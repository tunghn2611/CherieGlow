//
//  AddProfileSheet.swift
//  MenstrualCycle
//
//  Sheet thêm/chỉnh sửa hồ sơ đối tượng theo dõi.
//  Tương thích iOS 15+.
//

import SwiftUI

struct AddProfileSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: CycleViewModel

    @State private var name: String = ""
    @State private var relationship: ProfileRelationship = .lover
    @State private var lastPeriodStart: Date = Date()
    @State private var periodDuration: Int = 5
    @State private var cycleLength: Int = 28

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // ── Tên đối tượng ────────────────────────
                    inputSection(title: "Tên gọi", icon: "person.fill") {
                        TextField("Ví dụ: Linh, Mẹ, Em yêu...", text: $name)
                            .font(.body)
                            .padding(12)
                            .background(Color.softPink)
                            .cornerRadius(12)
                    }

                    // ── Mối quan hệ ─────────────────────────
                    inputSection(title: "Mối quan hệ", icon: "heart.fill") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(ProfileRelationship.allCases) { rel in
                                    Button(action: { relationship = rel }) {
                                        VStack(spacing: 6) {
                                            Text(rel.emoji)
                                                .font(.title2)
                                            Text(rel.rawValue)
                                                .font(.caption2)
                                                .foregroundColor(
                                                    relationship == rel ? .white : .textPrimary
                                                )
                                        }
                                        .frame(width: 72, height: 72)
                                        .background(
                                            relationship == rel
                                                ? Color.dustyRose
                                                : Color.softPink
                                        )
                                        .cornerRadius(14)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // ── Ngày bắt đầu kỳ kinh gần nhất ──────
                    inputSection(title: "Ngày bắt đầu kỳ kinh gần nhất", icon: "calendar") {
                        DatePicker(
                            "Chọn ngày",
                            selection: $lastPeriodStart,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "vi_VN"))
                        .padding(12)
                        .background(Color.softPink)
                        .cornerRadius(12)
                    }

                    // ── Số ngày kỳ kinh ─────────────────────
                    inputSection(title: "Số ngày kỳ kinh (2 – 7 ngày)", icon: "drop.fill") {
                        HStack(spacing: 16) {
                            Button(action: {
                                if periodDuration > 2 { periodDuration -= 1 }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.dustyRose)
                            }

                            Text("\(periodDuration) ngày")
                                .font(.title3.bold())
                                .foregroundColor(.textPrimary)
                                .frame(width: 80)

                            Button(action: {
                                if periodDuration < 7 { periodDuration += 1 }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.dustyRose)
                            }
                        }
                        .padding(12)
                        .background(Color.softPink)
                        .cornerRadius(12)
                    }

                    // ── Độ dài chu kỳ ───────────────────────
                    inputSection(title: "Độ dài chu kỳ (21 – 40 ngày)", icon: "repeat") {
                        HStack(spacing: 16) {
                            Button(action: {
                                if cycleLength > 21 { cycleLength -= 1 }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.dustyRose)
                            }

                            Text("\(cycleLength) ngày")
                                .font(.title3.bold())
                                .foregroundColor(.textPrimary)
                                .frame(width: 80)

                            Button(action: {
                                if cycleLength < 40 { cycleLength += 1 }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.dustyRose)
                            }
                        }
                        .padding(12)
                        .background(Color.softPink)
                        .cornerRadius(12)
                    }

                    // ── Nút Lưu ─────────────────────────────
                    Button(action: saveProfile) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Thêm hồ sơ")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: Color.gradientPink),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.creamWhite.ignoresSafeArea())
            .navigationTitle("Thêm đối tượng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Huỷ") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.dustyRose)
                }
            }
        }
    }

    // MARK: - Helpers

    private func inputSection<Content: View>(
        title: String, icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.dustyRose)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.textPrimary)
            }
            content()
        }
        .pastelCard()
    }

    private func saveProfile() {
        let profile = CycleProfile(
            name: name,
            relationship: relationship,
            lastPeriodStart: lastPeriodStart,
            periodDuration: periodDuration,
            cycleLength: cycleLength
        )
        viewModel.addProfile(profile)
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddProfileSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddProfileSheet(viewModel: CycleViewModel())
    }
}
