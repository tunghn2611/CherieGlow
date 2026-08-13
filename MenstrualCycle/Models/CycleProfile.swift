//
//  CycleProfile.swift
//  MenstrualCycle
//
//  Model cho đối tượng theo dõi chu kỳ (Multi-profile).
//  Sẽ được mở rộng ở Bước 2.
//  Tương thích iOS 15+.
//

import Foundation

/// Mối quan hệ với đối tượng theo dõi
enum ProfileRelationship: String, CaseIterable, Identifiable {
    case myself     = "Chính bạn"
    case mother     = "Mẹ"
    case sister     = "Chị"
    case younger    = "Em gái"
    case friend     = "Bạn bè"
    case lover      = "Người yêu"
    case wife       = "Vợ"
    case daughter   = "Con gái"
    case niece      = "Cháu gái"

    var id: String { rawValue }

    /// Biểu tượng cảm xúc đại diện
    var emoji: String {
        switch self {
        case .myself:   return "🌸"
        case .mother:   return "💐"
        case .sister:   return "👩‍👩‍👧"
        case .younger:  return "🌷"
        case .friend:   return "💕"
        case .lover:    return "❤️"
        case .wife:     return "💍"
        case .daughter: return "🧒"
        case .niece:    return "🌺"
        }
    }

    /// Danh xưng thân mật cho AI notification
    var petName: String {
        switch self {
        case .myself:   return "Nàng thơ"
        case .mother:   return "Người tuyệt vời nhất của bạn"
        case .sister:   return "Tình thân của bạn"
        case .younger:  return "Tình thân của bạn"
        case .friend:   return "Nàng bạn thân thiết"
        case .lover:    return "Em bé của bạn"
        case .wife:     return "Em bé của bạn"
        case .daughter: return "Cục vàng bé bỏng của bạn"
        case .niece:    return "Cục vàng bé bỏng của bạn"
        }
    }
}

/// Hồ sơ chu kỳ của một đối tượng
struct CycleProfile: Identifiable {
    let id: UUID
    var name: String
    var relationship: ProfileRelationship
    var lastPeriodStart: Date?
    var periodDuration: Int              // 2–7 ngày
    var cycleLength: Int                 // Trung bình 28 ngày
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        relationship: ProfileRelationship = .myself,
        lastPeriodStart: Date? = nil,
        periodDuration: Int = 5,
        cycleLength: Int = 28,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.lastPeriodStart = lastPeriodStart
        self.periodDuration = periodDuration
        self.cycleLength = cycleLength
        self.createdAt = createdAt
    }
}
