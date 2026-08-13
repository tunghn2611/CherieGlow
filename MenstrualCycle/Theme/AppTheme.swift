//
//  AppTheme.swift
//  MenstrualCycle
//
//  Bảng màu Pastel & Typography cho toàn bộ ứng dụng.
//  Tương thích iOS 15+.
//

import SwiftUI

// MARK: - Color Palette
extension Color {
    // ── Màu chủ đạo ──────────────────────────────────────
    /// Hồng pastel chính — dùng cho nút bấm, thanh tab, tiêu đề nổi bật
    static let pastelPink       = Color(red: 0.96, green: 0.72, blue: 0.76)
    /// Hồng đất — dùng cho gradient, nền card nổi bật
    static let dustyRose        = Color(red: 0.86, green: 0.58, blue: 0.63)
    /// Hồng nhạt — nền chung, nền section
    static let softPink         = Color(red: 0.99, green: 0.91, blue: 0.93)
    /// Hồng đậm hơn cho accent / pressed state
    static let deepRose         = Color(red: 0.78, green: 0.42, blue: 0.50)

    // ── Trung tính ────────────────────────────────────────
    /// Trắng kem — nền card
    static let creamWhite       = Color(red: 1.00, green: 0.98, blue: 0.97)
    /// Xám nhạt — đường viền, placeholder
    static let softGray         = Color(red: 0.88, green: 0.87, blue: 0.87)
    /// Xám đậm — text phụ
    static let textSecondary    = Color(red: 0.55, green: 0.53, blue: 0.55)
    /// Gần-đen — text chính
    static let textPrimary      = Color(red: 0.20, green: 0.18, blue: 0.22)

    // ── Phụ trợ ──────────────────────────────────────────
    /// Tím lavender nhẹ — badge, chip
    static let lavender         = Color(red: 0.85, green: 0.78, blue: 0.95)
    /// Xanh mint — trạng thái tốt, an toàn
    static let mintGreen        = Color(red: 0.74, green: 0.93, blue: 0.85)
    /// Vàng peach — cảnh báo nhẹ
    static let peachYellow      = Color(red: 1.00, green: 0.89, blue: 0.71)
    /// Đỏ coral nhẹ — cảnh báo mạnh
    static let coralRed         = Color(red: 0.96, green: 0.60, blue: 0.55)

    // ── Gradient sets ────────────────────────────────────
    static let gradientPink: [Color] = [
        Color(red: 0.96, green: 0.72, blue: 0.76),
        Color(red: 0.86, green: 0.58, blue: 0.63)
    ]
    static let gradientSoft: [Color] = [
        Color(red: 0.99, green: 0.91, blue: 0.93),
        Color(red: 0.96, green: 0.85, blue: 0.89)
    ]
}

// MARK: - Tab Item Enum
/// 4 Tab chức năng chính của ứng dụng
enum AppTab: Int, CaseIterable {
    case cycle      = 0
    case nutrition  = 1
    case fitness    = 2
    case account    = 3

    var title: String {
        switch self {
        case .cycle:     return "Chu kỳ"
        case .nutrition: return "Dinh dưỡng"
        case .fitness:   return "Thể dục"
        case .account:   return "Tài khoản"
        }
    }

    var iconName: String {
        switch self {
        case .cycle:     return "calendar.circle.fill"
        case .nutrition: return "leaf.fill"
        case .fitness:   return "figure.walk"
        case .account:   return "person.crop.circle.fill"
        }
    }
}

// MARK: - Reusable View Modifiers (iOS 15 safe)
struct PastelCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.creamWhite)
            .cornerRadius(16)
            .shadow(color: Color.dustyRose.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

extension View {
    /// Áp dụng style card pastel cho bất kỳ View nào
    func pastelCard() -> some View {
        modifier(PastelCardModifier())
    }
}
