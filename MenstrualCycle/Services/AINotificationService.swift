//
//  AINotificationService.swift
//  MenstrualCycle
//
//  Dịch vụ sinh thông báo cá nhân hóa bằng AI.
//  Chuẩn bị cấu trúc gọi Gemini API.
//  Tương thích iOS 15+.
//

import Foundation

/// Service sinh lời thông báo / nhắc nhở cá nhân hóa
class AINotificationService {

    // MARK: - Singleton
    static let shared = AINotificationService()
    private init() {}

    // MARK: - Gemini API Configuration
    /// Thay bằng API Key thực khi tích hợp Gemini
    private let apiKey = "YOUR_GEMINI_API_KEY"
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"

    // MARK: - Sinh thông báo Local (Fallback khi không có API)

    /// Sinh thông báo cá nhân hóa dựa trên quan hệ và trạng thái chu kỳ
    func generateLocalNotification(
        userName: String,
        profileName: String,
        relationship: ProfileRelationship,
        phase: CyclePhase,
        daysUntilNextPeriod: Int,
        daysUntilOvulation: Int
    ) -> String {
        let petName = relationship.petName
        let displayName = profileName.isEmpty ? "bạn ấy" : profileName

        switch relationship {
        case .myself:
            return generateSelfMessage(
                userName: userName,
                phase: phase,
                daysUntilNextPeriod: daysUntilNextPeriod,
                daysUntilOvulation: daysUntilOvulation
            )
        case .lover, .wife:
            return generatePartnerMessage(
                userName: userName,
                profileName: displayName,
                petName: petName,
                phase: phase,
                daysUntilNextPeriod: daysUntilNextPeriod
            )
        case .mother:
            return generateMotherMessage(
                userName: userName,
                profileName: displayName,
                phase: phase,
                daysUntilNextPeriod: daysUntilNextPeriod
            )
        case .sister, .younger:
            return generateSiblingMessage(
                userName: userName,
                profileName: displayName,
                petName: petName,
                phase: phase,
                daysUntilNextPeriod: daysUntilNextPeriod
            )
        case .friend:
            return generateFriendMessage(
                userName: userName,
                profileName: displayName,
                phase: phase,
                daysUntilNextPeriod: daysUntilNextPeriod
            )
        case .daughter, .niece:
            return generateChildMessage(
                userName: userName,
                profileName: displayName,
                petName: petName,
                phase: phase,
                daysUntilNextPeriod: daysUntilNextPeriod
            )
        }
    }

    // MARK: - Private Message Generators

    private func generateSelfMessage(
        userName: String,
        phase: CyclePhase,
        daysUntilNextPeriod: Int,
        daysUntilOvulation: Int
    ) -> String {
        let name = userName.isEmpty ? "bạn" : userName
        switch phase {
        case .menstruation:
            return "Theo Tổ chức Y tế Thế giới (WHO), cơ thể \(name) đang trong giai đoạn nhạy cảm nhất 🩸 Hãy bổ sung sắt, giữ ấm cơ thể và hạn chế vận động mạnh nhé!"
        case .follicular:
            return "Theo Hiệp hội Sản phụ khoa Hoa Kỳ (ACOG), hormone estrogen của \(name) đang tăng dần 🌱 Đây là thời điểm vàng để tái tạo năng lượng và tập luyện nhẹ nhàng."
        case .ovulation:
            return "Chỉ số y khoa (ACOG): Ngày rụng trứng của \(name) đang đến rất gần 🥚 Cơ thể đang ở trạng thái rực rỡ và dễ thụ thai nhất, hãy lắng nghe cơ thể nhé!"
        case .luteal:
            return "Căn cứ y học chu kỳ: Kỳ kinh của \(name) còn \(daysUntilNextPeriod) ngày nữa 🌙 Mức progesterone đang thay đổi, hãy ngủ đủ giấc và giảm bớt căng thẳng nhé!"
        case .preMenstrual:
            return "Theo khuyến nghị sức khỏe nữ giới (WHO): Kỳ kinh của \(name) sắp bắt đầu ⚡ Hãy uống nước ấm, chuẩn bị sẵn đồ dùng và nghỉ ngơi hợp lý nhé!"
        case .unknown:
            return "Nàng thơ \(name) ơi, hãy nhập ngày bắt đầu kỳ kinh gần nhất để hệ thống dựa trên tiêu chuẩn WHO phân tích chu kỳ giúp bạn nhé! 💕"
        }
    }

