//
//  FitnessViewModel.swift
//  MenstrualCycle
//
//  ViewModel quản lý Thể dục & Bài tập.
//  Kết nối SQLite qua FitnessRepository.
//  Tương thích iOS 15+.
//

import SwiftUI
import Combine

final class FitnessViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var todayEntries: [FitnessEntry] = []
    @Published var selectedDate: Date = Date()
    @Published var showAddWorkout: Bool = false
    @Published var todayCaloriesBurned: Int = 0
    @Published var todayMinutes: Int = 0

    // Add Workout Fields
    @Published var newWorkoutName: String = ""
    @Published var newWorkoutDuration: String = ""
    @Published var newWorkoutCalories: String = ""
    @Published var selectedWorkoutIcon: String = "figure.walk"

    // MARK: - Repository
    private let fitnessRepo = FitnessRepository()
    private var userId: String = ""

    // MARK: - Workout Templates
    let workoutTemplates: [(name: String, duration: Int, calories: Int, icon: String, colorHex: String)] = [
        ("Yoga buổi sáng", 20, 85, "figure.yoga", "B39DDB"),
        ("Đi bộ nhanh", 30, 150, "figure.walk", "81C784"),
        ("Chạy bộ", 25, 200, "figure.run", "FFB74D"),
        ("Bài tập hông", 15, 95, "figure.cooldown", "F48FB1"),
        ("Giãn cơ", 10, 40, "figure.cooldown", "F48FB1"),
        ("Đạp xe", 30, 250, "figure.outdoor.cycle", "4FC3F7")
    ]

    let workoutCategories: [(icon: String, name: String, colorName: String)] = [
        ("figure.yoga", "Yoga", "lavender"),
        ("figure.walk", "Đi bộ", "mintGreen"),
        ("figure.run", "Chạy bộ", "peachYellow"),
        ("figure.cooldown", "Giãn cơ", "pastelPink")
    ]

    // MARK: - Goal
    let dailyGoalMinutes: Int = 30

    var goalProgress: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(Double(todayMinutes) / Double(dailyGoalMinutes), 1.0)
    }

    var goalPercentText: String {
        "\(Int(goalProgress * 100))%"
    }

    // MARK: - Init
    init() {}

    // MARK: - Set User & Load Data

    func setUserId(_ id: String) {
        self.userId = id
        loadData()
    }

    func loadData() {
        guard !userId.isEmpty else { return }
        todayEntries = fitnessRepo.fetchEntries(for: userId, on: selectedDate)
        todayCaloriesBurned = fitnessRepo.todayTotalCalories(userId: userId)
        todayMinutes = fitnessRepo.todayTotalMinutes(userId: userId)
    }

    // MARK: - Add Workout from Template

    func addWorkoutFromTemplate(_ template: (name: String, duration: Int, calories: Int, icon: String, colorHex: String)) {
        guard !userId.isEmpty else { return }
        let entry = FitnessEntry(
            name: template.name,
            durationMin: template.duration,
            caloriesBurned: template.calories,
            icon: template.icon,
            colorHex: template.colorHex,
            date: selectedDate
        )
        if fitnessRepo.insertEntry(entry, userId: userId) {
            loadData()
        }
    }

    // MARK: - Add Custom Workout

    func addCustomWorkout() {
        guard !userId.isEmpty else { return }
        let name = newWorkoutName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let duration = Int(newWorkoutDuration) ?? 0
        let calories = Int(newWorkoutCalories) ?? 0

        let entry = FitnessEntry(
            name: name,
            durationMin: duration,
            caloriesBurned: calories,
            icon: selectedWorkoutIcon,
            colorHex: "F48FB1",
            date: selectedDate
        )
        if fitnessRepo.insertEntry(entry, userId: userId) {
            loadData()
            // Reset fields
            newWorkoutName = ""
            newWorkoutDuration = ""
            newWorkoutCalories = ""
            showAddWorkout = false
        }
    }

    // MARK: - Delete

    func deleteEntry(at offsets: IndexSet) {
        let entriesToDelete = offsets.map { todayEntries[$0] }
        for entry in entriesToDelete {
            let _ = fitnessRepo.deleteEntry(id: entry.id.uuidString)
        }
        loadData()
    }
}
