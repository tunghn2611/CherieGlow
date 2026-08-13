//
//  APIService.swift
//  MenstrualCycle
//
//  Service xử lý toàn bộ các API request từ ứng dụng iOS tới Backend Node.js
//  Production: Render.com (HTTPS)
//  Debug: Local LAN (HTTP)
//

import Foundation
import UIKit

class APIService {
    static let shared = APIService()
    
    /// Production Server on Render.com
    /// Kết nối trực tiếp tới cloud backend để app hoạt động mọi lúc trên điện thoại
    private let baseURL: URL = {
        return URL(string: "https://cherieglow.onrender.com/api")!
    }()
    
    // Lưu trữ Access Token trong bộ nhớ tạm (Có thể tối ưu lưu vào Keychain sau này)
    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "jwt_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "jwt_access_token") }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "jwt_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "jwt_refresh_token") }
    }
    
    private init() {}
    
    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
    }
    
    func clearTokens() {
        UserDefaults.standard.removeObject(forKey: "jwt_access_token")
        UserDefaults.standard.removeObject(forKey: "jwt_refresh_token")
    }
    
    // Helper để chèn Header
    private func defaultHeaders() -> [String: String] {
        var headers = ["Content-Type": "application/json"]
        if let token = accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
    
    // Generic Request
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let urlString = baseURL.absoluteString + "/" + endpoint
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "APIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        for (key, value) in defaultHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data returned"])))
                return
            }
            
            // Log response raw
            if let rawJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📥 [API-RESPONSE] \(endpoint):", rawJson)
            }
            
            do {
                let decoder = JSONDecoder()
                // Xử lý cả định dạng Date string từ MySQL
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                decoder.dateDecodingStrategy = .formatted(formatter)
                
                let decodedResponse = try decoder.decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // ── AUTH MODULE ───────────────────────────────────────────
    
    struct APIResponse<T: Decodable>: Decodable {
        let success: Bool
        let message: String
        let data: T?
    }
    
    struct UserResponse: Decodable {
        let id: String
        let email: String?
        let phone: String?
        let name: String?
        let profileCompleted: Bool
    }
    
    struct AuthData: Decodable {
        let accessToken: String
        let refreshToken: String
        let user: UserResponse
    }
    
    struct RegisterResponse: Decodable {
        let userId: String
    }
    
    struct SendOTPResponse: Decodable {
        let expiresIn: Int
        let otpCode: String?
    }
    
    func register(email: String, name: String, completion: @escaping (Result<APIResponse<RegisterResponse>, Error>) -> Void) {
        performRequest(endpoint: "auth/register", method: "POST", body: [
            "email": email,
            "name": name,
            "password": "DefaultPassword123!" // Password tạm mặc định khi đăng ký nhanh
        ], completion: completion)
    }
    
    func sendOTP(target: String, type: String, purpose: String, completion: @escaping (Result<APIResponse<SendOTPResponse>, Error>) -> Void) {
        performRequest(endpoint: "auth/send-otp", method: "POST", body: [
            "target": target,
            "type": type,
            "purpose": purpose
        ], completion: completion)
    }
    
    func verifyOTP(target: String, otpCode: String, purpose: String, completion: @escaping (Result<APIResponse<AuthData>, Error>) -> Void) {
        performRequest(endpoint: "auth/verify-otp", method: "POST", body: [
            "target": target,
            "otpCode": otpCode,
            "purpose": purpose
        ]) { (result: Result<APIResponse<AuthData>, Error>) in
            switch result {
            case .success(let response):
                if response.success, let authData = response.data {
                    self.setTokens(access: authData.accessToken, refresh: authData.refreshToken)
                }
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func saveProfileInfo(name: String, gender: String, dob: String, completion: @escaping (Result<APIResponse<UserResponse>, Error>) -> Void) {
        // Dob dạng YYYY-MM-DD
        performRequest(endpoint: "auth/profile", method: "PUT", body: [
            "name": name,
            "gender": gender,
            "dateOfBirth": dob
        ], completion: completion)
    }
    
    // ── SOCIAL LOGIN ─────────────────────────────────────────
    
    func loginWithGoogle(idToken: String, completion: @escaping (Result<APIResponse<AuthData>, Error>) -> Void) {
        performRequest(endpoint: "auth/google", method: "POST", body: [
            "idToken": idToken
        ]) { (result: Result<APIResponse<AuthData>, Error>) in
            switch result {
            case .success(let response):
                if response.success, let authData = response.data {
                    self.setTokens(access: authData.accessToken, refresh: authData.refreshToken)
                }
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func loginWithFacebook(accessToken fbToken: String, completion: @escaping (Result<APIResponse<AuthData>, Error>) -> Void) {
        performRequest(endpoint: "auth/facebook", method: "POST", body: [
            "accessToken": fbToken
        ]) { (result: Result<APIResponse<AuthData>, Error>) in
            switch result {
            case .success(let response):
                if response.success, let authData = response.data {
                    self.setTokens(access: authData.accessToken, refresh: authData.refreshToken)
                }
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func hasValidToken() -> Bool {
        return accessToken != nil && !(accessToken?.isEmpty ?? true)
    }
    
    // ── CYCLE MODULE ──────────────────────────────────────────
    
    struct ProfileResponse: Decodable {
        let id: String
        let profile_name: String
        let avg_cycle_length: Int
        let avg_period_duration: Int
        let last_period_start: String?
        let relationship: String?
    }
    
    struct DashboardData: Decodable {
        let hasProfile: Bool
        let profile: ProfileResponse?
        let currentDayOfCycle: Int?
        let currentPhase: String?
        let currentFertilityLevel: String?
        let conceptionProbability: Double?
        let nextPeriodDate: String?
        let nextOvulationDate: String?
        let daysUntilNextPeriod: Int?
        let forecast: [ForecastEntry]?
        let profiles: [ProfileResponse]?
    }
    
    struct ForecastEntry: Decodable {
        let cycleNumber: Int
        let predictedPeriodStart: String
        let predictedPeriodEnd: String
        let predictedOvulationDay: String
    }
    
    struct CycleListResponse: Decodable {
        let profiles: [ProfileResponse]
    }
    
    struct CreateProfileResponse: Decodable {
        let id: String
    }
    
    struct FertileWindowResponse: Decodable {
        let start: String
        let end: String
    }
    
    struct LogPeriodResponse: Decodable {
        let logId: String
        let cycleLength: Int
        let periodDuration: Int
        let ovulationDate: String
        let fertileWindow: FertileWindowResponse
    }
    
    struct ServerLogEntry: Decodable {
        let id: String
        let profile_id: String
        let period_start_date: String
        let period_end_date: String?
        let notes: String?
    }
    
    struct HistoryResponse: Decodable {
        let logs: [ServerLogEntry]
    }
    
    func createCycleProfile(id: String?, name: String, relationship: String, length: Int, duration: Int, lastStart: String, completion: @escaping (Result<APIResponse<CreateProfileResponse>, Error>) -> Void) {
        var body: [String: Any] = [
            "profileName": name,
            "relationship": relationship,
            "avgCycleLength": length,
            "avgPeriodDuration": duration,
            "lastPeriodStart": lastStart
        ]
        if let id = id {
            body["id"] = id
        }
        performRequest(endpoint: "cycles/profiles", method: "POST", body: body, completion: completion)
    }
    
    func updateCycleProfile(id: String, name: String, relationship: String, length: Int, duration: Int, lastStart: String, completion: @escaping (Result<APIResponse<CreateProfileResponse>, Error>) -> Void) {
        performRequest(endpoint: "cycles/profiles/\(id)", method: "PUT", body: [
            "profileName": name,
            "relationship": relationship,
            "avgCycleLength": length,
            "avgPeriodDuration": duration,
            "lastPeriodStart": lastStart
        ], completion: completion)
    }
    
    func deleteCycleProfile(id: String, completion: @escaping (Result<APIResponse<CreateProfileResponse>, Error>) -> Void) {
        performRequest(endpoint: "cycles/profiles/\(id)", method: "DELETE", completion: completion)
    }
    
    func getDashboard(completion: @escaping (Result<APIResponse<DashboardData>, Error>) -> Void) {
        performRequest(endpoint: "cycles/dashboard", method: "GET", completion: completion)
    }
    
    func logPeriod(id: String?, profileId: String, startDate: String, endDate: String?, intensity: String, completion: @escaping (Result<APIResponse<LogPeriodResponse>, Error>) -> Void) {
        var body: [String: Any] = [
            "profileId": profileId,
            "periodStartDate": startDate,
            "flowIntensity": intensity
        ]
        if let id = id {
            body["id"] = id
        }
        if let endDate = endDate {
            body["periodEndDate"] = endDate
        }
        performRequest(endpoint: "cycles/logs", method: "POST", body: body, completion: completion)
    }
    
    func getCycleHistory(profileId: String, completion: @escaping (Result<APIResponse<HistoryResponse>, Error>) -> Void) {
        performRequest(endpoint: "cycles/logs?profileId=\(profileId)&limit=100", method: "GET", completion: completion)
    }
    
    // ── NUTRITION MODULE ──────────────────────────────────────
    
    struct FoodItem: Decodable, Identifiable {
        let id: String
        let name_vi: String
        let name_en: String?
        let category_id: String?
        let image_url: String?
        let energy_kcal: String?
        let protein_g: String?
        let lipid_g: String?
        let carbohydrate_g: String?
        let fiber_g: String?
    }
    
    struct FoodSearchResponse: Decodable {
        let foods: [FoodItem]
        let total: Int
        let page: Int
    }
    
    struct FoodCategory: Decodable, Identifiable {
        let id: String
        let name_vi: String
        let name_en: String?
    }
    
    struct CategoryListResponse: Decodable {
        let categories: [FoodCategory]
    }
    
    struct MealLog: Decodable, Identifiable {
        let id: String
        let meal_type: String
        let food_name: String
        let serving_size_g: String
        let calories: String
        let protein: String
        let fat: String
        let carbs: String
    }
    
    struct DailySummary: Decodable {
        let total_calories: String?
        let total_protein: String?
        let total_fat: String?
        let total_carbs: String?
        let total_fiber: String?
    }
    
    struct MealListResponse: Decodable {
        let meals: [MealLog]
        let summary: DailySummary
    }
    
    func fetchNutritionCategories(completion: @escaping (Result<APIResponse<CategoryListResponse>, Error>) -> Void) {
        performRequest(endpoint: "nutrition/foods/categories", method: "GET", completion: completion)
    }
    
    func searchFoods(query: String, categoryId: String?, completion: @escaping (Result<APIResponse<FoodSearchResponse>, Error>) -> Void) {
        var endpoint = "nutrition/foods/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let catId = categoryId {
            endpoint += "&category=\(catId)"
        }
        performRequest(endpoint: endpoint, method: "GET", completion: completion)
    }
    
    struct LogMealResponse: Decodable {
        let id: String
        let calories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
    }
    
    struct EmptyResponse: Decodable {}
    
    func logMeal(date: String, mealType: String, foodId: String?, foodName: String, servingSize: Double, calories: Double? = nil, protein: Double? = nil, fat: Double? = nil, carbs: Double? = nil, completion: @escaping (Result<APIResponse<LogMealResponse>, Error>) -> Void) {
        var body: [String: Any] = [
            "logDate": date,
            "mealType": mealType,
            "foodName": foodName,
            "servingSize": servingSize
        ]
        if let foodId = foodId {
            body["foodId"] = foodId
        }
        if let calories = calories { body["calories"] = calories }
        if let protein = protein { body["protein"] = protein }
        if let fat = fat { body["fat"] = fat }
        if let carbs = carbs { body["carbs"] = carbs }
        
        performRequest(endpoint: "nutrition/meals", method: "POST", body: body, completion: completion)
    }
    
    func getMealsForDay(date: String, completion: @escaping (Result<APIResponse<MealListResponse>, Error>) -> Void) {
        performRequest(endpoint: "nutrition/meals?date=\(date)", method: "GET", completion: completion)
    }
    
    func deleteMeal(id: String, completion: @escaping (Result<APIResponse<EmptyResponse>, Error>) -> Void) {
        performRequest(endpoint: "nutrition/meals/\(id)", method: "DELETE", completion: completion)
    }
}
