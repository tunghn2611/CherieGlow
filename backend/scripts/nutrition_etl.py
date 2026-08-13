#!/usr/bin/env python3
"""
ETL Script: Viện Dinh Dưỡng Quốc Gia → MySQL
==============================================

Strategy: Direct API consumption (NO scraping needed!)

Discovery: The website viendinhduong.vn uses a hidden REST API to
serve its single-page application. We bypass the HTML entirely and
call the JSON API directly, which is:
  - 10x faster than Playwright/Selenium
  - More reliable (no DOM parsing)
  - Structured JSON (no BeautifulSoup needed)

Hidden APIs found:
  1. GET /api/fe/tool/apiGetListFoodCategory — All food categories
  2. GET /api/fe/tool/getPageFoodData?page=N&limit=M — Paginated food data

Data: 1250 dishes, 19 categories, ~14 nutritional fields per dish.

Usage:
    python3 scraper.py                    # Full import
    python3 scraper.py --page 1 --limit 5 # Test with 5 items
    python3 scraper.py --dry-run          # Preview without DB write
"""

import json
import time
import argparse
import sys
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

# ── Configuration ────────────────────────────────────────────
BASE_URL = "https://viendinhduong.vn"
CATEGORIES_API = f"{BASE_URL}/api/fe/tool/apiGetListFoodCategory"
FOOD_DATA_API = f"{BASE_URL}/api/fe/tool/getPageFoodData"
PAGE_SIZE = 50  # Items per page (max observed: 50)
RATE_LIMIT_SECONDS = 0.5  # Polite delay between requests

# MySQL connection (uses same config as Node.js backend)
DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": "",
    "database": "menstrual_cycle_db",
    "charset": "utf8mb4",
}

# ── Nutritional component key mapping ─────────────────────────
# Maps the API's Vietnamese/English keys to our MySQL column names
NUTRIENT_MAP = {
    "nang-luong":       "energy_kcal",
    "chat-dam":         "protein_g",
    "chat-beo":         "lipid_g",
    "chat-bot-duong":   "carbohydrate_g",
    "vitamin-a":        "vitamin_a_ug",
    "beta-caroten":     "beta_carotene_ug",
    "vitamin-c":        "vitamin_c_mg",
    "calcium":          "calcium_mg",
    "canxi":            "calcium_mg",       # Vietnamese variant
    "iron":             "iron_mg",
    "sat":              "iron_mg",          # Vietnamese variant
    "zinc":             "zinc_mg",
    "kem":              "zinc_mg",          # Vietnamese variant
    "natri":            "sodium_mg",
    "cholesterol":      "cholesterol_mg",
    "kali":             "potassium_mg",
    "magnesium":        "magnesium_mg",
    "xo":               "fiber_g",
}

# Default column values
DEFAULT_COLUMNS = {
    "energy_kcal": 0, "protein_g": 0, "lipid_g": 0, "carbohydrate_g": 0,
    "fiber_g": 0, "vitamin_a_ug": 0, "beta_carotene_ug": 0, "vitamin_c_mg": 0,
    "calcium_mg": 0, "iron_mg": 0, "zinc_mg": 0, "sodium_mg": 0,
    "potassium_mg": 0, "magnesium_mg": 0, "cholesterol_mg": 0,
}


def fetch_json(url):
    """Fetch JSON from URL with retry logic."""
    headers = {
        "User-Agent": "MenstrualCycleApp/1.0 (Nutrition ETL)",
        "Accept": "application/json",
    }
    for attempt in range(3):
        try:
            req = Request(url, headers=headers)
            with urlopen(req, timeout=30) as response:
                return json.loads(response.read().decode("utf-8"))
        except (URLError, HTTPError) as e:
            print(f"  ⚠️ Attempt {attempt+1}/3 failed: {e}")
            if attempt < 2:
                time.sleep(2 ** attempt)
    raise Exception(f"Failed to fetch: {url}")


def parse_nutrients(nutritional_components):
    """Parse the nutritional_components array into a flat dict."""
    result = dict(DEFAULT_COLUMNS)
    if not nutritional_components:
        return result

    for comp in nutritional_components:
        key = comp.get("key", "")
        amount = comp.get("amount", "")
        if key in NUTRIENT_MAP and amount != "" and amount is not None:
            try:
                col = NUTRIENT_MAP[key]
                # Only update if we haven't set it yet (avoid duplicate keys)
                if result[col] == 0:
                    result[col] = float(amount)
            except (ValueError, TypeError):
                pass
    return result


def fetch_categories():
    """Fetch all food categories from the API."""
    print("📂 Fetching food categories...")
    categories = fetch_json(CATEGORIES_API)
    print(f"   Found {len(categories)} categories")
    return categories


def fetch_all_foods(max_pages=None):
    """Fetch all food items, paginated."""
    # First, get total count
    first_page = fetch_json(f"{FOOD_DATA_API}?page=1&limit=1&name=&group=&energy=0&foodAreaId=")
    total = first_page.get("total", 0)
    last_page = first_page.get("last_page", 1)
    print(f"🍽️  Total food items: {total} across {last_page} pages")

    if max_pages:
        last_page = min(last_page, max_pages)
        print(f"   (Limited to {max_pages} pages)")

    all_foods = []
    for page in range(1, last_page + 1):
        url = f"{FOOD_DATA_API}?page={page}&limit={PAGE_SIZE}&name=&group=&energy=0&foodAreaId="
        print(f"   📄 Page {page}/{last_page}...", end=" ", flush=True)
        data = fetch_json(url)
        items = data.get("data", [])
        all_foods.extend(items)
        print(f"got {len(items)} items")
        time.sleep(RATE_LIMIT_SECONDS)  # Be polite to the server

    print(f"   ✅ Total fetched: {len(all_foods)} food items")
    return all_foods


