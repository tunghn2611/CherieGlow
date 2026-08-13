//
//  UserRepository.swift
//  MenstrualCycle
//
//  Repository CRUD cho bảng users.
//  Hỗ trợ: SĐT + OTP, Sign in with Apple, avatar.
//  Tương thích iOS 15+.
//

import Foundation

struct UserRepository {

    private let db = DatabaseManager.shared

    // MARK: - Find or Create by Phone

    func findOrCreateByPhone(countryCode: String, phone: String) -> String? {
        let fullPhone = phone.trimmingCharacters(in: .whitespaces)

        let rows = db.query(
            "SELECT id FROM users WHERE country_code = ?1 AND phone = ?2 AND auth_provider = 'phone';",
            params: [countryCode, fullPhone]
        )

        if let existingId = rows.first?["id"] as? String {
            return existingId
        }

        let userId = UUID().uuidString
        let createdAt = Date().timeIntervalSince1970

        let success = db.execute(
            """
            INSERT INTO users (id, country_code, phone, name, gender, date_of_birth, avatar_path, auth_provider, apple_user_id, profile_completed, created_at)
            VALUES (?1, ?2, ?3, '', '', NULL, '', 'phone', '', 0, ?4);
            """,
            params: [userId, countryCode, fullPhone, createdAt]
        )

        return success ? userId : nil
    }

    // MARK: - Ensure Local User (đồng bộ user từ server vào SQLite local)

    /// Đảm bảo user tồn tại trong SQLite local. Dùng khi login qua backend API trả về userId từ server.
    @discardableResult
    func ensureLocalUser(userId: String, countryCode: String = "+84", phone: String = "", name: String = "", provider: String = "phone", profileCompleted: Bool = false) -> Bool {
        // Kiểm tra user đã tồn tại chưa
        let rows = db.query("SELECT id FROM users WHERE id = ?1;", params: [userId])
        if !rows.isEmpty {
            // User đã tồn tại → cập nhật thông tin mới nhất
            return db.execute(
                "UPDATE users SET name = ?1, phone = ?2, profile_completed = ?3 WHERE id = ?4;",
                params: [name, phone, profileCompleted ? 1 : 0, userId]
            )
        }

        // Tạo user mới
        let createdAt = Date().timeIntervalSince1970
        return db.execute(
            """
            INSERT INTO users (id, country_code, phone, name, gender, date_of_birth, avatar_path, auth_provider, apple_user_id, profile_completed, created_at)
            VALUES (?1, ?2, ?3, ?4, '', NULL, '', ?5, '', ?6, ?7);
            """,
            params: [userId, countryCode, phone, name, provider, profileCompleted ? 1 : 0, createdAt]
        )
    }

    // MARK: - Find or Create by Apple ID

    func findOrCreateByApple(appleUserId: String, fullName: String) -> String? {
        let rows = db.query(
            "SELECT id FROM users WHERE apple_user_id = ?1 AND auth_provider = 'apple';",
            params: [appleUserId]
        )

        if let existingId = rows.first?["id"] as? String {
            return existingId
        }

        let userId = UUID().uuidString
        let createdAt = Date().timeIntervalSince1970

        let success = db.execute(
            """
            INSERT INTO users (id, country_code, phone, name, gender, date_of_birth, avatar_path, auth_provider, apple_user_id, profile_completed, created_at)
            VALUES (?1, '+84', '', ?2, '', NULL, '', 'apple', ?3, 0, ?4);
            """,
            params: [userId, fullName, appleUserId, createdAt]
        )

        return success ? userId : nil
    }

    // MARK: - Fetch by ID

    func fetchUser(byId userId: String) -> UserInfo? {
        let rows = db.query(
            "SELECT * FROM users WHERE id = ?1;",
            params: [userId]
        )
        guard let row = rows.first else { return nil }

        var dateOfBirth: Date? = nil
        if let dobTime = row["date_of_birth"] as? Double {
            dateOfBirth = Date(timeIntervalSince1970: dobTime)
        }

        return UserInfo(
            id: userId,
            countryCode: row["country_code"] as? String ?? "+84",
            phone: row["phone"] as? String ?? "",
            name: row["name"] as? String ?? "",
            gender: row["gender"] as? String ?? "",
            dateOfBirth: dateOfBirth,
            avatarPath: row["avatar_path"] as? String ?? "",
            authProvider: row["auth_provider"] as? String ?? "phone",
            profileCompleted: (row["profile_completed"] as? Int ?? 0) == 1
        )
    }

