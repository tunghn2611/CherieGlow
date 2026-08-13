//
//  NutritionViewModel.swift
//  MenstrualCycle
//
//  ViewModel quản lý Dinh dưỡng & BMI.
//  Kết nối SQLite qua NutritionRepository.
//  Tương thích iOS 15+.
//

import SwiftUI
import Combine

final class NutritionViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var heightCm: String = ""
    @Published var weightKg: String = ""
    @Published var meals: [MealEntry] = []
    @Published var foodInputText: String = ""
    @Published var isAnalyzingFood: Bool = false
    @Published var showManualEntry: Bool = false
    @Published var selectedDate: Date = Date()
    @Published var showAddMeal: Bool = false
    @Published var showFoodLookup: Bool = false

    // MARK: - Repository
    private let nutritionRepo = NutritionRepository()
    private var userId: String = ""

    // MARK: - Vietnamese Food Dictionary
    private let foodDatabase: [String: (cal: Double, protein: Double, carbs: Double, fat: Double)] = [
        "phở bò":       (450, 25, 55, 12),
        "cơm gà":       (550, 30, 65, 15),
        "bún chả":      (480, 28, 50, 18),
        "bánh mì":      (350, 15, 45, 12),
        "sinh tố bơ":   (280,  5, 35, 15),
        "gỏi cuốn":     (200, 12, 25,  5),
        "chả giò":      (320, 10, 30, 18),
        "cơm tấm":      (620, 35, 70, 20),
        "bún bò huế":   (520, 30, 55, 16),
        "xôi":          (380,  8, 65,  8),
        "cháo gà":      (300, 18, 40,  6),
        "trà sữa":      (350,  3, 55, 12)
    ]

    // MARK: - Init
    init() {}

    // MARK: - Set User & Load Data

    func setUserId(_ id: String) {
        self.userId = id
        loadProfile()
        loadMeals()
    }

    func loadProfile() {
        guard !userId.isEmpty else { return }
        if let profile = nutritionRepo.getProfile(for: userId) {
            if profile.heightCm > 0 {
                heightCm = String(format: "%.0f", profile.heightCm)
            }
            if profile.weightKg > 0 {
                weightKg = String(format: "%.1f", profile.weightKg)
            }
        }
    }

    func loadMeals() {
        guard !userId.isEmpty else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)
        
        APIService.shared.getMealsForDay(date: dateStr) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    if response.success, let data = response.data {
                        // Nhận danh sách meal từ server
                        self.meals = data.meals.map { sMeal in
                            MealEntry(
                                id: UUID(uuidString: sMeal.id) ?? UUID(),
                                name: sMeal.food_name,
                                calories: Double(sMeal.calories) ?? 0,
                                protein: Double(sMeal.protein) ?? 0,
                                carbs: Double(sMeal.carbs) ?? 0,
                                fat: Double(sMeal.fat) ?? 0,
                                date: self.selectedDate
                            )
                        }
                    }
                case .failure(let error):
                    print("⚠️ [NUTRITION-LOAD] Lỗi đồng bộ server: \(error.localizedDescription)")
                    // Offline fallback
                    self.meals = self.nutritionRepo.fetchMeals(for: self.userId, on: self.selectedDate)
                }
            }
        }
    }

    func saveProfile() {
        guard !userId.isEmpty else { return }
        let h = Double(heightCm) ?? 0
        let w = Double(weightKg) ?? 0
        let _ = nutritionRepo.saveProfile(userId: userId, heightCm: h, weightKg: w)
    }

    // MARK: - Computed – BMI

    var bmi: Double {
        guard let h = Double(heightCm), let w = Double(weightKg),
              h > 0, w > 0 else { return 0 }
        let heightM = h / 100.0
        return w / (heightM * heightM)
    }

    var bmiCategory: BMICategory {
        BMICategory.from(bmi: bmi)
    }

    var bmiAdvice: String {
        switch bmiCategory {
        case .severelUnderweight:
            return "Cơ thể bạn cần được bổ sung nhiều năng lượng hơn. Hãy ăn thêm các bữa phụ giàu dinh dưỡng nhé! 💪"
        case .underweight:
            return "Hãy tăng cường dinh dưỡng mỗi ngày, bổ sung protein và chất béo lành mạnh 🥑"
        case .slightlyUnderweight:
            return "Bạn chỉ cần thêm một chút dinh dưỡng nữa thôi. Ăn đa dạng hơn nhé! 🍎"
        case .normal:
            return "Tuyệt vời! Bạn đang có chỉ số BMI lý tưởng. Hãy duy trì chế độ ăn lành mạnh 🌟"
        case .slightlyOverweight:
            return "Hãy chú ý thêm về khẩu phần và tăng cường vận động nhẹ nhàng mỗi ngày 🚶‍♀️"
        case .overweight:
            return "Bạn đang làm rất tốt khi quan tâm đến sức khỏe! Hãy điều chỉnh chế độ ăn từ từ nhé 🌿"
        case .obese:
            return "Bạn đang trên hành trình trở nên tuyệt vời hơn mỗi ngày! Hãy bắt đầu với những thay đổi nhỏ trong chế độ ăn 🌸"
        }
    }

    var bmiColor: Color {
        switch bmiCategory {
        case .severelUnderweight, .underweight:
            return .lavender
        case .slightlyUnderweight:
            return .mintGreen
        case .normal:
            return .mintGreen
        case .slightlyOverweight:
            return .peachYellow
        case .overweight:
            return .coralRed
        case .obese:
            return .coralRed
        }
    }

    var bmiProgress: Double {
        guard bmi > 0 else { return 0 }
        let clamped = min(max(bmi, 15), 40)
        return (clamped - 15) / 25.0
    }

    // MARK: - Computed – Macros

    var todayMeals: [MealEntry] { meals }

    var todayCalories: Double { meals.reduce(0) { $0 + $1.calories } }
    var todayProtein: Double { meals.reduce(0) { $0 + $1.protein } }
    var todayCarbs: Double { meals.reduce(0) { $0 + $1.carbs } }
    var todayFat: Double { meals.reduce(0) { $0 + $1.fat } }

    var calorieGoal: Double {
        switch bmiCategory {
        case .severelUnderweight, .underweight, .slightlyUnderweight: return 2500
        case .normal: return 2000
        case .slightlyOverweight, .overweight, .obese: return 1500
        }
    }

    var proteinGoal: Double { 80 }
    var carbsGoal: Double { 250 }
    var fatGoal: Double { 65 }

    // MARK: - Methods

    func addMeal(_ meal: MealEntry) {
        guard !userId.isEmpty else { return }
        
        // 1. Lưu offline cục bộ
        let _ = nutritionRepo.insertMeal(meal, userId: userId)
        
        // 2. Gửi lên backend server
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)
        
        APIService.shared.logMeal(
            date: dateStr,
            mealType: "lunch",
            foodId: nil,
            foodName: meal.name,
            servingSize: 100,
            calories: meal.calories,
            protein: meal.protein,
            fat: meal.fat,
            carbs: meal.carbs
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    if response.success {
                        self.loadMeals()
                    }
                case .failure(let error):
                    print("⚠️ [NUTRITION-LOG] Failed to sync to server: \(error.localizedDescription)")
                }
            }
        }
    }

    func deleteMeal(at offsets: IndexSet) {
        let mealsToDelete = offsets.map { meals[$0] }
        for meal in mealsToDelete {
            let _ = nutritionRepo.deleteMeal(id: meal.id.uuidString)
            APIService.shared.deleteMeal(id: meal.id.uuidString) { _ in
                print("🗑️ Deleted meal on server")
            }
        }
        loadMeals()
    }

    func onDateChanged() {
        loadMeals()
    }

    func analyzeFood() {
        let query = foodInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isAnalyzingFood = true
        
        // Gọi API tìm kiếm món ăn từ cơ sở dữ liệu Viện Dinh Dưỡng ở Backend
        APIService.shared.searchFoods(query: query, categoryId: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAnalyzingFood = false
                
                switch result {
                case .success(let response):
                    if response.success, let foods = response.data?.foods, let firstMatch = foods.first {
                        // Tự động log món ăn đầu tiên tìm thấy
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        let dateStr = formatter.string(from: self.selectedDate)
                        
                        APIService.shared.logMeal(
                            date: dateStr,
                            mealType: "lunch",
                            foodId: firstMatch.id,
                            foodName: firstMatch.name_vi,
                            servingSize: 100
                        ) { [weak self] logResult in
                            DispatchQueue.main.async {
                                guard let self = self else { return }
                                if case .success = logResult {
                                    self.foodInputText = ""
                                    self.loadMeals()
                                }
                            }
                        }
                    } else {
                        // Không tìm thấy món khớp, chuyển qua nhập thủ công
                        self.showManualEntry = true
                    }
                case .failure:
                    self.showManualEntry = true
                }
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