def import_to_mysql(categories, foods, dry_run=False):
    """Import data into MySQL database."""
    try:
        import mysql.connector
    except ImportError:
        print("❌ mysql-connector-python not installed. Run: pip3 install mysql-connector-python")
        sys.exit(1)

    if dry_run:
        print("\n🔍 DRY RUN — Preview first 5 items:")
        for food in foods[:5]:
            nutrients = parse_nutrients(food.get("nutritional_components", []))
            print(f"   • {food.get('name_vi', '?')} | {nutrients['energy_kcal']} kcal | "
                  f"P:{nutrients['protein_g']}g F:{nutrients['lipid_g']}g C:{nutrients['carbohydrate_g']}g")
        print(f"\n   Would import {len(categories)} categories + {len(foods)} foods")
        return

    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()

    # Import categories
    print("\n📥 Importing categories...")
    cat_sql = """
        INSERT INTO food_categories (id, name_vi, name_en, ord, source)
        VALUES (%s, %s, %s, %s, 'viendinhduong.vn')
        ON DUPLICATE KEY UPDATE name_vi=VALUES(name_vi), name_en=VALUES(name_en), ord=VALUES(ord)
    """
    cat_count = 0
    for cat in categories:
        cursor.execute(cat_sql, (
            cat["_id"], cat.get("name", ""), cat.get("nameEn", ""), cat.get("ord", 0)
        ))
        cat_count += 1
    conn.commit()
    print(f"   ✅ {cat_count} categories imported")

    # Import foods
    print("📥 Importing food items...")
    food_sql = """
        INSERT INTO foods (
            id, code, name_vi, name_en, category_id, image_url, region_id,
            energy_kcal, protein_g, lipid_g, carbohydrate_g, fiber_g,
            vitamin_a_ug, beta_carotene_ug, vitamin_c_mg,
            calcium_mg, iron_mg, zinc_mg, sodium_mg, potassium_mg, magnesium_mg,
            cholesterol_mg, source, raw_data
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, 'viendinhduong.vn', %s
        )
        ON DUPLICATE KEY UPDATE
            name_vi=VALUES(name_vi), name_en=VALUES(name_en),
            energy_kcal=VALUES(energy_kcal), protein_g=VALUES(protein_g),
            lipid_g=VALUES(lipid_g), carbohydrate_g=VALUES(carbohydrate_g),
            fiber_g=VALUES(fiber_g), vitamin_a_ug=VALUES(vitamin_a_ug),
            beta_carotene_ug=VALUES(beta_carotene_ug), vitamin_c_mg=VALUES(vitamin_c_mg),
            calcium_mg=VALUES(calcium_mg), iron_mg=VALUES(iron_mg),
            zinc_mg=VALUES(zinc_mg), sodium_mg=VALUES(sodium_mg),
            potassium_mg=VALUES(potassium_mg), magnesium_mg=VALUES(magnesium_mg),
            cholesterol_mg=VALUES(cholesterol_mg), raw_data=VALUES(raw_data)
    """
    food_count = 0
    errors = 0
    for food in foods:
        try:
            nutrients = parse_nutrients(food.get("nutritional_components", []))
            image = food.get("image", "")
            if image and not image.startswith("http"):
                image = BASE_URL + image

            cursor.execute(food_sql, (
                food["_id"],
                food.get("code", ""),
                food.get("name_vi", ""),
                food.get("name_en", ""),
                food.get("category_id", None),
                image,
                food.get("food_area_id", None),
                nutrients["energy_kcal"], nutrients["protein_g"],
                nutrients["lipid_g"], nutrients["carbohydrate_g"], nutrients["fiber_g"],
                nutrients["vitamin_a_ug"], nutrients["beta_carotene_ug"], nutrients["vitamin_c_mg"],
                nutrients["calcium_mg"], nutrients["iron_mg"], nutrients["zinc_mg"],
                nutrients["sodium_mg"], nutrients["potassium_mg"], nutrients["magnesium_mg"],
                nutrients["cholesterol_mg"],
                json.dumps(food, ensure_ascii=False),
            ))
            food_count += 1
        except Exception as e:
            errors += 1
            print(f"   ❌ Error importing '{food.get('name_vi', '?')}': {e}")

    conn.commit()
    cursor.close()
    conn.close()

    print(f"\n🎉 Import complete!")
    print(f"   ✅ {food_count} foods imported successfully")
    if errors:
        print(f"   ⚠️  {errors} errors occurred")


def main():
    parser = argparse.ArgumentParser(description="ETL: Viện Dinh Dưỡng → MySQL")
    parser.add_argument("--pages", type=int, default=None, help="Limit number of pages to fetch")
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing to DB")
    args = parser.parse_args()

    print("=" * 60)
    print("🌸 MenstrualCycle — Nutrition Data ETL Pipeline")
    print("   Source: Viện Dinh Dưỡng Quốc Gia (viendinhduong.vn)")
    print("   Method: Direct API (no scraping needed!)")
    print("=" * 60)

    categories = fetch_categories()
    foods = fetch_all_foods(max_pages=args.pages)
    import_to_mysql(categories, foods, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
