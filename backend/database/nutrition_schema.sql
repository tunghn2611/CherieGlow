-- ============================================================
-- MODULE 3: SMART NUTRITION TABLES
-- ============================================================
USE menstrual_cycle_db;

-- 9. Food Categories (from Viện Dinh Dưỡng)
CREATE TABLE IF NOT EXISTS food_categories (
    id              VARCHAR(30) PRIMARY KEY,         -- MongoDB _id from source
    name_vi         VARCHAR(255) NOT NULL,
    name_en         VARCHAR(255),
    ord             INT DEFAULT 0,
    source          VARCHAR(100) DEFAULT 'viendinhduong.vn',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_name (name_vi)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Foods — Nutritional values per 100g serving
CREATE TABLE IF NOT EXISTS foods (
    id              VARCHAR(30) PRIMARY KEY,         -- MongoDB _id from source
    code            VARCHAR(20),                      -- e.g. "VPF-000432"
    name_vi         VARCHAR(255) NOT NULL,
    name_en         VARCHAR(255),
    category_id     VARCHAR(30),
    image_url       VARCHAR(500),
    region_id       VARCHAR(30),
    -- Macronutrients (per 100g)
    energy_kcal     DECIMAL(8,2) DEFAULT 0,
    protein_g       DECIMAL(8,2) DEFAULT 0,
    lipid_g         DECIMAL(8,2) DEFAULT 0,
    carbohydrate_g  DECIMAL(8,2) DEFAULT 0,
    fiber_g         DECIMAL(8,2) DEFAULT 0,
    -- Micronutrients
    vitamin_a_ug    DECIMAL(8,2) DEFAULT 0,
    beta_carotene_ug DECIMAL(8,2) DEFAULT 0,
    vitamin_c_mg    DECIMAL(8,2) DEFAULT 0,
    calcium_mg      DECIMAL(8,2) DEFAULT 0,
    iron_mg         DECIMAL(8,2) DEFAULT 0,
    zinc_mg         DECIMAL(8,2) DEFAULT 0,
    sodium_mg       DECIMAL(8,2) DEFAULT 0,
    potassium_mg    DECIMAL(8,2) DEFAULT 0,
    magnesium_mg    DECIMAL(8,2) DEFAULT 0,
    cholesterol_mg  DECIMAL(8,2) DEFAULT 0,
    -- Metadata
    source          VARCHAR(100) DEFAULT 'viendinhduong.vn',
    raw_data        JSON,                             -- Full original JSON for reference
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES food_categories(id) ON DELETE SET NULL,
    INDEX idx_name_vi (name_vi),
    INDEX idx_category (category_id),
    FULLTEXT INDEX ft_food_name (name_vi, name_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. Daily Nutrition Logs — User's daily food intake
CREATE TABLE IF NOT EXISTS daily_nutrition_logs (
    id              CHAR(36) PRIMARY KEY,
    user_id         CHAR(36) NOT NULL,
    log_date        DATE NOT NULL,
    meal_type       ENUM('breakfast', 'lunch', 'dinner', 'snack') NOT NULL,
    food_id         VARCHAR(30),
    food_name       VARCHAR(255) NOT NULL,            -- Snapshot (in case food record changes)
    serving_size_g  DECIMAL(8,2) DEFAULT 100,         -- Grams consumed
    -- Calculated nutritional values (based on serving size)
    calories        DECIMAL(8,2) DEFAULT 0,
    protein         DECIMAL(8,2) DEFAULT 0,
    fat             DECIMAL(8,2) DEFAULT 0,
    carbs           DECIMAL(8,2) DEFAULT 0,
    fiber           DECIMAL(8,2) DEFAULT 0,
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE SET NULL,
    INDEX idx_user_date (user_id, log_date),
    INDEX idx_meal (user_id, log_date, meal_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. Daily Nutrition Summary — Aggregated daily totals
CREATE TABLE IF NOT EXISTS daily_nutrition_summary (
    id              CHAR(36) PRIMARY KEY,
    user_id         CHAR(36) NOT NULL,
    log_date        DATE NOT NULL,
    total_calories  DECIMAL(8,2) DEFAULT 0,
    total_protein   DECIMAL(8,2) DEFAULT 0,
    total_fat       DECIMAL(8,2) DEFAULT 0,
    total_carbs     DECIMAL(8,2) DEFAULT 0,
    total_fiber     DECIMAL(8,2) DEFAULT 0,
    meal_count      INT DEFAULT 0,
    -- Target comparison
    calorie_target  DECIMAL(8,2) DEFAULT 2000,
    protein_target  DECIMAL(8,2) DEFAULT 50,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_date (user_id, log_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
