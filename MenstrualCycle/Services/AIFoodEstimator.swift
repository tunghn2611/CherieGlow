//
//  AIFoodEstimator.swift
//  MenstrualCycle
//
//  Ước tính hàm lượng dinh dưỡng bằng Gemini AI khi món ăn
//  không có trong cơ sở dữ liệu Viện Dinh Dưỡng.
//  Tương thích iOS 15+.
//

import Foundation

final class AIFoodEstimator {

    static let shared = AIFoodEstimator()
    private init() {}

    // Tái sử dụng cùng API config với AINotificationService
    private let apiKey = "YOUR_GEMINI_API_KEY"
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    // MARK: - Estimate Nutrition

    /// Gọi Gemini AI để ước tính dinh dưỡng của món ăn
    func estimateNutrition(query: String, completion: @escaping (FoodItem?) -> Void) {
        let prompt = """
        Bạn là chuyên gia dinh dưỡng Việt Nam. Hãy ước tính hàm lượng dinh dưỡng cho món ăn sau:

        Món ăn: "\(query)"

        Trả về KẾT QUẢ DUY NHẤT ở định dạng JSON thuần (không markdown, không ```) với cấu trúc chính xác sau:
        {
            "name": "Tên món ăn (tiếng Việt, có dấu)",
            "category": "Phân loại (Cơm/Phở-Bún-Mì/Bánh/Khai vị/Đồ uống/Trái cây/Rau củ/Thịt-Cá/Hải sản/Chè-Tráng miệng/Canh-Súp/Xôi-Cháo)",
            "icon": "emoji phù hợp",
            "unit": "đơn vị (ví dụ: 1 tô, 1 đĩa, 1 ly)",
            "servingGrams": khối lượng gram,
            "calories": kcal,
            "protein": gram,
            "carbs": gram,
            "fat": gram,
            "fiber": gram,
            "vitaminA": mcg,
            "vitaminC": mg,
            "vitaminB1": mg,
            "vitaminB2": mg,
            "calcium": mg,
            "iron": mg,
            "sodium": mg,
            "sugar": gram,
            "cholesterol": mg
        }

        Lưu ý:
        - Giá trị phải THỰC TẾ, dựa trên dữ liệu dinh dưỡng chuẩn
        - Tất cả giá trị số phải là số, không phải chuỗi
        - Chỉ trả về JSON, không kèm giải thích
        """

        callGeminiAPI(prompt: prompt) { [weak self] text in
            guard let self = self, let text = text else {
                completion(nil)
                return
            }
            let parsed = self.parseGeminiResponse(text: text, query: query)
            completion(parsed)
        }
    }

    // MARK: - Parse AI Response

    private func parseGeminiResponse(text: String, query: String) -> FoodItem? {
        // Loại bỏ markdown code blocks nếu có
        var cleanText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Tìm JSON object đầu tiên
        if let startIdx = cleanText.firstIndex(of: "{"),
           let endIdx = cleanText.lastIndex(of: "}") {
            cleanText = String(cleanText[startIdx...endIdx])
        }

        guard let data = cleanText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ [AIFood] Failed to parse JSON from AI response")
            return nil
        }

        let name = (json["name"] as? String) ?? query
        let category = (json["category"] as? String) ?? "Khác"
        let icon = (json["icon"] as? String) ?? "🍽"
        let unit = (json["unit"] as? String) ?? "1 phần"
        let servingGrams = (json["servingGrams"] as? Int) ?? 100

        return FoodItem(
            id: "ai_\(UUID().uuidString.prefix(8))",
            name: name,
            aliases: [],
            category: category,
            icon: icon,
            unit: unit,
            servingGrams: servingGrams,
            calories: toDouble(json["calories"]),
            protein: toDouble(json["protein"]),
            carbs: toDouble(json["carbs"]),
            fat: toDouble(json["fat"]),
            fiber: toDouble(json["fiber"]),
            vitaminA: toDouble(json["vitaminA"]),
            vitaminC: toDouble(json["vitaminC"]),
            vitaminB1: toDouble(json["vitaminB1"]),
            vitaminB2: toDouble(json["vitaminB2"]),
            calcium: toDouble(json["calcium"]),
            iron: toDouble(json["iron"]),
            sodium: toDouble(json["sodium"]),
            sugar: toDouble(json["sugar"]),
            cholesterol: toDouble(json["cholesterol"]),
            source: .aiEstimated
        )
    }

    private func toDouble(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) ?? 0 }
        return 0
    }

    // MARK: - Gemini API Call

    private func callGeminiAPI(prompt: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 512
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async {
                completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }.resume()
    }
}
