//
//  DatabaseManager.swift
//  MenstrualCycle
//
//  Singleton quản lý kết nối SQLite qua libsqlite3 (tích hợp sẵn iOS).
//  Tự động tạo schema khi khởi chạy lần đầu.
//  Tương thích iOS 15+.
//

import Foundation
import SQLite3

final class DatabaseManager {

    // MARK: - Singleton
    static let shared = DatabaseManager()

    // MARK: - Properties
    private var db: OpaquePointer?

    /// Đường dẫn file database
    private var dbPath: String {
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        return documentsDir.appendingPathComponent("MenstrualCycle_v2.sqlite").path
    }

    var databaseURL: URL {
        return URL(fileURLWithPath: dbPath)
    }

    // MARK: - Init
    private init() {
        openDatabase()
        createTables()
        migrateIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Open Database

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ [DB] Không thể mở database: \(errMsg)")
        } else {
            print("✅ [DB] Database đã mở tại: \(dbPath)")
            // Bật WAL mode để tăng hiệu suất
            execute("PRAGMA journal_mode=WAL;")
            // Bật foreign keys
            execute("PRAGMA foreign_keys=ON;")
        }
    }

    // MARK: - Create Tables

    private func createTables() {
        // Bảng users — xác thực bằng SĐT + OTP
        let createUsers = """
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            country_code TEXT NOT NULL DEFAULT '+84',
            phone TEXT NOT NULL DEFAULT '',
            name TEXT NOT NULL DEFAULT '',
            gender TEXT NOT NULL DEFAULT '',
            date_of_birth REAL,
            avatar_path TEXT DEFAULT '',
            auth_provider TEXT NOT NULL DEFAULT 'phone',
            apple_user_id TEXT DEFAULT '',
            profile_completed INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL
        );
        """

        // Bảng cycle_profiles — hồ sơ theo dõi (multi-profile)
        let createCycleProfiles = """
        CREATE TABLE IF NOT EXISTS cycle_profiles (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT DEFAULT '',
            relationship TEXT NOT NULL,
            last_period_start REAL,
            period_duration INTEGER DEFAULT 5,
            cycle_length INTEGER DEFAULT 28,
            created_at REAL NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        """

        // Bảng cycle_dates — lịch sử ngày chu kỳ thực tế
        let createCycleDates = """
        CREATE TABLE IF NOT EXISTS cycle_dates (
            id TEXT PRIMARY KEY,
            profile_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            start_date REAL NOT NULL,
            end_date REAL,
            notes TEXT DEFAULT '',
            created_at REAL NOT NULL,
            FOREIGN KEY (profile_id) REFERENCES cycle_profiles(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        """

        // Bảng meal_entries
        let createMealEntries = """
        CREATE TABLE IF NOT EXISTS meal_entries (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            calories REAL DEFAULT 0,
            protein REAL DEFAULT 0,
            carbs REAL DEFAULT 0,
            fat REAL DEFAULT 0,
            date REAL NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        """

        // Bảng nutrition_profiles
        let createNutritionProfiles = """
        CREATE TABLE IF NOT EXISTS nutrition_profiles (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL UNIQUE,
            height_cm REAL DEFAULT 0,
            weight_kg REAL DEFAULT 0,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        """

        // Bảng fitness_entries
        let createFitnessEntries = """
        CREATE TABLE IF NOT EXISTS fitness_entries (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            duration_min INTEGER DEFAULT 0,
            calories_burned INTEGER DEFAULT 0,
            icon TEXT DEFAULT '',
            color_hex TEXT DEFAULT '',
            date REAL NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        """

        execute(createUsers)
        execute(createCycleProfiles)
        execute(createCycleDates)
        execute(createMealEntries)
        execute(createNutritionProfiles)
        execute(createFitnessEntries)
    }

    // MARK: - Migration (thêm cột mới cho bảng cũ nếu cần)

    private func migrateIfNeeded() {
        // Kiểm tra xem bảng users có cột country_code chưa
        let cols = query("PRAGMA table_info(users);")
        let colNames = cols.compactMap { $0["name"] as? String }

        if !colNames.contains("country_code") {
            execute("ALTER TABLE users ADD COLUMN country_code TEXT NOT NULL DEFAULT '+84';")
        }
        if !colNames.contains("gender") {
            execute("ALTER TABLE users ADD COLUMN gender TEXT NOT NULL DEFAULT '';")
        }
        if !colNames.contains("date_of_birth") {
            execute("ALTER TABLE users ADD COLUMN date_of_birth REAL;")
        }
        if !colNames.contains("profile_completed") {
            execute("ALTER TABLE users ADD COLUMN profile_completed INTEGER NOT NULL DEFAULT 0;")
        }
        if !colNames.contains("avatar_path") {
            execute("ALTER TABLE users ADD COLUMN avatar_path TEXT DEFAULT '';")
        }
        if !colNames.contains("auth_provider") {
            execute("ALTER TABLE users ADD COLUMN auth_provider TEXT NOT NULL DEFAULT 'phone';")
        }
        if !colNames.contains("apple_user_id") {
            execute("ALTER TABLE users ADD COLUMN apple_user_id TEXT DEFAULT '';")
        }
    }

    // MARK: - Execute (INSERT / UPDATE / DELETE / DDL)

    /// Thực thi câu lệnh SQL không trả dữ liệu
    @discardableResult
    func execute(_ sql: String, params: [Any?] = []) -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ [DB] Prepare failed: \(errMsg)\n   SQL: \(sql)")
            return false
        }
        defer { sqlite3_finalize(statement) }

        bindParams(statement: statement, params: params)

        let result = sqlite3_step(statement)
        if result != SQLITE_DONE && result != SQLITE_ROW {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ [DB] Execute failed: \(errMsg)\n   SQL: \(sql)")
            return false
        }
        return true
    }

    // MARK: - Query (SELECT)

    /// Thực thi SELECT và trả về mảng các row (mỗi row là dictionary)
    func query(_ sql: String, params: [Any?] = []) -> [[String: Any]] {
        var statement: OpaquePointer?
        var results: [[String: Any]] = []

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ [DB] Query prepare failed: \(errMsg)\n   SQL: \(sql)")
            return results
        }
        defer { sqlite3_finalize(statement) }

        bindParams(statement: statement, params: params)

        let columnCount = sqlite3_column_count(statement)
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<columnCount {
                let colName = String(cString: sqlite3_column_name(statement, i))
                let colType = sqlite3_column_type(statement, i)

                switch colType {
                case SQLITE_INTEGER:
                    row[colName] = Int(sqlite3_column_int64(statement, i))
                case SQLITE_FLOAT:
                    row[colName] = sqlite3_column_double(statement, i)
                case SQLITE_TEXT:
                    if let cString = sqlite3_column_text(statement, i) {
                        row[colName] = String(cString: cString)
                    }
                case SQLITE_NULL:
                    row[colName] = nil as Any? as Any
                default:
                    break
                }
            }
            results.append(row)
        }
        return results
    }

    // MARK: - Bind Parameters

    private func bindParams(statement: OpaquePointer?, params: [Any?]) {
        for (index, param) in params.enumerated() {
            let i = Int32(index + 1) // SQLite params are 1-indexed

            if param == nil {
                sqlite3_bind_null(statement, i)
            } else if let val = param as? String {
                sqlite3_bind_text(statement, i, (val as NSString).utf8String, -1, nil)
            } else if let val = param as? Int {
                sqlite3_bind_int64(statement, i, Int64(val))
            } else if let val = param as? Double {
                sqlite3_bind_double(statement, i, val)
            } else if let val = param as? Date {
                sqlite3_bind_double(statement, i, val.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(statement, i)
            }
        }
    }
}
