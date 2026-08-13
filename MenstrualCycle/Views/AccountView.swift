//
//  AccountView.swift
//  MenstrualCycle
//
//  Tab 4: Tài khoản & Cài đặt
//  Tương thích iOS 15+.
//

import SwiftUI

struct AccountView: View {
    // Truy cập trạng thái xác thực từ ViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    // Sheet chỉnh sửa hồ sơ
    @State private var showEditProfile: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ── Profile Header ──────────────────────────────
                profileHeader

                // ── Menu Sections ───────────────────────────────
                personalInfoSection

                appSettingsSection

                supportSection

                // ── Logout Button ───────────────────────────────
                logoutButton

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.softPink.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authViewModel)
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: Color.gradientPink),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                if let avatar = authViewModel.currentUserAvatar {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
            }

            VStack(spacing: 4) {
                Text(authViewModel.currentUserName.isEmpty ? "Người dùng" : authViewModel.currentUserName)
                    .font(.title2.bold())
                    .foregroundColor(.textPrimary)
                Text(authViewModel.currentUserPhone.isEmpty ? "" : "\(authViewModel.selectedCountryCode) \(authViewModel.currentUserPhone)")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }

            // Edit profile button
            Button(action: { showEditProfile = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Chỉnh sửa hồ sơ")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: Color.gradientPink),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(24)
            }
        }
        .pastelCard()
    }

    // MARK: - Personal Info Section
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Thông tin cá nhân")

            VStack(spacing: 0) {
                NavigationLink(destination: HealthProfileView()) {
                    menuRow(icon: "person.text.rectangle", title: "Hồ sơ sức khỏe", color: .pastelPink)
                }
                divider
                NavigationLink(destination: CycleHistoryView()) {
                    menuRow(icon: "heart.text.square", title: "Lịch sử chu kỳ", color: .dustyRose)
                }
                divider
                NavigationLink(destination: StatisticsView()) {
                    menuRow(icon: "chart.bar", title: "Thống kê", color: .lavender)
                }
            }
            .background(Color.creamWhite)
            .cornerRadius(16)
            .shadow(color: Color.dustyRose.opacity(0.1), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - App Settings Section
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Cài đặt ứng dụng")

            VStack(spacing: 0) {
                NavigationLink(destination: SettingsDetailView(settingsType: .notification)) {
                    menuRow(icon: "bell.badge", title: "Thông báo", color: .peachYellow)
                }
                divider
                NavigationLink(destination: SettingsDetailView(settingsType: .security)) {
                    menuRow(icon: "lock.shield", title: "Bảo mật", color: .mintGreen)
                }
                divider
                NavigationLink(destination: SettingsDetailView(settingsType: .language)) {
                    menuRow(icon: "globe", title: "Ngôn ngữ", color: .lavender)
                }
                divider
                NavigationLink(destination: SettingsDetailView(settingsType: .appearance)) {
                    menuRow(icon: "moon.stars", title: "Giao diện", color: .deepRose)
                }
            }
            .background(Color.creamWhite)
            .cornerRadius(16)
            .shadow(color: Color.dustyRose.opacity(0.1), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Hỗ trợ")

            VStack(spacing: 0) {
                NavigationLink(destination: SettingsDetailView(settingsType: .help)) {
                    menuRow(icon: "questionmark.circle", title: "Trợ giúp & FAQ", color: .pastelPink)
                }
                divider
                Button(action: { exportDatabase() }) {
                    menuRow(icon: "square.and.arrow.up", title: "Xuất dữ liệu SQLite (AirDrop/iCloud)", color: .mintGreen)
                }
                .buttonStyle(.plain)
                divider
                menuRow(icon: "star", title: "Đánh giá ứng dụng", color: .peachYellow)
                divider
                menuRow(icon: "info.circle", title: "Phiên bản 1.0.0", color: .softGray)
            }
            .background(Color.creamWhite)
            .cornerRadius(16)
            .shadow(color: Color.dustyRose.opacity(0.1), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Logout
    private var logoutButton: some View {
        Button(action: { authViewModel.logout() }) {
            HStack {
                Spacer()
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Đăng xuất")
                    .fontWeight(.semibold)
                Spacer()
            }
            .foregroundColor(.coralRed)
            .padding()
            .background(Color.creamWhite)
            .cornerRadius(16)
            .shadow(color: Color.dustyRose.opacity(0.1), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Helpers
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundColor(.textSecondary)
            .padding(.leading, 4)
            .padding(.bottom, 4)
    }

    private func menuRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
            }

            Text(title)
                .font(.subheadline)
                .foregroundColor(.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.softGray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 66)
    }

    private func exportDatabase() {
        let dbURL = DatabaseManager.shared.databaseURL
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return }
        
        let activityVC = UIActivityViewController(activityItems: [dbURL], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            // iPad compatibility
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = rootVC.view
                popoverController.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AccountView()
        }
        .environmentObject(AuthViewModel())
    }
}
