//
//  FoodLookupService.swift
//  MenstrualCycle
//
//  Dịch vụ tra cứu hàm lượng dinh dưỡng từ dataset Viện Dinh Dưỡng
//  và fallback AI (Gemini) khi không tìm thấy.
//  Tương thích iOS 15+.
//

import Foundation

// MARK: - Food Item Model (JSON Decodable)

struct FoodItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let aliases: [String]
    let category: String
    let icon: String
    let unit: String
    let servingGrams: Int
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let vitaminA: Double
    let vitaminC: Double
    let vitaminB1: Double
    let vitaminB2: Double
    let calcium: Double
    let iron: Double
    let sodium: Double
    let sugar: Double
    let cholesterol: Double

    /// Nguồn dữ liệu
    var source: FoodSource = .verified

    enum FoodSource: String, Codable {
        case verified = "Viện Dinh Dưỡng Quốc Gia"
        case aiEstimated = "AI Estimated (Gemini)"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, aliases, category, icon, unit, servingGrams
        case calories, protein, carbs, fat, fiber
        case vitaminA, vitaminC, vitaminB1, vitaminB2
        case calcium, iron, sodium, sugar, cholesterol
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "🍽"
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? "1 phần"
        servingGrams = try c.decodeIfPresent(Int.self, forKey: .servingGrams) ?? 100
        calories = try c.decodeIfPresent(Double.self, forKey: .calories) ?? 0
        protein = try c.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        carbs = try c.decodeIfPresent(Double.self, forKey: .carbs) ?? 0
        fat = try c.decodeIfPresent(Double.self, forKey: .fat) ?? 0
        fiber = try c.decodeIfPresent(Double.self, forKey: .fiber) ?? 0
        vitaminA = try c.decodeIfPresent(Double.self, forKey: .vitaminA) ?? 0
        vitaminC = try c.decodeIfPresent(Double.self, forKey: .vitaminC) ?? 0
        vitaminB1 = try c.decodeIfPresent(Double.self, forKey: .vitaminB1) ?? 0
        vitaminB2 = try c.decodeIfPresent(Double.self, forKey: .vitaminB2) ?? 0
        calcium = try c.decodeIfPresent(Double.self, forKey: .calcium) ?? 0
        iron = try c.decodeIfPresent(Double.self, forKey: .iron) ?? 0
        sodium = try c.decodeIfPresent(Double.self, forKey: .sodium) ?? 0
        sugar = try c.decodeIfPresent(Double.self, forKey: .sugar) ?? 0
        cholesterol = try c.decodeIfPresent(Double.self, forKey: .cholesterol) ?? 0
        source = .verified
    }

    init(
        id: String, name: String, aliases: [String] = [], category: String = "",
        icon: String = "🍽", unit: String = "1 phần", servingGrams: Int = 100,
        calories: Double, protein: Double, carbs: Double, fat: Double,
        fiber: Double = 0, vitaminA: Double = 0, vitaminC: Double = 0,
        vitaminB1: Double = 0, vitaminB2: Double = 0,
        calcium: Double = 0, iron: Double = 0, sodium: Double = 0,
        sugar: Double = 0, cholesterol: Double = 0,
        source: FoodSource = .verified
    ) {
        self.id = id; self.name = name; self.aliases = aliases
        self.category = category; self.icon = icon; self.unit = unit
        self.servingGrams = servingGrams; self.calories = calories
        self.protein = protein; self.carbs = carbs; self.fat = fat
        self.fiber = fiber; self.vitaminA = vitaminA; self.vitaminC = vitaminC
        self.vitaminB1 = vitaminB1; self.vitaminB2 = vitaminB2
        self.calcium = calcium; self.iron = iron; self.sodium = sodium
        self.sugar = sugar; self.cholesterol = cholesterol; self.source = source
    }

    static func == (lhs: FoodItem, rhs: FoodItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Food Lookup Service

final class FoodLookupService {
    static let shared = FoodLookupService()

    private var allFoods: [FoodItem] = []
    private var isLoaded = false

    private init() {
        loadDatabase()
    }

    // MARK: - Load JSON Database

    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "vietnamese_foods", withExtension: "json") else {
            print("⚠️ [FoodLookup] vietnamese_foods.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            allFoods = try JSONDecoder().decode([FoodItem].self, from: data)
            isLoaded = true
            print("✅ [FoodLookup] Loaded \(allFoods.count) foods from database")
        } catch {
            print("❌ [FoodLookup] Failed to parse JSON: \(error)")
        }
    }

    // MARK: - Fuzzy Search

    /// Tìm kiếm món ăn bằng fuzzy matching (bỏ dấu, lowercase, match aliases)
    func search(query: String) -> [FoodItem] {
        let normalizedQuery = removeDiacritics(query.lowercased().trimmingCharacters(in: .whitespaces))
        guard !normalizedQuery.isEmpty else { return [] }

        // Tính điểm match cho mỗi món
        var scored: [(food: FoodItem, score: Int)] = []

        for food in allFoods {
            let normalizedName = removeDiacritics(food.name.lowercased())
            let normalizedAliases = food.aliases.map { removeDiacritics($0.lowercased()) }

            var score = 0

            // Exact match tên chính → điểm cao nhất
            if normalizedName == normalizedQuery {
                score = 100
            }
            // Tên chính chứa query
            else if normalizedName.contains(normalizedQuery) {
                score = 80
            }
            // Query chứa tên chính (user nhập nhiều hơn)
            else if normalizedQuery.contains(normalizedName) {
                score = 70
            }
            // Check aliases
            else {
                for alias in normalizedAliases {
                    if alias == normalizedQuery {
                        score = 90
                        break
                    } else if alias.contains(normalizedQuery) || normalizedQuery.contains(alias) {
                        score = max(score, 60)
                    }
                }
            }

            // Word-level match (ít nhất 1 từ trùng)
            if score == 0 {
                let queryWords = normalizedQuery.split(separator: " ")
                let nameWords = normalizedName.split(separator: " ")
                let matchCount = queryWords.filter { qw in
                    nameWords.contains(where: { $0.contains(qw) || qw.contains($0) })
                }.count
                if matchCount > 0 {
                    score = 30 + min(matchCount * 10, 30)
                }
            }

            if score > 0 {
                scored.append((food, score))
            }
        }

        // Sắp xếp theo điểm giảm dần
        return scored.sorted { $0.score > $1.score }.map { $0.food }
    }

    /// Lấy tất cả danh mục
    func getAllCategories() -> [String] {
        Array(Set(allFoods.map { $0.category })).sorted()
    }

    /// Lấy tất cả món theo danh mục
    func getFoods(byCategory category: String) -> [FoodItem] {
        allFoods.filter { $0.category == category }
    }

    /// Lấy tất cả món ăn
    func getAllFoods() -> [FoodItem] {
        allFoods
    }

    // MARK: - Vietnamese Diacritics Removal

    private func removeDiacritics(_ string: String) -> String {
        let mutable = NSMutableString(string: string)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        // Additional Vietnamese-specific replacements
        return (mutable as String)
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
    }
}