    private func generatePartnerMessage(
        userName: String, profileName: String, petName: String,
        phase: CyclePhase, daysUntilNextPeriod: Int
    ) -> String {
        let name = userName.isEmpty ? "bạn" : userName
        switch phase {
        case .menstruation:
            return "Khuyến nghị chăm sóc từ WHO: \(profileName) đang trong kỳ kinh 🩸 Hãy chuẩn bị túi chườm ấm, nhắc cô ấy nghỉ ngơi và tránh làm việc nặng nhé!"
        case .ovulation:
            return "Chỉ dẫn y khoa ACOG: \(profileName) đang ở giai đoạn rụng trứng 💝 Cơ thể cô ấy đang tràn đầy năng lượng tích cực nhất, hãy cùng chia sẻ khoảnh khắc nhé!"
        case .preMenstrual:
            return "Theo tâm lý học nội tiết (ACOG): Kỳ kinh của \(profileName) sắp tới ⚡ Hãy kiên nhẫn, chuẩn bị sẵn trà ấm và giúp cô ấy giảm bớt căng thẳng nhé!"
        default:
            return "Chăm sóc chu kỳ: Kỳ kinh tiếp theo của \(profileName) còn \(daysUntilNextPeriod) ngày nữa 🌸 Hãy cùng cô ấy duy trì chế độ dinh dưỡng lành mạnh theo chuẩn WHO."
        }
    }

    private func generateMotherMessage(
        userName: String, profileName: String,
        phase: CyclePhase, daysUntilNextPeriod: Int
    ) -> String {
        let name = userName.isEmpty ? "bạn" : userName
        switch phase {
        case .menstruation:
            return "Khuyến nghị y khoa cho tuổi trung niên (WHO): Mẹ đang trong kỳ kinh 💐 Hãy gọi điện hỏi thăm mẹ, mang cho mẹ ít trái cây tươi giàu vitamin nhé!"
        case .preMenstrual:
            return "Chăm sóc sức khỏe gia đình: Mẹ sắp bước vào kỳ kinh tiếp theo 🌷 Hãy nhắc mẹ nghỉ ngơi, uống nước ấm để giảm mệt mỏi theo lời khuyên của bác sĩ."
        default:
            return "Quan tâm sức khỏe của mẹ: Kỳ kinh của mẹ còn \(daysUntilNextPeriod) ngày nữa 💐 Hãy cùng mẹ đi dạo nhẹ nhàng để tăng cường sức đề kháng theo khuyến nghị WHO."
        }
    }

    private func generateSiblingMessage(
        userName: String, profileName: String, petName: String,
        phase: CyclePhase, daysUntilNextPeriod: Int
    ) -> String {
        let name = userName.isEmpty ? "bạn" : userName
        switch phase {
        case .menstruation:
            return "Khuyên bảo sức khỏe nữ giới (WHO): \(profileName) đang trong kỳ kinh 🌷 Nhắc chị/em uống nước ấm, ăn nhẹ thanh đạm để giảm cảm giác đầy bụng."
        case .preMenstrual:
            return "Lời khuyên y tế (ACOG): Kỳ kinh của \(profileName) sắp tới ⚡ Hãy khuyên chị/em ngủ sớm, tránh thức khuya để cân bằng nội tiết tố."
        default:
            return "Đồng hành sức khỏe: Kỳ kinh của \(profileName) còn \(daysUntilNextPeriod) ngày 🌸 Nhắc chị/em duy trì chế độ sinh hoạt điều độ theo chuẩn y khoa."
        }
    }

    private func generateFriendMessage(
        userName: String, profileName: String,
        phase: CyclePhase, daysUntilNextPeriod: Int
    ) -> String {
        let name = userName.isEmpty ? "bạn" : userName
        switch phase {
        case .menstruation:
            return "Lời khuyên chăm sóc (WHO): Bạn thân \(profileName) đang trong kỳ kinh 💕 Hãy chia sẻ công việc hoặc rủ cô ấy nghỉ ngơi thư giãn nhẹ nhàng nhé!"
        case .preMenstrual:
            return "Lưu ý chu kỳ (ACOG): Bạn thân \(profileName) sắp tới kỳ kinh ⚡ Hãy nhẹ nhàng hỏi thăm và nhắc cô ấy uống nhiều nước ấm giảm mệt mỏi."
        default:
            return "Quan tâm bạn bè: Kỳ kinh của \(profileName) còn \(daysUntilNextPeriod) ngày nữa 💕 Luôn là người bạn tinh tế đồng hành cùng cô ấy nhé!"
        }
    }