    // MARK: - Update Profile (thông tin cơ bản sau đăng nhập lần đầu)

    func updateProfile(userId: String, name: String, gender: String, dateOfBirth: Date, avatarPath: String = "") -> Bool {
        return db.execute(
            """
            UPDATE users SET name = ?1, gender = ?2, date_of_birth = ?3, avatar_path = ?4, profile_completed = 1
            WHERE id = ?5;
            """,
            params: [name, gender, dateOfBirth.timeIntervalSince1970, avatarPath, userId]
        )
    }

    // MARK: - Update Avatar Only

    func updateAvatar(userId: String, avatarPath: String) -> Bool {
        return db.execute(
            "UPDATE users SET avatar_path = ?1 WHERE id = ?2;",
            params: [avatarPath, userId]
        )
    }

    // MARK: - Update Name Only

    func updateUser(userId: String, name: String, phone: String) -> Bool {
        return db.execute(
            "UPDATE users SET name = ?1, phone = ?2 WHERE id = ?3;",
            params: [name, phone, userId]
        )
    }

    // MARK: - Check Profile Completed

    func isProfileCompleted(userId: String) -> Bool {
        let rows = db.query(
            "SELECT profile_completed FROM users WHERE id = ?1;",
            params: [userId]
        )
        return (rows.first?["profile_completed"] as? Int ?? 0) == 1
    }

    // MARK: - Quick Account (Google/Facebook — no SDK, local only)

    @discardableResult
    func findOrCreateQuickAccount(userId: String, provider: String, defaultName: String) -> Bool {
        let createdAt = Date().timeIntervalSince1970
        return db.execute(
            """
            INSERT INTO users (id, country_code, phone, name, gender, date_of_birth, avatar_path, auth_provider, apple_user_id, profile_completed, created_at)
            VALUES (?1, '+84', '', ?2, '', NULL, '', ?3, '', 0, ?4);
            """,
            params: [userId, defaultName, provider, createdAt]
        )
    }

    // MARK: - Find User by Provider & Email / Name
    func findByProviderEmail(provider: String, email: String) -> String? {
        let rows = db.query(
            "SELECT id FROM users WHERE auth_provider = ?1 ORDER BY created_at ASC;",
            params: [provider]
        )
        return rows.first?["id"] as? String
    }

    // MARK: - Migrate Local User Data
    /// Chuyển toàn bộ dữ liệu từ user ID cũ sang user ID mới khi login lại
    func migrateUserData(from oldUserId: String, to newUserId: String) {
        guard !oldUserId.isEmpty, !newUserId.isEmpty, oldUserId != newUserId else { return }
        
        print("🔄 [DB] Migrating local data from \(oldUserId) → \(newUserId)")
        
        // 1. Cập nhật cycle_profiles
        db.execute("UPDATE cycle_profiles SET user_id = ?1 WHERE user_id = ?2;", params: [newUserId, oldUserId])
        
        // 2. Cập nhật cycle_dates
        db.execute("UPDATE cycle_dates SET user_id = ?1 WHERE user_id = ?2;", params: [newUserId, oldUserId])
        
        // 3. Cập nhật meal_entries
        db.execute("UPDATE meal_entries SET user_id = ?1 WHERE user_id = ?2;", params: [newUserId, oldUserId])
        
        // 4. Cập nhật nutrition_profiles
        let existingNewProfile = db.query("SELECT id FROM nutrition_profiles WHERE user_id = ?1;", params: [newUserId])
        if existingNewProfile.isEmpty {
            db.execute("UPDATE nutrition_profiles SET user_id = ?1 WHERE user_id = ?2;", params: [newUserId, oldUserId])
        } else {
            db.execute("DELETE FROM nutrition_profiles WHERE user_id = ?1;", params: [oldUserId])
        }
        
        // 5. Cập nhật fitness_entries
        db.execute("UPDATE fitness_entries SET user_id = ?1 WHERE user_id = ?2;", params: [newUserId, oldUserId])
        
        print("✅ [DB] Local data migration complete!")
    }
}

// MARK: - UserInfo Model

struct UserInfo {
    let id: String
    let countryCode: String
    let phone: String
    let name: String
    let gender: String
    let dateOfBirth: Date?
    let avatarPath: String
    let authProvider: String
    let profileCompleted: Bool
}
