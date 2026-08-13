//
//  NutritionProfile.swift
//  MenstrualCycle
//
//  Model cho thông tin dinh dưỡng & BMI.
//  Sẽ được mở rộng ở Bước 3.
//  Tương thích iOS 15+.
//

import Foundation

/// Phân loại trạng thái BMI
enum BMICategory: String {
    case severelUnderweight = "Nên tăng cân rất mạnh"
    case underweight        = "Nên tăng cân"
    case slightlyUnderweight = "Nên tăng cân nhẹ"
    case normal             = "Nên duy trì cân nặng"
    case slightlyOverweight = "Nên giảm cân nhẹ"
    case overweight         = "Nên giảm cân"
    case obese              = "Hãy cùng nỗ lực mỗi ngày"

    /// Xác định BMICategory từ chỉ số BMI
    static func from(bmi: Double) -> BMICategory {
        switch bmi {
        case ..<16.0:          return .severelUnderweight
        case 16.0..<17.0:      return .underweight
        case 17.0..<18.5:      return .slightlyUnderweight
        case 18.5..<25.0:      return .normal
        case 25.0..<27.5:      return .slightlyOverweight
        case 27.5..<30.0:      return .overweight
        default:               return .obese
        }
    }
}

/// Thông tin dinh dưỡng của người dùng
struct NutritionProfile {
    var heightCm: Double = 0
    var weightKg: Double = 0

    /// Tính chỉ số BMI
    var bmi: Double {
        guard heightCm > 0 else { return 0 }
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    var category: BMICategory {
        BMICategory.from(bmi: bmi)
    }
}

/// Một bữa ăn trong nhật ký
struct MealEntry: Identifiable {
    let id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var date: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        date: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.date = date
    }
}