    private func generateChildMessage(
        userName: String, profileName: String, petName: String,
        phase: CyclePhase, daysUntilNextPeriod: Int
    ) -> String {
        let name = userName.isEmpty ? "bạn" : userName
        switch phase {
        case .menstruation:
            return "Hướng dẫn của ACOG cho trẻ vị thành niên: Bé \(profileName) đang trong kỳ kinh 🧒 Hãy hướng dẫn bé vệ sinh đúng cách, chườm ấm và giữ ấm cơ thể nhé."
        case .preMenstrual:
            return "Lời khuyên giáo dục giới tính (WHO): Bé \(profileName) sắp tới kỳ kinh ⚡ Hãy chuẩn bị sẵn băng vệ sinh cho bé và động viên tinh thần để bé bớt lo lắng."
        default:
            return "Bảo vệ sức khỏe của bé: Kỳ kinh của bé còn \(daysUntilNextPeriod) ngày 🌺 Hãy giúp bé duy trì ăn uống đầy đủ chất dinh dưỡng theo tháp dinh dưỡng WHO."
        }
    }

    // MARK: - Gemini API Call (Chuẩn bị sẵn)

    /// Gọi Gemini API để sinh thông báo (cần API Key thực)
    func generateAINotification(
        userName: String,
        profileName: String,
        relationship: ProfileRelationship,
        phase: CyclePhase,
        daysUntilNextPeriod: Int,
        completion: @escaping (String) -> Void
    ) {
        // Kiểm tra API key
        guard apiKey != "YOUR_GEMINI_API_KEY" else {
            // Fallback về local notification
            let message = generateLocalNotification(
                userName: userName,
                profileName: profileName,
                relationship: relationship,
                phase: phase,
                daysUntilNextPeriod: daysUntilNextPeriod,
                daysUntilOvulation: 0
            )
            completion(message)
            return
        }

        // ── Chuẩn bị prompt cho Gemini ──────────────────
        let prompt = """
        Bạn là trợ lý sức khỏe nữ giới chuyên nghiệp. Hãy viết một câu thông báo nhắc nhở về chu kỳ kinh nguyệt bằng tiếng Việt.
        
        Thông tin:
        - Người dùng: \(userName)
        - Đối tượng theo dõi: \(profileName)
        - Mối quan hệ: \(relationship.rawValue)
        - Danh xưng thân mật: \(relationship.petName)
        - Giai đoạn hiện tại: \(phase.rawValue)
        - Số ngày đến kỳ kinh tiếp theo: \(daysUntilNextPeriod)
        
        Yêu cầu bắt buộc:
        - Phải trích dẫn hoặc căn cứ theo hướng dẫn y học uy tín từ Tổ chức Y tế Thế giới (WHO) hoặc Hiệp hội Sản phụ khoa Hoa Kỳ (ACOG).
        - Văn phong tình cảm, tự nhiên nhưng chuyên nghiệp, ấm áp.
        - Bao gồm lời khuyên sức khỏe cụ thể cho giai đoạn này.
        - Dùng emoji phù hợp.
        - Độ dài: 1-2 câu.
        """

        // ── Tạo request body ───────────────────────────
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)"),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(generateLocalNotification(
                userName: userName, profileName: profileName,
                relationship: relationship, phase: phase,
                daysUntilNextPeriod: daysUntilNextPeriod, daysUntilOvulation: 0
            ))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // ── Gọi API ────────────────────────────────────
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                DispatchQueue.main.async {
                    completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            } else {
                // Fallback
                let fallback = self.generateLocalNotification(
                    userName: userName, profileName: profileName,
                    relationship: relationship, phase: phase,
                    daysUntilNextPeriod: daysUntilNextPeriod, daysUntilOvulation: 0
                )
                DispatchQueue.main.async {
                    completion(fallback)
                }
            }
        }.resume()
    }
}
