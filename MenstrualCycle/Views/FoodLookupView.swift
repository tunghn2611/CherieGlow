//
//  FoodLookupView.swift
//  MenstrualCycle
//
//  Màn hình tra cứu "Hàm lượng dinh dưỡng" chính.
//  Flow: Nhập tên món → Search local DB → Hiện kết quả / AI fallback.
//  Tương thích iOS 15+.
//

import SwiftUI

struct FoodLookupView: View {
    @ObservedObject var viewModel: NutritionViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var searchText: String = ""
    @State private var searchResults: [FoodItem] = []
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false

    // AI states
    @State private var showAISuggestion: Bool = false
    @State private var isAILoading: Bool = false
    @State private var aiResult: FoodItem? = nil
    @State private var aiError: Bool = false

    // Detail sheet
    @State private var selectedFood: FoodItem? = nil
    @State private var showFoodDetail: Bool = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Search Bar ──
                    searchBar

                    // ── Results or States ──
                    if isAILoading {
                        aiLoadingView
                    } else if let aiFood = aiResult {
                        aiResultView(aiFood)
                    } else if showAISuggestion {
                        aiSuggestionCard
                    } else if hasSearched && searchResults.isEmpty {
                        noResultView
                    } else if !searchResults.isEmpty {
                        searchResultsList
                    } else {
                        promptView
                    }

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
            .sheet(isPresented: $showFoodDetail) {
                if let food = selectedFood {
                    FoodDetailView(
                        food: food,
                        onAddToMeal: { foodItem in
                            let meal = MealEntry(
                                name: foodItem.name,
                                calories: foodItem.calories,
                                protein: foodItem.protein,
                                carbs: foodItem.carbs,
                                fat: foodItem.fat,
                                date: viewModel.selectedDate
                            )
                            viewModel.addMeal(meal)
                        },
                        onDismiss: nil
                    )
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.dustyRose)
                    .font(.body)

                TextField("Nhập tên món ăn...", text: $searchText)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        hasSearched = false
                        showAISuggestion = false
                        aiResult = nil
                        aiError = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.softGray)
                    }
                }
            }
            .padding(14)
            .background(Color.creamWhite)
            .cornerRadius(14)
            .shadow(color: Color.dustyRose.opacity(0.1), radius: 4, x: 0, y: 2)

            // Search button
            Button(action: performSearch) {
                HStack(spacing: 6) {
                    Image(systemName: "text.magnifyingglass")
                    Text("Tra cứu dinh dưỡng")
                        .fontWeight(.semibold)
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
            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
        }
        .pastelCard()
    }

    // MARK: - Prompt View (Initial state)

    private var promptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.mintGreen)

            Text("Tra cứu hàm lượng dinh dưỡng")
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text("Nhập tên món ăn Việt Nam để xem chi tiết\ncalories, protein, carbs, fat, vitamin và khoáng chất")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            // Source info
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.mintGreen)
                    .font(.caption)
                Text("Dữ liệu từ Viện Dinh Dưỡng Quốc Gia")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
            .padding(8)
            .background(Color.mintGreen.opacity(0.08))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .pastelCard()
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kết quả (\(searchResults.count) món)")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundColor(.mintGreen)
                    Text("Viện Dinh Dưỡng")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }

            ForEach(searchResults.prefix(10)) { food in
                Button(action: {
                    selectedFood = food
                    showFoodDetail = true
                }) {
                    HStack(spacing: 12) {
                        Text(food.icon)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(food.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.textPrimary)

                            HStack(spacing: 6) {
                                Text("\(Int(food.calories)) kcal")
                                    .font(.caption.bold())
                                    .foregroundColor(.coralRed)
                                Text("·")
                                    .foregroundColor(.softGray)
                                Text("P:\(Int(food.protein))g")
                                    .font(.caption2)
                                    .foregroundColor(.dustyRose)
                                Text("C:\(Int(food.carbs))g")
                                    .font(.caption2)
                                    .foregroundColor(.peachYellow)
                                Text("F:\(Int(food.fat))g")
                                    .font(.caption2)
                                    .foregroundColor(.lavender)
                            }

                            Text(food.unit)
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.softGray)
                    }
                    .padding(12)
                    .background(Color.softPink.opacity(0.3))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .pastelCard()
    }

    // MARK: - No Result View

    private var noResultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 40))
                .foregroundColor(.peachYellow)

            Text("Không tìm thấy trong cơ sở dữ liệu")
                .font(.subheadline.bold())
                .foregroundColor(.textPrimary)

            Text("Món \"\(searchText)\" chưa có trong Bảng Thành phần Dinh dưỡng.\nBạn có muốn tra cứu bằng AI không?")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            // AI Lookup button
            Button(action: performAILookup) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Tra cứu bằng AI ✨")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.lavender, .dustyRose]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            // Cancel
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Thoát")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .pastelCard()
    }

    // MARK: - AI Loading

    private var aiLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .dustyRose))
                .scaleEffect(1.3)

            Text("Đang hỏi AI Gemini...")
                .font(.subheadline.bold())
                .foregroundColor(.textPrimary)

            Text("AI đang ước tính hàm lượng dinh dưỡng\ncho \"\(searchText)\"")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .pastelCard()
    }

    // MARK: - AI Suggestion Card

    private var aiSuggestionCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.peachYellow)

            Text("AI không thể ước tính")
                .font(.subheadline.bold())
                .foregroundColor(.textPrimary)

            Text("Xin lỗi, AI không thể phân tích món \"\(searchText)\".\nVui lòng thử lại hoặc nhập tên khác.")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                searchText = ""
                showAISuggestion = false
                aiError = false
                hasSearched = false
            }) {
                Text("Thử lại")
                    .font(.subheadline.bold())
                    .foregroundColor(.dustyRose)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .pastelCard()
    }

    // MARK: - AI Result View

    private func aiResultView(_ food: FoodItem) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.peachYellow)
                Text("Kết quả từ AI")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("Ước tính")
                    .font(.caption2)
                    .foregroundColor(.peachYellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.peachYellow.opacity(0.15))
                    .cornerRadius(8)
            }

            // Food preview card
            Button(action: {
                selectedFood = food
                showFoodDetail = true
            }) {
                HStack(spacing: 12) {
                    Text(food.icon)
                        .font(.largeTitle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.textPrimary)
                        HStack(spacing: 6) {
                            Text("\(Int(food.calories)) kcal")
                                .font(.caption.bold())
                                .foregroundColor(.coralRed)
                            Text("P:\(Int(food.protein))g  C:\(Int(food.carbs))g  F:\(Int(food.fat))g")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }
                        Text("Nhấn để xem chi tiết →")
                            .font(.caption2)
                            .foregroundColor(.dustyRose)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.softGray)
                }
                .padding(14)
                .background(Color.softPink.opacity(0.4))
                .cornerRadius(14)
            }
            .buttonStyle(PlainButtonStyle())

            // Action buttons
            VStack(spacing: 10) {
                // Thêm vào bữa ăn
                Button(action: {
                    let meal = MealEntry(
                        name: food.name,
                        calories: food.calories,
                        protein: food.protein,
                        carbs: food.carbs,
                        fat: food.fat,
                        date: viewModel.selectedDate
                    )
                    viewModel.addMeal(meal)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Thêm vào bữa ăn")
                            .fontWeight(.semibold)
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

                // Thoát
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text("Thoát")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.textSecondary)
                    .background(Color.softGray.opacity(0.3))
                    .cornerRadius(12)
                }
            }
        }
        .pastelCard()
    }

    // MARK: - Search Logic

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        // Reset AI states
        showAISuggestion = false
        aiResult = nil
        aiError = false
        isAILoading = false

        isSearching = true
        searchResults = FoodLookupService.shared.search(query: query)
        hasSearched = true
        isSearching = false
    }

    private func performAILookup() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isAILoading = true
        showAISuggestion = false
        aiResult = nil
        aiError = false

        AIFoodEstimator.shared.estimateNutrition(query: query) { result in
            isAILoading = false
            if let food = result {
                aiResult = food
            } else {
                showAISuggestion = true
                aiError = true
            }
        }
    }
}
