//
//  SettingsDetailView.swift
//  MenstrualCycle
//
//  Cài đặt chi tiết
//

import SwiftUI

enum SettingsType: String {
    case notification = "Thông báo"
    case security = "Bảo mật"
    case language = "Ngôn ngữ"
    case appearance = "Giao diện"
    case help = "Trợ giúp & FAQ"
}

struct SettingsDetailView: View {
    let settingsType: SettingsType
    @Environment(\.presentationMode) var presentationMode
    
    // Notification states
    @State private var cycleNotif = true
    @State private var waterNotif = true
    @State private var exerciseNotif = false
    @State private var healthNotif = true
    
    // Security states
    @State private var faceIdEnabled = false
    @State private var appLockEnabled = false
    
    // Language & Appearance
    @State private var selectedLanguage = "vi"
    @State private var selectedTheme = "light"
    
    // FAQ
    @State private var expandedIndex: Int? = nil
    let faqs = [
        ("Làm sao để theo dõi chu kỳ?", "Bạn có thể vào tab Chu kỳ, nhấn vào icon bánh răng để thiết lập ngày bắt đầu và các chỉ số chu kỳ của bạn."),
        ("Dữ liệu có được bảo mật không?", "Có, tất cả dữ liệu của bạn được mã hóa và lưu trữ an toàn trên thiết bị của bạn (SQLite)."),
        ("Tính năng AI hoạt động thế nào?", "AI giúp phân tích các món ăn bạn nhập vào bằng ngôn ngữ tự nhiên để ước tính lượng calo và dinh dưỡng."),
        ("Làm sao để thêm hồ sơ người thân?", "Trong tab Chu kỳ, nhấn vào nút dấu '+' ở góc phải trên cùng để thêm hồ sơ mới."),
        ("Ứng dụng có miễn phí không?", "Có, MenstrualCycle hoàn toàn miễn phí cho các tính năng cơ bản.")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                switch settingsType {
                case .notification:
                    notificationContent
                case .security:
                    securityContent
                case .language:
                    languageContent
                case .appearance:
                    appearanceContent
                case .help:
                    helpContent
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.softPink.ignoresSafeArea())
        .navigationTitle(settingsType.rawValue)
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
    
    private var notificationContent: some View {
        VStack(spacing: 0) {
            toggleRow(icon: "bell.fill", color: .peachYellow, label: "Nhắc nhở chu kỳ", isOn: $cycleNotif)
            Divider().padding(.leading, 46)
            toggleRow(icon: "drop.fill", color: .mintGreen, label: "Nhắc nhở uống nước", isOn: $waterNotif)
            Divider().padding(.leading, 46)
            toggleRow(icon: "figure.walk", color: .coralRed, label: "Nhắc nhở tập thể dục", isOn: $exerciseNotif)
            Divider().padding(.leading, 46)
            toggleRow(icon: "heart.fill", color: .dustyRose, label: "Thông báo sức khỏe", isOn: $healthNotif)
        }
        .pastelCard()
    }
    
    private var securityContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 0) {
                toggleRow(icon: "faceid", color: .lavender, label: "Mở khóa bằng Face ID", isOn: $faceIdEnabled)
                Divider().padding(.leading, 46)
                toggleRow(icon: "lock.fill", color: .mintGreen, label: "Khóa ứng dụng", isOn: $appLockEnabled)
            }
            .pastelCard()
            
            VStack(spacing: 0) {
                actionRow(icon: "key.fill", color: .dustyRose, label: "Đổi mật khẩu", labelColor: .textPrimary)
                Divider().padding(.leading, 46)
                actionRow(icon: "trash.fill", color: .coralRed, label: "Xóa tài khoản", labelColor: .coralRed)
            }
            .pastelCard()
        }
    }
    
    private var languageContent: some View {
        VStack(spacing: 0) {
            selectionRow(label: "🇻🇳 Tiếng Việt", value: "vi", selectedValue: $selectedLanguage)
            Divider().padding(.leading, 16)
            selectionRow(label: "🇺🇸 English", value: "en", selectedValue: $selectedLanguage)
            Divider().padding(.leading, 16)
            selectionRow(label: "🇯🇵 日本語", value: "ja", selectedValue: $selectedLanguage)
            Divider().padding(.leading, 16)
            selectionRow(label: "🇰🇷 한국어", value: "ko", selectedValue: $selectedLanguage)
        }
        .pastelCard()
    }
    
    private var appearanceContent: some View {
        VStack(spacing: 0) {
            selectionRow(label: "☀️ Sáng", value: "light", selectedValue: $selectedTheme)
            Divider().padding(.leading, 16)
            selectionRow(label: "🌙 Tối", value: "dark", selectedValue: $selectedTheme)
            Divider().padding(.leading, 16)
            selectionRow(label: "📱 Theo hệ thống", value: "system", selectedValue: $selectedTheme)
        }
        .pastelCard()
    }
    
    private var helpContent: some View {
        VStack(spacing: 12) {
            ForEach(0..<faqs.count, id: \.self) { i in
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation {
                            if expandedIndex == i {
                                expandedIndex = nil
                            } else {
                                expandedIndex = i
                            }
                        }
                    }) {
                        HStack {
                            Text(faqs[i].0)
                                .font(.subheadline.bold())
                                .foregroundColor(.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: expandedIndex == i ? "chevron.up" : "chevron.down")
                                .foregroundColor(.dustyRose)
                                .font(.caption)
                        }
                    }
                    
                    if expandedIndex == i {
                        Text(faqs[i].1)
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .pastelCard()
            }
        }
    }
    
    // Helpers
    private func toggleRow(icon: String, color: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            Text(label)
                .font(.subheadline)
                .foregroundColor(.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.dustyRose)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    
    private func actionRow(icon: String, color: Color, label: String, labelColor: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            Text(label)
                .font(.subheadline)
                .foregroundColor(labelColor)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.softGray)
                .font(.caption)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    
    private func selectionRow(label: String, value: String, selectedValue: Binding<String>) -> some View {
        Button(action: {
            selectedValue.wrappedValue = value
        }) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
                Spacer()
                if selectedValue.wrappedValue == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.dustyRose)
                        .font(.title3)
                } else {
                    Circle()
                        .stroke(Color.softGray, lineWidth: 1)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }
}

struct SettingsDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsDetailView(settingsType: .notification)
        }
    }
}
