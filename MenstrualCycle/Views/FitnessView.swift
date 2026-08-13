//
//  FitnessView.swift
//  MenstrualCycle
//
//  Tab 3: Thể dục & Bài tập — kết nối SQLite qua FitnessViewModel.
//  Tương thích iOS 15+.
//

import SwiftUI

struct FitnessView: View {
    @ObservedObject var viewModel: FitnessViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ── Header ──────────────────────────────────────
                headerSection

                // ── Today's Goal ────────────────────────────────
                todayGoalCard

                // ── Workout Categories ──────────────────────────
                workoutCategories

                // ── Suggested Workouts ──────────────────────────
                suggestedWorkouts

                // ── Today's Log ─────────────────────────────────
                if !viewModel.todayEntries.isEmpty {
                    todayLogSection
                }

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
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $viewModel.showAddWorkout) {
            addWorkoutSheet
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vận động nào! 💪")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                Text("Thể dục")
                    .font(.title.bold())
                    .foregroundColor(.textPrimary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.peachYellow)
                Text("\(viewModel.todayCaloriesBurned) cal")
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

    // MARK: - Today's Goal
    private var todayGoalCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mục tiêu hôm nay")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    Text("\(viewModel.dailyGoalMinutes) phút vận động")
                        .font(.title3.bold())
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.softGray, lineWidth: 6)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: viewModel.goalProgress)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: Color.gradientPink),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    Text(viewModel.goalPercentText)
                        .font(.caption.bold())
                        .foregroundColor(.dustyRose)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.softGray)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: Color.gradientPink),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(viewModel.goalProgress), height: 6)
                }
            }
            .frame(height: 6)
        }
        .pastelCard()
    }

    // MARK: - Workout Categories
    private var workoutCategories: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Loại bài tập")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Button(action: { viewModel.showAddWorkout = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Thêm")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.dustyRose)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    categoryChip(icon: "figure.yoga", name: "Yoga", color: .lavender)
                    categoryChip(icon: "figure.walk", name: "Đi bộ", color: .mintGreen)
                    categoryChip(icon: "figure.run", name: "Chạy bộ", color: .peachYellow)
                    categoryChip(icon: "figure.cooldown", name: "Giãn cơ", color: .pastelPink)
                }
            }
        }
    }

    private func categoryChip(icon: String, name: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            Text(name)
                .font(.caption)
                .foregroundColor(.textPrimary)
        }
        .frame(width: 80)
    }

    // MARK: - Suggested Workouts
    private var suggestedWorkouts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bài tập gợi ý")
                .font(.headline)
                .foregroundColor(.textPrimary)

            ForEach(viewModel.workoutTemplates, id: \.name) { template in
                Button(action: {
                    viewModel.addWorkoutFromTemplate(template)
                }) {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lavender.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: template.icon)
                                    .foregroundColor(.lavender)
                                    .font(.title3)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.textPrimary)
                            Text("\(template.duration) phút")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Text("\(template.calories) kcal")
                            .font(.caption.bold())
                            .foregroundColor(.dustyRose)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.pastelPink.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .pastelCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Today's Log
    private var todayLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Đã tập hôm nay")
                .font(.headline)
                .foregroundColor(.textPrimary)

            ForEach(viewModel.todayEntries) { entry in
                HStack(spacing: 14) {
                    Image(systemName: entry.icon)
                        .font(.title3)
                        .foregroundColor(.dustyRose)
                        .frame(width: 40, height: 40)
                        .background(Color.pastelPink.opacity(0.2))
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.textPrimary)
                        Text("\(entry.durationMin) phút · \(entry.caloriesBurned) kcal")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.mintGreen)
                }
                .pastelCard()
            }
        }
    }

    // MARK: - Add Workout Sheet
    private var addWorkoutSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Name
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .foregroundColor(.dustyRose)
                        .frame(width: 20)
                    TextField("Tên bài tập", text: $viewModel.newWorkoutName)
                }
                .padding()
                .background(Color.creamWhite)
                .cornerRadius(14)

                // Duration
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .foregroundColor(.dustyRose)
                        .frame(width: 20)
                    TextField("Thời gian (phút)", text: $viewModel.newWorkoutDuration)
                        .keyboardType(.numberPad)
                }
                .padding()
                .background(Color.creamWhite)
                .cornerRadius(14)

                // Calories
                HStack(spacing: 12) {
                    Image(systemName: "bolt")
                        .foregroundColor(.dustyRose)
                        .frame(width: 20)
                    TextField("Calo đốt cháy", text: $viewModel.newWorkoutCalories)
                        .keyboardType(.numberPad)
                }
                .padding()
                .background(Color.creamWhite)
                .cornerRadius(14)

                Button(action: {
                    viewModel.addCustomWorkout()
                }) {
                    Text("Thêm bài tập")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: Color.gradientPink),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(24)
            .background(Color.softPink.ignoresSafeArea())
            .navigationTitle("Thêm bài tập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Huỷ") {
                        viewModel.showAddWorkout = false
                    }
                }
            }
        }
    }
}

struct FitnessView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FitnessView(viewModel: FitnessViewModel())
        }
    }
}
