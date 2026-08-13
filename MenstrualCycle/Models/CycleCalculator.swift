//
//  CycleCalculator.swift
//  MenstrualCycle
//
//  Thuật toán tính toán chu kỳ kinh nguyệt chuẩn.
//  Tương thích iOS 15+.
//

import Foundation

/// Các giai đoạn trong chu kỳ kinh nguyệt
enum CyclePhase: String {
    case menstruation   = "Kỳ kinh"
    case follicular     = "Nang trứng"
    case ovulation      = "Rụng trứng"
    case luteal         = "Hoàng thể"
    case preMenstrual   = "Tiền kinh"
    case unknown        = "Chưa xác định"

    var emoji: String {
        switch self {
        case .menstruation: return "🩸"
        case .follicular:   return "🌱"
        case .ovulation:    return "🥚"
        case .luteal:       return "🌙"
        case .preMenstrual: return "⚡"
        case .unknown:      return "❓"
        }
    }

    var color: String {
        switch self {
        case .menstruation: return "coralRed"
        case .follicular:   return "mintGreen"
        case .ovulation:    return "pastelPink"
        case .luteal:       return "lavender"
        case .preMenstrual: return "peachYellow"
        case .unknown:      return "softGray"
        }
    }
}

/// Trạng thái so sánh kỳ kinh thực tế vs dự đoán
enum PeriodComparisonStatus: String {
    case onTime     = "Kỳ kinh diễn ra rất tốt 👍"
    case early      = "Kỳ kinh tới sớm hơn dự kiến ⚡"
    case late       = "Kỳ kinh đang bị chậm ⏰"
    case notSet     = "Chưa có dữ liệu đối chiếu"
}

/// Kết quả dự đoán chu kỳ
struct CyclePrediction {
    let currentDay: Int               // Ngày thứ mấy của chu kỳ
    let currentPhase: CyclePhase
    let nextPeriodDate: Date          // Ngày dự kiến kỳ kinh tiếp theo
    let ovulationDate: Date           // Ngày rụng trứng dự kiến
    let daysUntilNextPeriod: Int
    let daysUntilOvulation: Int

    // Tỷ lệ phần trăm
    let fertilityPercent: Int         // % khả năng thụ thai
    let ovulationPercent: Int         // % xác suất đang rụng trứng
    let safePercent: Int              // % an toàn (không thụ thai)

    let cycleProgress: Double         // 0.0 – 1.0 cho vòng tròn
}

/// Engine tính toán chu kỳ
struct CycleCalculator {

    // MARK: - Tính toán chính
    /// Tính toán toàn bộ dự đoán dựa trên dữ liệu đầu vào
    static func predict(
        lastPeriodStart: Date,
        periodDuration: Int,
        cycleLength: Int,
        today: Date = Date()
    ) -> CyclePrediction {
        let calendar = Calendar.current

        // ── Ngày thứ mấy trong chu kỳ hiện tại ───────────
        let daysSinceStart = calendar.dateComponents([.day], from: startOfDay(lastPeriodStart), to: startOfDay(today)).day ?? 0
        // Xử lý trường hợp chu kỳ đã qua nhiều vòng
        let currentDay: Int
        if daysSinceStart >= 0 {
            currentDay = (daysSinceStart % cycleLength) + 1
        } else {
            currentDay = 1
        }

        // ── Ngày rụng trứng (thường = cycleLength - 14) ──
        let ovulationDay = max(cycleLength - 14, periodDuration + 1)

        // ── Ngày kỳ kinh tiếp theo ──────────────────────
        let daysUntilNext = cycleLength - currentDay + 1
        let nextPeriodDate = calendar.date(byAdding: .day, value: daysUntilNext, to: startOfDay(today)) ?? today

        // ── Ngày rụng trứng tới ─────────────────────────
        let daysUntilOvulation: Int
        let ovulationDate: Date
        if currentDay <= ovulationDay {
            daysUntilOvulation = ovulationDay - currentDay
            ovulationDate = calendar.date(byAdding: .day, value: daysUntilOvulation, to: startOfDay(today)) ?? today
        } else {
            // Rụng trứng đã qua, tính cho chu kỳ tiếp theo
            let nextOvDay = cycleLength - currentDay + ovulationDay
            daysUntilOvulation = nextOvDay
            ovulationDate = calendar.date(byAdding: .day, value: nextOvDay, to: startOfDay(today)) ?? today
        }

        // ── Xác định giai đoạn hiện tại ─────────────────
        let phase = determinePhase(
            currentDay: currentDay,
            periodDuration: periodDuration,
            ovulationDay: ovulationDay,
            cycleLength: cycleLength
        )

        // ── Tính phần trăm ──────────────────────────────
        let (fertility, ovulationPct, safe) = calculatePercentages(
            currentDay: currentDay,
            periodDuration: periodDuration,
            ovulationDay: ovulationDay,
            cycleLength: cycleLength
        )

        // ── Tiến trình chu kỳ ──────────────────────────
        let progress = Double(currentDay) / Double(cycleLength)

        return CyclePrediction(
            currentDay: currentDay,
            currentPhase: phase,
            nextPeriodDate: nextPeriodDate,
            ovulationDate: ovulationDate,
            daysUntilNextPeriod: max(daysUntilNext, 0),
            daysUntilOvulation: max(daysUntilOvulation, 0),
            fertilityPercent: fertility,
            ovulationPercent: ovulationPct,
            safePercent: safe,
            cycleProgress: min(progress, 1.0)
        )
    }

