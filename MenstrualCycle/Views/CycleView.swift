//
//  CycleView.swift
//  MenstrualCycle
//
//  Tab 1: Theo dõi Chu kỳ Kinh nguyệt — Đầy đủ tính năng.
//  Tương thích iOS 15+.
//

import SwiftUI

struct CycleView: View {
    @EnvironmentObject var viewModel: CycleViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ── Header + Profile Picker ─────────────────────
                headerSection

                // ── Vòng tròn trạng thái ────────────────────────
                cycleRingCard

                // ── Thông báo AI ────────────────────────────────
                aiMessageCard

                // ── Chỉ số dự đoán ─────────────────────────────
                predictionGrid

                // ── Cài đặt chu kỳ ─────────────────────────────
                cycleSettingsCard

                // ── Đối chiếu ngày thực tế ─────────────────────
                actualDateCard

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.softPink.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.body.bold())
                        .foregroundColor(.dustyRose)
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddProfile) {
            AddProfileSheet(viewModel: viewModel)
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Xác nhận xoá"),
                message: Text("Bạn có chắc chắn muốn xoá hồ sơ chu kỳ này cùng toàn bộ lịch sử chu kỳ của họ? Thao tác này không thể hoàn tác."),
                primaryButton: .destructive(Text("Xoá")) {
                    viewModel.deleteCurrentProfile()
                },
                secondaryButton: .cancel(Text("Huỷ"))
            )
        }
    }

    // MARK: - 1. Header + Profile Picker
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Xin chào 🌸")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    Text("Chu kỳ của bạn")
                        .font(.title.bold())
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                // Nút thêm hồ sơ
                Button(action: { viewModel.showAddProfile = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.dustyRose)
                }
            }

            // Profile selector — horizontal scroll
            if viewModel.profiles.count > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(viewModel.profiles.enumerated()), id: \.element.id) { index, profile in
                            profileChip(profile: profile, index: index)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func profileChip(profile: CycleProfile, index: Int) -> some View {
        let isSelected = index == viewModel.selectedProfileIndex
        return Button(action: { viewModel.selectProfile(at: index) }) {
            HStack(spacing: 6) {
                Text(profile.relationship.emoji)
                    .font(.body)
                Text(profile.name.isEmpty ? profile.relationship.rawValue : profile.name)
                    .font(.caption.bold())
                    .foregroundColor(isSelected ? .white : .textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AnyView(LinearGradient(
                        gradient: Gradient(colors: Color.gradientPink),
                        startPoint: .leading, endPoint: .trailing))
                    : AnyView(Color.creamWhite)
            )
            .cornerRadius(20)
            .shadow(color: Color.dustyRose.opacity(isSelected ? 0.3 : 0.08),
                    radius: isSelected ? 6 : 3, x: 0, y: 2)
        }
    }

    // MARK: - 2. Cycle Ring Card
    private var cycleRingCard: some View {
        VStack(spacing: 16) {
            if let pred = viewModel.prediction {
                // Vòng tròn trạng thái
                ZStack {
                    // Track nền
                    Circle()
                        .stroke(Color.softGray.opacity(0.4), lineWidth: 10)
                        .frame(width: 180, height: 180)

                    // Tiến trình chu kỳ
                    Circle()
                        .trim(from: 0, to: pred.cycleProgress)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: phaseGradient(pred.currentPhase)),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: pred.cycleProgress)

                    // Nội dung trung tâm
                    VStack(spacing: 4) {
                        Text(pred.currentPhase.emoji)
                            .font(.title)
                        Text("Ngày \(pred.currentDay)")
                            .font(.title2.bold())
                            .foregroundColor(.textPrimary)
                        Text("của chu kỳ")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }

                // Tên giai đoạn
                Text("Giai đoạn: \(pred.currentPhase.rawValue)")
                    .font(.headline)
                    .foregroundColor(.dustyRose)

                // Countdown
                HStack(spacing: 20) {
                    countdownLabel(
                        value: "\(pred.daysUntilNextPeriod)",
                        unit: "ngày",
                        label: "Đến kỳ kinh",
                        color: .coralRed
                    )
                    countdownLabel(
                        value: "\(pred.daysUntilOvulation)",
                        unit: "ngày",
                        label: "Đến rụng trứng",
                        color: .pastelPink
                    )
                }
            } else {
                // Chưa có dữ liệu
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.softGray)
                    Text("Chưa có dữ liệu chu kỳ")
                        .font(.headline)
                        .foregroundColor(.textSecondary)
                    Text("Hãy nhập ngày bắt đầu kỳ kinh\ngần nhất bên dưới")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            }
        }
        .pastelCard()
    }

    private func countdownLabel(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.textPrimary)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - 3. AI Message Card
    private var aiMessageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.peachYellow)
                Text("Lời nhắn yêu thương")
                    .font(.subheadline.bold())
                    .foregroundColor(.textPrimary)
                Spacer()
                Button(action: { viewModel.generateAIMessage() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.dustyRose)
                }
            }

            if viewModel.isLoadingAI {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .dustyRose))
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                Text(viewModel.aiMessage)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.peachYellow.opacity(0.15),
                    Color.pastelPink.opacity(0.10)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.dustyRose.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    // MARK: - 4. Prediction Grid
    private var predictionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chỉ số dự đoán")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Text("Dựa trên mô hình tính toán lâm sàng uy tín")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }

            if let pred = viewModel.prediction {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    predictionTile(
                        icon: "heart.fill",
                        title: "Khả năng thụ thai",
                        value: "\(pred.fertilityPercent)%",
                        color: pred.fertilityPercent > 50 ? .coralRed : .mintGreen,
                        progress: Double(pred.fertilityPercent) / 100.0,
                        source: "Nguồn: ACOG"
                    )
                    predictionTile(
                        icon: "sparkles",
                        title: "Xác suất rụng trứng",
                        value: "\(pred.ovulationPercent)%",
                        color: .pastelPink,
                        progress: Double(pred.ovulationPercent) / 100.0,
                        source: "Nguồn: WHO"
                    )
                    predictionTile(
                        icon: "shield.fill",
                        title: "An toàn",
                        value: "\(pred.safePercent)%",
                        color: .mintGreen,
                        progress: Double(pred.safePercent) / 100.0,
                        source: "Nguồn: WHO"
                    )
                    predictionTile(
                        icon: "calendar",
                        title: "Kỳ kinh tiếp theo",
                        value: viewModel.formatShortDate(pred.nextPeriodDate),
                        color: .lavender,
                        progress: nil,
                        source: "Chuẩn: WHO & ACOG"
                    )
                }
            }
        }
    }

    private func predictionTile(
        icon: String, title: String, value: String,
        color: Color, progress: Double?, source: String
    ) -> some View {
        VStack(spacing: 10) {
            if let progress = progress {
                // Mini circular progress
                ZStack {
                    Circle()
                        .stroke(Color.softGray.opacity(0.3), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color)
                }
            } else {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            Text(value)
                .font(.headline.bold())
                .foregroundColor(.textPrimary)

            Text(title)
                .font(.caption2)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(source)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.08))
                .cornerRadius(4)
        }
        .frame(maxWidth: .infinity)
        .pastelCard()
    }

    // MARK: - 5. Cycle Settings Card
    private var cycleSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.dustyRose)
                Text("Thiết lập chu kỳ")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }

            // Ngày bắt đầu
            VStack(alignment: .leading, spacing: 6) {
                Text("Ngày bắt đầu kỳ kinh gần nhất")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                DatePicker(
                    "Chọn ngày",
                    selection: Binding(
                        get: { viewModel.currentProfile?.lastPeriodStart ?? Date() },
                        set: { viewModel.updateLastPeriodStart($0) }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "vi_VN"))
            }

            Divider()

            // Số ngày kỳ kinh
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Số ngày kỳ kinh")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text("\(viewModel.currentProfile?.periodDuration ?? 5) ngày")
                        .font(.subheadline.bold())
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Stepper("",
                    value: Binding(
                        get: { viewModel.currentProfile?.periodDuration ?? 5 },
                        set: { viewModel.updatePeriodDuration($0) }
                    ),
                    in: 2...7
                )
                .labelsHidden()
            }

            Divider()

            // Độ dài chu kỳ
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Độ dài chu kỳ")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text("\(viewModel.currentProfile?.cycleLength ?? 28) ngày")
                        .font(.subheadline.bold())
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Stepper("",
                    value: Binding(
                        get: { viewModel.currentProfile?.cycleLength ?? 28 },
                        set: { viewModel.updateCycleLength($0) }
                    ),
                    in: 21...40
                )
                .labelsHidden()
            }
            
            if viewModel.profiles.count > 1 {
                Divider()
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                        Text("Xoá hồ sơ chu kỳ này")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.coralRed)
                    .padding(.vertical, 10)
                    .background(Color.softPink.opacity(0.3))
                    .cornerRadius(10)
                }
            }
        }
        .pastelCard()
    }

    // MARK: - 6. Actual Date Comparison
    private var actualDateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.lavender)
                Text("Đối chiếu ngày thực tế")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }

            Text("Nhập ngày kỳ kinh thực tế đến để so sánh với dự đoán")
                .font(.caption)
                .foregroundColor(.textSecondary)

            DatePicker(
                "Ngày thực tế",
                selection: $viewModel.actualPeriodDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "vi_VN"))

            Button(action: { viewModel.compareActualDate() }) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("So sánh")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: Color.gradientPink),
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            // Kết quả so sánh
            if viewModel.comparisonStatus != .notSet {
                HStack(spacing: 8) {
                    Image(systemName: comparisonIcon)
                        .foregroundColor(comparisonColor)
                    Text(comparisonMessage)
                        .font(.subheadline)
                        .foregroundColor(.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(comparisonColor.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .pastelCard()
    }

    // MARK: - Helpers

    private func phaseGradient(_ phase: CyclePhase) -> [Color] {
        switch phase {
        case .menstruation: return [.coralRed, .dustyRose]
        case .follicular:   return [.mintGreen, .lavender]
        case .ovulation:    return Color.gradientPink
        case .luteal:       return [.lavender, .dustyRose]
        case .preMenstrual: return [.peachYellow, .coralRed]
        case .unknown:      return [.softGray, .softGray]
        }
    }

    private var comparisonMessage: String {
        guard let profile = viewModel.currentProfile else { return "" }
        let name = profile.name.isEmpty ? profile.relationship.rawValue : profile.name
        switch viewModel.comparisonStatus {
        case .onTime:
            return "Kỳ kinh của \(name) diễn ra rất tốt 👍"
        case .early:
            return "Kỳ kinh của \(name) tới sớm hơn dự kiến ⚡"
        case .late:
            return "Kỳ kinh của \(name) đang bị chậm ⏰"
        case .notSet:
            return ""
        }
    }

    private var comparisonIcon: String {
        switch viewModel.comparisonStatus {
        case .onTime: return "checkmark.seal.fill"
        case .early:  return "bolt.fill"
        case .late:   return "clock.fill"
        case .notSet: return "questionmark.circle"
        }
    }

    private var comparisonColor: Color {
        switch viewModel.comparisonStatus {
        case .onTime: return .mintGreen
        case .early:  return .peachYellow
        case .late:   return .coralRed
        case .notSet: return .softGray
        }
    }
}

struct CycleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CycleView()
                .environmentObject(CycleViewModel())
        }
    }
}
