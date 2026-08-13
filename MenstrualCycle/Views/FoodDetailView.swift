//
//  FoodDetailView.swift
//  MenstrualCycle
//
//  Hiển thị chi tiết hàm lượng dinh dưỡng của một món ăn.
//  Hiển thị nguồn dữ liệu (Viện Dinh Dưỡng / AI Estimated).
//  Có nút "Thêm vào bữa ăn" và "Thoát".
//  Tương thích iOS 15+.
//

import SwiftUI

struct FoodDetailView: View {
    let food: FoodItem
    let onAddToMeal: ((FoodItem) -> Void)?
    let onDismiss: (() -> Void)?

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Header ──
                    foodHeader

                    // ── Source Badge ──
                    sourceBadge

                    // ── Calorie Highlight ──
                    calorieHighlight

                    // ── Macros ──
                    macrosCard

                    // ── Vitamins ──
                    vitaminsCard

                    // ── Minerals ──
                    mineralsCard

                    // ── Other ──
                    otherNutrientsCard

                    // ── Action Buttons ──
                    actionButtons

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(Color.softPink.ignoresSafeArea())
            .navigationTitle("Hàm lượng dinh dưỡng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: dismissView) {
                        Image(systemName: "arrow.left")
                            .font(.body.bold())
                            .foregroundColor(.dustyRose)
                    }
                }
            }
        }
    }

    // MARK: - Food Header

    private var foodHeader: some View {
        VStack(spacing: 12) {
            Text(food.icon)
                .font(.system(size: 64))

            Text(food.name)
                .font(.title2.bold())
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Label(food.category, systemImage: "tag.fill")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Text("·")
                    .foregroundColor(.softGray)

                Text(food.unit)
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Text("·")
                    .foregroundColor(.softGray)

                Text("\(food.servingGrams)g")
                    .font(.caption.bold())
                    .foregroundColor(.dustyRose)
            }
        }
        .frame(maxWidth: .infinity)
        .pastelCard()
    }

    // MARK: - Source Badge

    private var sourceBadge: some View {
        HStack(spacing: 8) {
            if food.source == .verified {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.mintGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dữ liệu xác thực")
                        .font(.caption.bold())
                        .foregroundColor(.textPrimary)
                    Text("Nguồn: Viện Dinh Dưỡng Quốc Gia Việt Nam")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            } else {
                Image(systemName: "sparkles")
                    .foregroundColor(.peachYellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ước tính bởi AI")
                        .font(.caption.bold())
                        .foregroundColor(.textPrimary)
                    Text("Dữ liệu ước tính bằng Gemini AI, có thể chưa chính xác 100%")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            food.source == .verified
                ? Color.mintGreen.opacity(0.1)
                : Color.peachYellow.opacity(0.1)
        )
        .cornerRadius(12)
    }

    // MARK: - Calorie Highlight

    private var calorieHighlight: some View {
        VStack(spacing: 8) {
            Text("Năng lượng")
                .font(.caption)
                .foregroundColor(.textSecondary)
            Text("\(Int(food.calories))")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundColor(.coralRed)
            Text("kcal / \(food.unit)")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .pastelCard()
    }

    // MARK: - Macros Card

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.dustyRose)
                Text("Chất đa lượng")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }

            // Visual macro bars
            macroBar(label: "Protein", value: food.protein, unit: "g", color: .dustyRose, maxValue: 80)
            macroBar(label: "Carbohydrate", value: food.carbs, unit: "g", color: .peachYellow, maxValue: 150)
            macroBar(label: "Chất béo (Fat)", value: food.fat, unit: "g", color: .lavender, maxValue: 60)
            macroBar(label: "Chất xơ (Fiber)", value: food.fiber, unit: "g", color: .mintGreen, maxValue: 25)
            macroBar(label: "Đường (Sugar)", value: food.sugar, unit: "g", color: .coralRed, maxValue: 50)
        }
        .pastelCard()
    }

    private func macroBar(label: String, value: Double, unit: String, color: Color, maxValue: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(String(format: "%.1f %@", value, unit))
                    .font(.caption.bold())
                    .foregroundColor(.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.softGray.opacity(0.3))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(min(value / maxValue, 1.0)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Vitamins Card

    private var vitaminsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.mintGreen)
                Text("Vitamin")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }

            HStack(spacing: 12) {
                nutrientTile(name: "Vitamin A", value: food.vitaminA, unit: "mcg", icon: "eye.fill", color: .peachYellow)
                nutrientTile(name: "Vitamin C", value: food.vitaminC, unit: "mg", icon: "drop.fill", color: .mintGreen)
            }
            HStack(spacing: 12) {
                nutrientTile(name: "Vitamin B1", value: food.vitaminB1, unit: "mg", icon: "bolt.fill", color: .lavender)
                nutrientTile(name: "Vitamin B2", value: food.vitaminB2, unit: "mg", icon: "sparkle", color: .dustyRose)
            }
        }
        .pastelCard()
    }

    private func nutrientTile(name: String, value: Double, unit: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.15))
                .cornerRadius(6)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                Text(formatNutrientValue(value, unit: unit))
                    .font(.caption.bold())
                    .foregroundColor(.textPrimary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.softPink.opacity(0.4))
        .cornerRadius(10)
    }

    // MARK: - Minerals Card

    private var mineralsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "atom")
                    .foregroundColor(.lavender)
                Text("Khoáng chất")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }

            HStack(spacing: 12) {
                nutrientTile(name: "Canxi", value: food.calcium, unit: "mg", icon: "figure.strengthtraining.traditional", color: .dustyRose)
                nutrientTile(name: "Sắt", value: food.iron, unit: "mg", icon: "drop.triangle.fill", color: .coralRed)
            }
        }
        .pastelCard()
    }

    // MARK: - Other Nutrients

    private var otherNutrientsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.peachYellow)
                Text("Thông tin khác")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }

            HStack(spacing: 12) {
                nutrientTile(name: "Natri", value: food.sodium, unit: "mg", icon: "cube.fill", color: .peachYellow)
                nutrientTile(name: "Cholesterol", value: food.cholesterol, unit: "mg", icon: "heart.fill", color: .coralRed)
            }
        }
        .pastelCard()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Thêm vào bữa ăn
            Button(action: {
                onAddToMeal?(food)
                dismissView()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Thêm vào bữa ăn hôm nay")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: Color.gradientPink),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.dustyRose.opacity(0.3), radius: 6, x: 0, y: 3)
            }

            // Thoát
            Button(action: dismissView) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle")
                    Text("Thoát")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.textSecondary)
                .background(Color.softGray.opacity(0.3))
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Helpers

    private func dismissView() {
        onDismiss?()
        presentationMode.wrappedValue.dismiss()
    }

    private func formatNutrientValue(_ value: Double, unit: String) -> String {
        if value >= 1 {
            return String(format: "%.1f %@", value, unit)
        } else if value > 0 {
            return String(format: "%.2f %@", value, unit)
        } else {
            return "0 \(unit)"
        }
    }
}
