//
//  ContentView.swift
//  MenstrualCycle
//
//  Màn hình chính chứa TabView với 4 tab chức năng.
//  Truyền userId từ AuthViewModel đến tất cả ViewModel con.
//  Sử dụng NavigationView (chuẩn iOS 15). KHÔNG dùng NavigationStack.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab: Int = 0

    @StateObject private var cycleViewModel = CycleViewModel()
    @StateObject private var nutritionViewModel = NutritionViewModel()
    @StateObject private var fitnessViewModel = FitnessViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            // ── Tab 1: Chu kỳ ─────────────────────────────────
            NavigationView {
                CycleView()
                    .environmentObject(cycleViewModel)
                    .navigationTitle("Chu kỳ")
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: AppTab.cycle.iconName)
                Text(AppTab.cycle.title)
            }
            .tag(AppTab.cycle.rawValue)

            // ── Tab 2: Dinh dưỡng ────────────────────────────
            NavigationView {
                NutritionView()
                    .environmentObject(nutritionViewModel)
                    .navigationTitle("Dinh dưỡng")
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: AppTab.nutrition.iconName)
                Text(AppTab.nutrition.title)
            }
            .tag(AppTab.nutrition.rawValue)

            // ── Tab 3: Thể dục ───────────────────────────────
            NavigationView {
                FitnessView(viewModel: fitnessViewModel)
                    .navigationTitle("Thể dục")
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: AppTab.fitness.iconName)
                Text(AppTab.fitness.title)
            }
            .tag(AppTab.fitness.rawValue)

            // ── Tab 4: Tài khoản ─────────────────────────────
            NavigationView {
                AccountView()
                    .navigationTitle("Tài khoản")
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: AppTab.account.iconName)
                Text(AppTab.account.title)
            }
            .tag(AppTab.account.rawValue)
        }
        .accentColor(.dustyRose)
        .onAppear {
            configureTabBarAppearance()
            loadAllData()
        }
        .onChange(of: authViewModel.currentUserId) { _ in
            loadAllData()
        }
    }

    // MARK: - Load Data for current user
    private func loadAllData() {
        guard let userId = authViewModel.currentUserId else { return }
        let userName = authViewModel.currentUserName

        cycleViewModel.setUserId(userId, userName: userName.isEmpty ? "Bạn" : userName)
        nutritionViewModel.setUserId(userId)
        fitnessViewModel.setUserId(userId)
    }

    // MARK: - Tab Bar Appearance (iOS 15 compatible)
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.creamWhite)

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(Color.softGray)
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.softGray)

        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(Color.dustyRose)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.dustyRose)

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
    }
}
