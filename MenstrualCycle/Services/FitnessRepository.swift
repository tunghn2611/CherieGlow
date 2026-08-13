//
//  FitnessRepository.swift
//  MenstrualCycle
//
//  Repository CRUD cho bảng fitness_entries.
//  Tương thích iOS 15+.
//

import Foundation

final class FitnessRepository {
    private let db = DatabaseManager.shared

    func fetchEntries(for userId: String, on date: Date) -> [FitnessEntry] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date).timeIntervalSince1970
        let endOfDay = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: date)!).timeIntervalSince1970

        let sql = "SELECT * FROM fitness_entries WHERE user_id = ? AND date >= ? AND date < ? ORDER BY date DESC"
        let rows = db.query(sql, params: [userId, startOfDay, endOfDay])

        return rows.compactMap { row in
            guard let idStr = row["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let name = row["name"] as? String,
                  let dateTime = row["date"] as? Double else {
                return nil
            }

            return FitnessEntry(
                id: id,
                name: name,
                durationMin: (row["duration_min"] as? Int) ?? 0,
                caloriesBurned: (row["calories_burned"] as? Int) ?? 0,
                icon: (row["icon"] as? String) ?? "figure.walk",
                colorHex: (row["color_hex"] as? String) ?? "",
                date: Date(timeIntervalSince1970: dateTime)
            )
        }
    }

    func insertEntry(_ entry: FitnessEntry, userId: String) -> Bool {
        let sql = """
            INSERT INTO fitness_entries (id, user_id, name, duration_min, calories_burned, icon, color_hex, date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        let params: [Any?] = [
            entry.id.uuidString,
            userId,
            entry.name,
            entry.durationMin,
            entry.caloriesBurned,
            entry.icon,
            entry.colorHex,
            entry.date.timeIntervalSince1970
        ]
        return db.execute(sql, params: params)
    }

    func deleteEntry(id: String) -> Bool {
        return db.execute("DELETE FROM fitness_entries WHERE id = ?", params: [id])
    }

    func todayTotalCalories(userId: String) -> Int {
        let cal = Calendar.current
        let now = Date()
        let startOfDay = cal.startOfDay(for: now).timeIntervalSince1970
        let endOfDay = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!).timeIntervalSince1970

        let sql = "SELECT COALESCE(SUM(calories_burned), 0) as total FROM fitness_entries WHERE user_id = ? AND date >= ? AND date < ?"
        let rows = db.query(sql, params: [userId, startOfDay, endOfDay])
        return (rows.first?["total"] as? Int) ?? 0
    }

    func todayTotalMinutes(userId: String) -> Int {
        let cal = Calendar.current
        let now = Date()
        let startOfDay = cal.startOfDay(for: now).timeIntervalSince1970
        let endOfDay = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!).timeIntervalSince1970

        let sql = "SELECT COALESCE(SUM(duration_min), 0) as total FROM fitness_entries WHERE user_id = ? AND date >= ? AND date < ?"
        let rows = db.query(sql, params: [userId, startOfDay, endOfDay])
        return (rows.first?["total"] as? Int) ?? 0
    }
}

// MARK: - FitnessEntry Model

struct FitnessEntry: Identifiable {
    let id: UUID
    var name: String
    var durationMin: Int
    var caloriesBurned: Int
    var icon: String
    var colorHex: String
    var date: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        durationMin: Int = 0,
        caloriesBurned: Int = 0,
        icon: String = "figure.walk",
        colorHex: String = "",
        date: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.durationMin = durationMin
        self.caloriesBurned = caloriesBurned
        self.icon = icon
        self.colorHex = colorHex
        self.date = date
    }
}
