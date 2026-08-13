//
//  CycleRepository.swift
//  MenstrualCycle
//
//  Repository CRUD cho cycle_profiles và cycle_dates.
//  Tương thích iOS 15+.
//

import Foundation

final class CycleRepository {
    private let db = DatabaseManager.shared

    // MARK: - Cycle Profiles

    func fetchProfiles(for userId: String) -> [CycleProfile] {
        let sql = "SELECT * FROM cycle_profiles WHERE user_id = ? ORDER BY created_at DESC"
        let rows = db.query(sql, params: [userId])

        return rows.compactMap { row in
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  let relationshipStr = row["relationship"] as? String,
                  let relationship = ProfileRelationship(rawValue: relationshipStr),
                  let periodDuration = row["period_duration"] as? Int,
                  let cycleLength = row["cycle_length"] as? Int,
                  let createdAtTime = row["created_at"] as? Double else {
                return nil
            }

            let name = (row["name"] as? String) ?? ""
            var lastPeriodStart: Date? = nil
            if let lastTime = row["last_period_start"] as? Double {
                lastPeriodStart = Date(timeIntervalSince1970: lastTime)
            }

            return CycleProfile(
                id: id,
                name: name,
                relationship: relationship,
                lastPeriodStart: lastPeriodStart,
                periodDuration: periodDuration,
                cycleLength: cycleLength,
                createdAt: Date(timeIntervalSince1970: createdAtTime)
            )
        }
    }

    func insertProfile(profile: CycleProfile, userId: String) -> Bool {
        let sql = """
            INSERT INTO cycle_profiles (id, user_id, name, relationship, last_period_start, period_duration, cycle_length, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        let params: [Any?] = [
            profile.id.uuidString,
            userId,
            profile.name,
            profile.relationship.rawValue,
            profile.lastPeriodStart?.timeIntervalSince1970,
            profile.periodDuration,
            profile.cycleLength,
            profile.createdAt.timeIntervalSince1970
        ]
        return db.execute(sql, params: params)
    }

    func updateProfile(_ profile: CycleProfile) -> Bool {
        let sql = """
            UPDATE cycle_profiles
            SET name = ?, relationship = ?, last_period_start = ?,
                period_duration = ?, cycle_length = ?
            WHERE id = ?
        """
        let params: [Any?] = [
            profile.name,
            profile.relationship.rawValue,
            profile.lastPeriodStart?.timeIntervalSince1970,
            profile.periodDuration,
            profile.cycleLength,
            profile.id.uuidString
        ]
        return db.execute(sql, params: params)
    }

    func deleteProfile(id: String) -> Bool {
        let sql = "DELETE FROM cycle_profiles WHERE id = ?"
        return db.execute(sql, params: [id])
    }

    // MARK: - Cycle Dates (lịch sử ngày chu kỳ thực tế)

    func fetchCycleDates(profileId: String) -> [CycleDateEntry] {
        let sql = "SELECT * FROM cycle_dates WHERE profile_id = ? ORDER BY start_date DESC"
        let rows = db.query(sql, params: [profileId])

        return rows.compactMap { row in
            guard let idStr = row["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let startTime = row["start_date"] as? Double else {
                return nil
            }

            var endDate: Date? = nil
            if let endTime = row["end_date"] as? Double {
                endDate = Date(timeIntervalSince1970: endTime)
            }

            return CycleDateEntry(
                id: id,
                profileId: profileId,
                startDate: Date(timeIntervalSince1970: startTime),
                endDate: endDate,
                notes: (row["notes"] as? String) ?? ""
            )
        }
    }

    func insertCycleDate(entry: CycleDateEntry, userId: String) -> Bool {
        let sql = """
            INSERT INTO cycle_dates (id, profile_id, user_id, start_date, end_date, notes, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        let params: [Any?] = [
            entry.id.uuidString,
            entry.profileId,
            userId,
            entry.startDate.timeIntervalSince1970,
            entry.endDate?.timeIntervalSince1970,
            entry.notes,
            Date().timeIntervalSince1970
        ]
        return db.execute(sql, params: params)
    }

    func deleteCycleDate(id: String) -> Bool {
        return db.execute("DELETE FROM cycle_dates WHERE id = ?", params: [id])
    }
}

// MARK: - CycleDateEntry Model

struct CycleDateEntry: Identifiable {
    let id: UUID
    let profileId: String
    let startDate: Date
    let endDate: Date?
    let notes: String

    init(
        id: UUID = UUID(),
        profileId: String,
        startDate: Date,
        endDate: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.profileId = profileId
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }
}
