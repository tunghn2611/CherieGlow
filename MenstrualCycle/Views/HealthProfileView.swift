//
//  HealthProfileView.swift
//  MenstrualCycle
//
//  Hồ sơ sức khỏe
//

import SwiftUI

struct HealthProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ── Avatar ────────────────────────────────────
                avatarSection
                
                // ── Personal Info ─────────────────────────────
                personalInfoCard
                
                // ── Health Metrics ────────────────────────────
                healthMetricsCard
                
                // ── Medical Notes ─────────────────────────────
                medicalNotesCard
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.softPink.ignoresSafeArea())
        .navigationTitle("Hồ sơ sức khỏe")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
        }
    }
    
    private var avatarSection: some View {
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
    }
    
    private var personalInfoCard: some View {
        VStack(spacing: 12) {
            infoRow(icon: "person.fill", label: "Tên hiển thị", value: authViewModel.currentUserName.isEmpty ? "Người dùng" : authViewModel.currentUserName, color: .dustyRose)
            Divider()
            infoRow(icon: "phone.fill", label: "SĐT", value: authViewModel.currentUserPhone.isEmpty ? "" : "\(authViewModel.selectedCountryCode) \(authViewModel.currentUserPhone)", color: .pastelPink)
        }
        .pastelCard()
    }
    
    private var healthMetricsCard: some View {
        VStack(spacing: 12) {
            infoRow(icon: "drop.fill", label: "Nhóm máu", value: "Chưa cập nhật", color: .coralRed)
            Divider()
            infoRow(icon: "ruler.fill", label: "Chiều cao", value: "Chưa cập nhật", color: .mintGreen)
            Divider()
            infoRow(icon: "scalemass.fill", label: "Cân nặng", value: "Chưa cập nhật", color: .peachYellow)
            Divider()
            infoRow(icon: "calendar", label: "Ngày sinh", value: "Chưa cập nhật", color: .lavender)
        }
        .pastelCard()
    }
    
    private var medicalNotesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.softGray)
                Text("Ghi chú y tế")
                    .font(.subheadline.bold())
                    .foregroundColor(.textPrimary)
            }
            Text("Chưa có ghi chú y tế nào")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.softPink.opacity(0.5))
                .cornerRadius(12)
        }
        .pastelCard()
    }
    
    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.textPrimary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
    }
}

struct HealthProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HealthProfileView()
        }
        .environmentObject(AuthViewModel())
    }
}
