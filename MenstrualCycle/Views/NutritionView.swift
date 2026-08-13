//
//  NutritionView.swift
//  MenstrualCycle
//
//  Tab 2: Quản lý Dinh dưỡng & BMI – Phiên bản đầy đủ.
//  Tương thích iOS 15+. KHÔNG dùng NavigationStack, Charts, SwiftData.
//

import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var viewModel: NutritionViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1 ── Header
                headerSection

                // ★ Main Button: Hàm lượng dinh dưỡng
                nutritionLookupButton

                // 2 ── BMI Card
                bmiCard

                // 3 ── Macro Overview
                macroOverview

                // 4 ── AI Food Input
                aiFoodInputSection

                // 5 ── Today's Meals
                mealsSection

                // 6 ── Daily Summary
                dailySummaryCard

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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Xong") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.body.bold())
                .foregroundColor(.dustyRose)
            }
        }
        .sheet(isPresented: $viewModel.showManualEntry) {
            AddMealSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showFoodLookup) {
            FoodLookupView(viewModel: viewModel)
        }
        .onChange(of: viewModel.selectedDate) { _ in
            viewModel.onDateChanged()
        }
        .onChange(of: viewModel.heightCm) { _ in
            viewModel.saveProfile()
        }
        .onChange(of: viewModel.weightKg) { _ in
            viewModel.saveProfile()
        }
    }

    // MARK: - 1. Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dinh dưỡng hôm nay 🥗")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                Text("Chế độ ăn")
                    .font(.title.bold())
                    .foregroundColor(.textPrimary)
            }
            Spacer()
            // Calorie badge
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.coralRed)
                Text("\(Int(viewModel.todayCalories)) kcal")
                    .font(.subheadline.bold())
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.creamWhite)
            .cornerRadius(20)
            .shadow(color: Color.dustyRose.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - ★ Nutrition Lookup Button (Main CTA)

    private var nutritionLookupButton: some View {
        Button(action: {
            viewModel.showFoodLookup = true
        }) {
            HStack(spacing: 12) {
                // Icon với gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.mintGreen, .dustyRose]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "leaf.arrow.triangle.circlepath")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Hàm lượng dinh dưỡng")
                        .font(.subheadline.bold())
                        .foregroundColor(.textPrimary)
                    Text("Tra cứu chi tiết calories, protein, vitamin...")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(.dustyRose)
            }
            .padding(14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.creamWhite,
                        Color.mintGreen.opacity(0.08)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.dustyRose.opacity(0.15), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.mintGreen.opacity(0.3), .dustyRose.opacity(0.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 2. BMI Card

    private var bmiCard: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("Chỉ số BMI")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
            }

            // Input fields
            HStack(spacing: 12) {
                bmiInputField(title: "Chiều cao (cm)", text: $viewModel.heightCm, icon: "ruler")
                bmiInputField(title: "Cân nặng (kg)", text: $viewModel.weightKg, icon: "scalemass")
            }

            // BMI value + category
            if viewModel.bmi > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chỉ số BMI")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        Text(String(format: "%.1f", viewModel.bmi))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(viewModel.bmiCategory.rawValue)
                            .font(.subheadline.bold())
                            .foregroundColor(viewModel.bmiColor)
                        if let h = Double(viewModel.heightCm),
                           let w = Double(viewModel.weightKg) {
                            Text("\(Int(h)) cm · \(Int(w)) kg")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }

                // BMI progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Full gradient bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.mintGreen, .peachYellow, .coralRed]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 8)

                        // Indicator dot
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .dustyRose.opacity(0.3), radius: 2, x: 0, y: 1)
                            .offset(x: max(0, min(geo.size.width * CGFloat(viewModel.bmiProgress) - 8, geo.size.width - 16)))
                    }
                }
                .frame(height: 16)

                // BMI advice
                Text(viewModel.bmiAdvice)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            } else {
                // Placeholder when no input
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.dustyRose)
                    Text("Nhập chiều cao và cân nặng để tính BMI")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding(.vertical, 8)
            }
        }
        .pastelCard()
    }

    private func bmiInputField(title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.dustyRose)
                .frame(width: 20)
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .font(.subheadline)
                .foregroundColor(.textPrimary)
        }
        .padding(10)
        .background(Color.softPink.opacity(0.5))
        .cornerRadius(10)
    }

    // MARK: - 3. Macro Overview

    private var macroOverview: some View {
        HStack(spacing: 12) {
            macroTile(
                name: "Protein",
                current: viewModel.todayProtein,
                goal: viewModel.proteinGoal,
                unit: "g",
                color: .dustyRose
            )
            macroTile(
                name: "Carbs",
                current: viewModel.todayCarbs,
                goal: viewModel.carbsGoal,
                unit: "g",
                color: .peachYellow
            )
            macroTile(
                name: "Fat",
                current: viewModel.todayFat,
                goal: viewModel.fatGoal,
                unit: "g",
                color: .lavender
            )
        }
    }

    private func macroTile(
        name: String,
        current: Double,
        goal: Double,
        unit: String,
        color: Color
    ) -> some View {
        let percent = goal > 0 ? min(current / goal, 1.0) : 0

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.softGray, lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: percent)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(current))\(unit)")
                    .font(.caption2.bold())
                    .foregroundColor(.textPrimary)
            }
            Text(name)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .pastelCard()
    }

    // MARK: - 4. AI Food Input

    private var aiFoodInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nhập thức ăn")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.dustyRose)
            }

            // Text editor with placeholder
            ZStack(alignment: .topLeading) {
                if viewModel.foodInputText.isEmpty {
                    Text("Ví dụ: Trưa nay mình ăn phở bò, uống trà sữa...")
                        .font(.subheadline)
                        .foregroundColor(.softGray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $viewModel.foodInputText)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
                    .frame(minHeight: 80, maxHeight: 100)
                    .padding(4)
            }
            .background(Color.softPink.opacity(0.5))
            .cornerRadius(12)

            // Analyze button
            Button(action: {
                viewModel.analyzeFood()
            }) {
                HStack {
                    if viewModel.isAnalyzingFood {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Đang phân tích...")
                            .fontWeight(.semibold)
                    } else {
                        Image(systemName: "sparkles")
                        Text("Phân tích bằng AI 🤖")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: Color.gradientPink),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(viewModel.foodInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAnalyzingFood)
            .opacity((viewModel.foodInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAnalyzingFood) ? 0.6 : 1.0)
        }
        .pastelCard()
    }

    // MARK: - 5. Meals Section

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bữa ăn")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Button(action: {
                    viewModel.showManualEntry = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.pastelPink)
                        .font(.title3)
                }
            }

            // Date picker
            DatePicker(
                "Chọn ngày",
                selection: $viewModel.selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(CompactDatePickerStyle())
            .accentColor(.dustyRose)
            .foregroundColor(.textSecondary)
            .environment(\.locale, Locale(identifier: "vi_VN"))

            // Meals list
            if viewModel.todayMeals.isEmpty {
                emptyMealsPlaceholder
            } else {
                ForEach(viewModel.todayMeals) { meal in
                    mealRow(meal)
                }
            }
        }
        .pastelCard()
    }

    private var emptyMealsPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.softGray)
            Text("Chưa có bữa ăn nào")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
            Text("Nhập thức ăn ở trên hoặc nhấn + để thêm")
                .font(.caption)
                .foregroundColor(.softGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func mealRow(_ meal: MealEntry) -> some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(Color.pastelPink.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundColor(.dustyRose)
                        .font(.body)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.textPrimary)
                HStack(spacing: 8) {
                    macroLabel("P", value: meal.protein, color: .dustyRose)
                    macroLabel("C", value: meal.carbs, color: .peachYellow)
                    macroLabel("F", value: meal.fat, color: .lavender)
                }
            }

            Spacer()

            // Calories
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(meal.calories))")
                    .font(.subheadline.bold())
                    .foregroundColor(.textPrimary)
                Text("kcal")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }

            // Delete button
            Button(action: {
                withAnimation {
                    if let idx = viewModel.todayMeals.firstIndex(where: { $0.id == meal.id }) {
                        viewModel.deleteMeal(at: IndexSet(integer: idx))
                    }
                }
            }) {
                Image(systemName: "trash.circle.fill")
                    .foregroundColor(.coralRed.opacity(0.6))
                    .font(.title3)
            }
        }
        .padding(12)
        .background(Color.softPink.opacity(0.3))
        .cornerRadius(12)
    }

    private func macroLabel(_ letter: String, value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(letter)
                .font(.caption2.bold())
                .foregroundColor(color)
            Text("\(Int(value))g")
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - 6. Daily Summary

    private var dailySummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tổng kết ngày")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(viewModel.formatDate(viewModel.selectedDate))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            // Calorie progress
            VStack(spacing: 8) {
                HStack {
                    Text("Năng lượng")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("\(Int(viewModel.todayCalories)) / \(Int(viewModel.calorieGoal)) kcal")
                        .font(.subheadline.bold())
                        .foregroundColor(.textPrimary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.softGray.opacity(0.5))
                            .frame(height: 12)

                        let progress = viewModel.calorieGoal > 0
                            ? min(viewModel.todayCalories / viewModel.calorieGoal, 1.0)
                            : 0
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: Color.gradientPink),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(progress), height: 12)
                    }
                }
                .frame(height: 12)
            }

            // Status label
            HStack(spacing: 6) {
                Image(systemName: calorieStatusIcon)
                    .foregroundColor(calorieStatusColor)
                Text(calorieStatusText)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, 4)
        }
        .pastelCard()
    }

    // MARK: - Summary Helpers

    private var calorieStatusIcon: String {
        let ratio = viewModel.calorieGoal > 0
            ? viewModel.todayCalories / viewModel.calorieGoal
            : 0
        if ratio < 0.5 { return "arrow.up.circle.fill" }
        if ratio <= 1.0 { return "checkmark.circle.fill" }
        return "exclamationmark.circle.fill"
    }

    private var calorieStatusColor: Color {
        let ratio = viewModel.calorieGoal > 0
            ? viewModel.todayCalories / viewModel.calorieGoal
            : 0
        if ratio < 0.5 { return .peachYellow }
        if ratio <= 1.0 { return .mintGreen }
        return .coralRed
    }

    private var calorieStatusText: String {
        let ratio = viewModel.calorieGoal > 0
            ? viewModel.todayCalories / viewModel.calorieGoal
            : 0
        if ratio < 0.5 {
            return "Bạn chưa ăn đủ, hãy bổ sung thêm nhé!"
        }
        if ratio <= 1.0 {
            return "Tuyệt vời! Bạn đang ăn đúng mục tiêu 🎯"
        }
        return "Bạn đã vượt mục tiêu, hãy kiểm soát nhé!"
    }
}

// MARK: - Preview

struct NutritionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NutritionView()
        }
    }
}