    // MARK: - So sánh ngày thực tế
    /// So sánh ngày thực tế kỳ kinh đến với dự đoán
    static func comparePeriod(
        actualDate: Date,
        predictedDate: Date
    ) -> PeriodComparisonStatus {
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: startOfDay(predictedDate), to: startOfDay(actualDate)).day ?? 0

        if abs(diff) <= 2 {
            return .onTime
        } else if diff < -2 {
            return .early
        } else {
            return .late
        }
    }

    // MARK: - Private Helpers

    private static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Xác định giai đoạn dựa trên ngày hiện tại trong chu kỳ
    private static func determinePhase(
        currentDay: Int,
        periodDuration: Int,
        ovulationDay: Int,
        cycleLength: Int
    ) -> CyclePhase {
        // Ngày 1 – periodDuration: Kỳ kinh
        if currentDay <= periodDuration {
            return .menstruation
        }
        // periodDuration+1 – ovulationDay-3: Nang trứng
        if currentDay <= ovulationDay - 3 {
            return .follicular
        }
        // ovulationDay-2 – ovulationDay+1: Rụng trứng (cửa sổ 4 ngày)
        if currentDay <= ovulationDay + 1 {
            return .ovulation
        }
        // ovulationDay+2 – cycleLength-3: Hoàng thể
        if currentDay <= cycleLength - 3 {
            return .luteal
        }
        // cycleLength-2 – cycleLength: Tiền kinh
        return .preMenstrual
    }

    /// Tính tỷ lệ phần trăm thụ thai, rụng trứng, an toàn
    private static func calculatePercentages(
        currentDay: Int,
        periodDuration: Int,
        ovulationDay: Int,
        cycleLength: Int
    ) -> (fertility: Int, ovulation: Int, safe: Int) {
        // Cửa sổ thụ thai cao: ovulationDay-5 đến ovulationDay+1
        let fertileWindowStart = ovulationDay - 5
        let fertileWindowEnd = ovulationDay + 1

        let fertility: Int
        let ovulationPct: Int

        if currentDay >= fertileWindowStart && currentDay <= fertileWindowEnd {
            // Trong cửa sổ thụ thai
            let distanceToOvulation = abs(currentDay - ovulationDay)
            switch distanceToOvulation {
            case 0:
                fertility = 95      // Ngày rụng trứng
                ovulationPct = 98
            case 1:
                fertility = 85
                ovulationPct = 70
            case 2:
                fertility = 65
                ovulationPct = 40
            case 3:
                fertility = 45
                ovulationPct = 20
            default:
                fertility = 25
                ovulationPct = 10
            }
        } else if currentDay <= periodDuration {
            // Đang trong kỳ kinh
            fertility = 5
            ovulationPct = 0
        } else {
            // Ngoài cửa sổ (an toàn)
            fertility = 8
            ovulationPct = 2
        }

        let safe = max(100 - fertility, 0)

        return (fertility, ovulationPct, safe)
    }
}
