//
//  LoginView.swift
//  MenstrualCycle
//
//  Màn hình đăng nhập theo 3 bước thực tế:
//  1. Nhập SĐT + Mã quốc gia
//  2. Nhập OTP (6 ô riêng biệt, đếm ngược, tự động chuyển ô)
//  3. Nhập thông tin cá nhân (chọn ảnh đại diện từ Photo Library, Tên, Giới tính, Ngày sinh)
//  Tương thích iOS 15+.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // OTP Fields State
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var activeField: OTPField?
    
    enum OTPField: Hashable {
        case f1, f2, f3, f4, f5, f6
    }
    
    // Image Picker State
    @State private var showImagePicker: Bool = false

    var body: some View {
        ZStack {
            // ── Background ───────────────────────────────────
            LinearGradient(
                gradient: Gradient(colors: [Color.softPink, Color.creamWhite]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                switch authViewModel.currentStep {
                case .phone:
                    phoneStepView
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .otp:
                    otpStepView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case .profile:
                    profileStepView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }

            // ── Loading Overlay ──────────────────────────────
            if authViewModel.isLoading {
                loadingOverlay
            }
        }
        .alert(isPresented: $authViewModel.showError) {
            Alert(
                title: Text("Lỗi"),
                message: Text(authViewModel.errorMessage),
                dismissButton: .default(Text("Đồng ý"))
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $authViewModel.profileImage)
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - STEP 1: Phone Number
    // ═══════════════════════════════════════════════════════

    private var phoneStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                // Logo
                logoSection

                // Title
                VStack(spacing: 6) {
                    Text("Đăng nhập")
                        .font(.title2.bold())
                        .foregroundColor(.textPrimary)
                    Text("Nhập số điện thoại để tiếp tục")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }

                // Country Code + Phone
                VStack(spacing: 14) {
                    // Country Code Picker
                    Menu {
                        ForEach(authViewModel.countryCodes) { country in
                            Button(action: {
                                authViewModel.selectedCountryCode = country.code
                            }) {
                                HStack {
                                    Text(country.flag)
                                    Text(country.name)
                                    Text(country.code)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            let selected = authViewModel.countryCodes.first(where: { $0.code == authViewModel.selectedCountryCode })
                            Text(selected?.flag ?? "🇻🇳")
                                .font(.title3)
                            Text(authViewModel.selectedCountryCode)
                                .font(.body.bold())
                                .foregroundColor(.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                                .foregroundColor(.dustyRose)
                            Spacer()
                            Text(selected?.name ?? "Việt Nam")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                        }
                        .padding()
                        .background(Color.creamWhite)
                        .cornerRadius(14)
                        .shadow(color: Color.dustyRose.opacity(0.1), radius: 4, x: 0, y: 2)
                    }

                    // Phone Number Field
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.dustyRose)
                            .frame(width: 20)
                        TextField("Số điện thoại", text: $authViewModel.phoneNumber)
                            .keyboardType(.phonePad)
                            .disableAutocorrection(true)
                    }
                    .padding()
                    .background(Color.creamWhite)
                    .cornerRadius(14)
                    .shadow(color: Color.dustyRose.opacity(0.1), radius: 4, x: 0, y: 2)
                }

                // Send OTP Button
                Button(action: {
                    // Reset OTP Digits
                    otpDigits = Array(repeating: "", count: 6)
                    authViewModel.otpCode = ""
                    authViewModel.sendOTP()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Gửi mã OTP")
                            .fontWeight(.bold)
                    }
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
                    .shadow(color: Color.dustyRose.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(authViewModel.isLoading)

                // Divider
                orDivider

                // Social Login
                socialLoginSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - STEP 2: OTP Verification
    // ═══════════════════════════════════════════════════════

    private var otpStepView: some View {
        VStack(spacing: 24) {
            // Header with Back
            stepHeader(title: "Xác thực OTP") {
                authViewModel.goBackStep()
            }

            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.pastelPink.opacity(0.3))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: Color.gradientPink),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: Color.dustyRose.opacity(0.3), radius: 10, x: 0, y: 5)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            // Info
            VStack(spacing: 8) {
                Text("Mã OTP đã gửi đến")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                Text(authViewModel.maskedPhoneNumber)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }

            // 6-Digit OTP Box UI
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    TextField("", text: $otpDigits[index])
                        .keyboardType(.numberPad)
                        .font(.title2.bold().monospaced())
                        .multilineTextAlignment(.center)
                        .frame(width: 46, height: 52)
                        .background(Color.creamWhite)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(activeField == getField(index) ? Color.dustyRose : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: Color.dustyRose.opacity(0.08), radius: 4, x: 0, y: 2)
                        .focused($activeField, equals: getField(index))
                        .onChange(of: otpDigits[index]) { newValue in
                            handleOtpInput(value: newValue, index: index)
                        }
                }
            }
            .padding(.horizontal, 20)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    activeField = .f1
                }
            }
            .onChange(of: authViewModel.autoFilledOTP) { newCode in
                guard newCode.count == 6 else { return }
                let digits = Array(newCode)
                for i in 0..<6 {
                    otpDigits[i] = String(digits[i])
                }
                activeField = nil
            }

            // Countdown & Resend
            VStack(spacing: 12) {
                if authViewModel.otpCountdown > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .foregroundColor(.textSecondary)
                            .font(.caption)
                        Text("Gửi lại mã sau \(authViewModel.otpCountdown)s")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                } else {
                    Button(action: {
                        otpDigits = Array(repeating: "", count: 6)
                        authViewModel.otpCode = ""
                        authViewModel.sendOTP()
                        activeField = .f1
                    }) {
                        Text("Gửi lại mã OTP")
                            .font(.subheadline.bold())
                            .foregroundColor(.dustyRose)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }

            // Verify Button
            Button(action: {
                authViewModel.verifyOTP()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Xác minh")
                        .fontWeight(.bold)
                }
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
                .shadow(color: Color.dustyRose.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isLoading || authViewModel.otpCode.count < 6)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - STEP 3: Profile Setup (Có ảnh đại diện)
    // ═══════════════════════════════════════════════════════

    private var profileStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header (không có nút back)
                HStack {
                    Spacer()
                    Text("Thông tin cá nhân")
                        .font(.title3.bold())
                        .foregroundColor(.textPrimary)
                    Spacer()
                }
                .padding(.top, 20)

                // Interactive Avatar Chooser
                Button(action: {
                    showImagePicker = true
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: Color.gradientSoft),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .shadow(color: Color.dustyRose.opacity(0.15), radius: 8, x: 0, y: 4)

                        if let uiImage = authViewModel.profileImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                        } else {
                            Text("👤")
                                .font(.system(size: 48))
                        }

                        // Small badge overlay
                        Circle()
                            .fill(Color.dustyRose)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                            .offset(x: 38, y: 38)
                    }
                }
                .buttonStyle(.plain)

                Text("Nhấp để tải lên ảnh đại diện và hoàn tất thông tin")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)

                // Name Field
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.dustyRose)
                        .frame(width: 20)
                    TextField("Họ và tên", text: $authViewModel.profileName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
                .padding()
                .background(Color.creamWhite)
                .cornerRadius(14)
                .shadow(color: Color.dustyRose.opacity(0.1), radius: 4, x: 0, y: 2)

                // Gender Selection
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.dustyRose)
                            .font(.subheadline)
                        Text("Giới tính")
                            .font(.subheadline.bold())
                            .foregroundColor(.textPrimary)
                    }

                    HStack(spacing: 12) {
                        ForEach(authViewModel.genderOptions, id: \.self) { gender in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    authViewModel.profileGender = gender
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: genderIcon(gender))
                                        .font(.caption)
                                    Text(gender)
                                        .font(.subheadline.bold())
                                }
                                .foregroundColor(authViewModel.profileGender == gender ? .white : .textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    authViewModel.profileGender == gender
                                        ? AnyView(LinearGradient(
                                            gradient: Gradient(colors: Color.gradientPink),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          ))
                                        : AnyView(Color.creamWhite)
                                )
                                .cornerRadius(12)
                                .shadow(color: Color.dustyRose.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Date of Birth
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundColor(.dustyRose)
                            .font(.subheadline)
                        Text("Ngày sinh")
                            .font(.subheadline.bold())
                            .foregroundColor(.textPrimary)
                    }

                    DatePicker(
                        "",
                        selection: $authViewModel.profileDateOfBirth,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "vi_VN"))
                    .frame(maxHeight: 150)
                    .clipped()
                    .background(Color.creamWhite)
                    .cornerRadius(14)
                    .shadow(color: Color.dustyRose.opacity(0.1), radius: 4, x: 0, y: 2)
                }

                // Save Button
                Button(action: {
                    authViewModel.saveProfile()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Hoàn tất")
                            .fontWeight(.bold)
                    }
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
                    .shadow(color: Color.dustyRose.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(authViewModel.isLoading)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Helper functions for OTP Input
    // ═══════════════════════════════════════════════════════

    private func getField(_ index: Int) -> OTPField {
        switch index {
        case 0: return .f1
        case 1: return .f2
        case 2: return .f3
        case 3: return .f4
        case 4: return .f5
        default: return .f6
        }
    }

    private func handleOtpInput(value: String, index: Int) {
        if value.count > 1 {
            otpDigits[index] = String(value.last!)
        }
        
        authViewModel.otpCode = otpDigits.joined()

        if !value.isEmpty {
            // Tự động nhảy sang ô kế tiếp
            switch index {
            case 0: activeField = .f2
            case 1: activeField = .f3
            case 2: activeField = .f4
            case 3: activeField = .f5
            case 4: activeField = .f6
            default: activeField = nil
            }
        } else {
            // Tự động nhảy lùi về ô trước khi xoá
            switch index {
            case 5: activeField = .f5
            case 4: activeField = .f4
            case 3: activeField = .f3
            case 2: activeField = .f2
            case 1: activeField = .f1
            default: activeField = nil
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Shared Components
    // ═══════════════════════════════════════════════════════

    private var logoSection: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .shadow(color: Color.dustyRose.opacity(0.2), radius: 10, x: 0, y: 5)

            Text("Chérie Glow")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)

            Text("Theo dõi chu kỳ thông minh")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
    }

    private func stepHeader(title: String, backAction: @escaping () -> Void) -> some View {
        HStack {
            Button(action: backAction) {
                Image(systemName: "arrow.left")
                    .font(.title3.bold())
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.creamWhite)
                    .cornerRadius(12)
                    .shadow(color: Color.dustyRose.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.textPrimary)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var orDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color.softGray)
                .frame(height: 1)
            Text("hoặc")
                .font(.footnote)
                .foregroundColor(.textSecondary)
            Rectangle()
                .fill(Color.softGray)
                .frame(height: 1)
        }
    }

    private var socialLoginSection: some View {
        VStack(spacing: 12) {
            Text("Đăng nhập nhanh với")
                .font(.footnote)
                .foregroundColor(.textSecondary)

            socialRowButton(icon: "icloud.fill", label: "Đăng nhập bằng iCloud",
                            color: Color(red: 0.20, green: 0.60, blue: 1.0)) {
                authViewModel.loginWithApple()
            }
            socialRowButton(icon: "g.circle.fill", label: "Đăng nhập bằng Google",
                            color: Color(red: 0.85, green: 0.26, blue: 0.22)) {
                authViewModel.loginWithGoogle()
            }
            socialRowButton(icon: "f.circle.fill", label: "Đăng nhập bằng Facebook",
                            color: Color(red: 0.26, green: 0.40, blue: 0.70)) {
                authViewModel.loginWithFacebook()
            }
        }
    }

    private func socialRowButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(.system(size: 20))
                Spacer()
                Text(label).font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: icon).font(.system(size: 20)).hidden()
            }
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(14)
            .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func genderIcon(_ gender: String) -> String {
        switch gender {
        case "Nữ": return "figure.dress.line.vertical.figure"
        case "Nam": return "figure.stand"
        default: return "figure.wave"
        }
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .dustyRose))
                    .scaleEffect(1.3)
                Text("Đang xử lý...")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
            .padding(32)
            .background(Color.creamWhite)
            .cornerRadius(20)
            .shadow(color: Color.dustyRose.opacity(0.2), radius: 12, x: 0, y: 6)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
