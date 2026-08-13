//
//  AddMealSheet.swift
//  MenstrualCycle
//
//  Sheet nhập bữa ăn thủ công khi AI không tìm thấy.
//  Tương thích iOS 15+.
//

import SwiftUI

struct AddMealSheet: View {
    @ObservedObject var viewModel: NutritionViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var mealName: String = ""
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // ── Illustration ──────────────────────
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.dustyRose)
                        Text("Nhập thông tin món ăn")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Text("AI chưa nhận diện được món này.\nBạn hãy nhập thủ công nhé!")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // ── Form Fields ──────────────────────
                    VStack(spacing: 16) {
                        mealTextField(
                            title: "Tên món ăn",
                            icon: "pencil",
                            text: $mealName,
                            keyboard: .default
                        )

                        mealTextField(
                            title: "Calo (kcal)",
                            icon: "flame.fill",
                            text: $caloriesText,
                            keyboard: .decimalPad
                        )

                        mealTextField(
                            title: "Protein (g)",
                            icon: "p.circle.fill",
                            text: $proteinText,
                            keyboard: .decimalPad
                        )

                        mealTextField(
                            title: "Carbs (g)",
                            icon: "c.circle.fill",
                            text: $carbsText,
                            keyboard: .decimalPad
                        )

                        mealTextField(
                            title: "Fat (g)",
                            icon: "f.circle.fill",
                            text: $fatText,
                            keyboard: .decimalPad
                        )
                    }
                    .pastelCard()

                    // ── Save Button ──────────────────────
                    Button(action: saveMeal) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Lưu món ăn")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: Color.gradientPink),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .disabled(mealName.isEmpty)
                    .opacity(mealName.isEmpty ? 0.5 : 1.0)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(Color.softPink.ignoresSafeArea())
            .navigationTitle("Thêm món ăn")
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
        }
    }

    // MARK: - Helpers

    private func mealTextField(
        title: String,
        icon: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.dustyRose)
                .frame(width: 24)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .foregroundColor(.textPrimary)
        }
        .padding(.vertical, 4)
        .overlay(
            Rectangle()
                .fill(Color.softGray.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func saveMeal() {
        let cal     = Double(caloriesText) ?? 0
        let protein = Double(proteinText)  ?? 0
        let carbs   = Double(carbsText)    ?? 0
        let fat     = Double(fatText)      ?? 0

        let entry = MealEntry(
            name: mealName,
            calories: cal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            date: viewModel.selectedDate
        )
        viewModel.addMeal(entry)
        viewModel.foodInputText = ""
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddMealSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddMealSheet(viewModel: NutritionViewModel())
    }
}
