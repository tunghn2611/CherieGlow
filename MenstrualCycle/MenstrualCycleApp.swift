import SwiftUI
import GoogleSignIn
import FacebookCore

@main
struct MenstrualCycleApp: App {
    // MARK: - ViewModel xác thực ở cấp ứng dụng
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        configureNavigationBarAppearance()
        // Khởi tạo Facebook SDK bất đồng bộ để tránh chặn main thread lúc khởi chạy
        DispatchQueue.main.async {
            ApplicationDelegate.shared.initializeSDK()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    // Xử lý callback URL từ Google Sign-In và Facebook Login
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    ApplicationDelegate.shared.application(
                        UIApplication.shared,
                        open: url,
                        sourceApplication: nil,
                        annotation: [UIApplication.OpenURLOptionsKey.annotation]
                    )
                }
        }
    }

    // MARK: - Global Navigation Bar Style (iOS 15 safe)
    private func configureNavigationBarAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.softPink)
        navAppearance.shadowColor = .clear

        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.textPrimary),
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.textPrimary),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}

// MARK: - RootView: Điều hướng giữa màn hình đăng nhập và màn hình chính
struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            if authViewModel.isAuthenticated {
                ContentView()
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        )
                    )
            } else {
                LoginView()
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        )
                    )
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authViewModel.isAuthenticated)
    }
}
