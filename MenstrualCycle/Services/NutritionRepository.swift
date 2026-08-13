//
//  NutritionRepository.swift
//  MenstrualCycle
//
//  Repository CRUD cho bảng meal_entries và nutrition_profiles.
//  Tương thích iOS 15+.
//

import Foundation

final class NutritionRepository {
    private let db = DatabaseManager.shared

    // MARK: - Nutrition Profile
    func getProfile(for userId: String) -> NutritionProfile? {
        let sql = "SELECT * FROM nutrition_profiles WHERE user_id = ?"
        let rows = db.query(sql, params: [userId])

        guard let row = rows.first else { return nil }

        let height = (row["height_cm"] as? Double) ?? 0.0
        let weight = (row["weight_kg"] as? Double) ?? 0.0

        return NutritionProfile(heightCm: height, weightKg: weight)
    }

    func saveProfile(userId: String, heightCm: Double, weightKg: Double) -> Bool {
        // Kiểm tra đã có chưa
        let existing = db.query("SELECT id FROM nutrition_profiles WHERE user_id = ?", params: [userId])
        if existing.isEmpty {
            let sql = "INSERT INTO nutrition_profiles (id, user_id, height_cm, weight_kg) VALUES (?, ?, ?, ?)"
            return db.execute(sql, params: [UUID().uuidString, userId, heightCm, weightKg])
        } else {
            let sql = "UPDATE nutrition_profiles SET height_cm = ?, weight_kg = ? WHERE user_id = ?"
            return db.execute(sql, params: [heightCm, weightKg, userId])
        }
    }

    // MARK: - Meal Entries
    func fetchMeals(for userId: String, on date: Date) -> [MealEntry] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date).timeIntervalSince1970
        let endOfDay = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: date)!).timeIntervalSince1970

        let sql = "SELECT * FROM meal_entries WHERE user_id = ? AND date >= ? AND date < ? ORDER BY date DESC"
        let rows = db.query(sql, params: [userId, startOfDay, endOfDay])

        return rows.compactMap { row in
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  let name = row["name"] as? String,
                  let dateTime = row["date"] as? Double else {
                return nil
            }

            return MealEntry(
                id: id,
                name: name,
                calories: (row["calories"] as? Double) ?? 0.0,
                protein: (row["protein"] as? Double) ?? 0.0,
                carbs: (row["carbs"] as? Double) ?? 0.0,
                fat: (row["fat"] as? Double) ?? 0.0,
                date: Date(timeIntervalSince1970: dateTime)
            )
        }
    }

    func insertMeal(_ meal: MealEntry, userId: String) -> Bool {
        let sql = """
            INSERT INTO meal_entries (id, user_id, name, calories, protein, carbs, fat, date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        let params: [Any?] = [
            meal.id.uuidString, userId, meal.name,
            meal.calories, meal.protein, meal.carbs, meal.fat,
            meal.date.timeIntervalSince1970
        ]
        return db.execute(sql, params: params)
    }

    func deleteMeal(id: String) -> Bool {
        return db.execute("DELETE FROM meal_entries WHERE id = ?", params: [id])
    }
}
