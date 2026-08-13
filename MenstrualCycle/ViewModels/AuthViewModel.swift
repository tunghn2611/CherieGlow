//
//  AuthViewModel.swift
//  MenstrualCycle
//
//  ViewModel quản lý luồng xác thực: SĐT + OTP tự động điền, Sign in with Apple,
//  Google Sign-In, Facebook Login, chọn ảnh đại diện & lưu SQLite.
//  Tương thích iOS 15+.
//

import SwiftUI
import Combine
import UserNotifications
import AuthenticationServices
import GoogleSignIn
import FacebookLogin

class AuthViewModel: ObservableObject {

    // MARK: - Auth State
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false

    // MARK: - Login Step
    enum LoginStep: Int {
        case phone = 0      // Bước 1: Nhập SĐT
        case otp = 1        // Bước 2: Nhập OTP
        case profile = 2    // Bước 3: Nhập thông tin cơ bản (chỉ lần đầu)
    }
    @Published var currentStep: LoginStep = .phone

    // MARK: - Phone Fields
    @Published var selectedCountryCode: String = "+84"
    @Published var phoneNumber: String = ""

    // MARK: - OTP Fields
    @Published var otpCode: String = ""
    @Published var generatedOTP: String = ""
    @Published var otpCountdown: Int = 0
    @Published var autoFilledOTP: String = ""  // Khi server trả OTP trong dev mode
    private var countdownTimer: AnyCancellable?

    // MARK: - Profile Fields (lần đầu đăng nhập)
    @Published var profileName: String = ""
    @Published var profileGender: String = ""
    @Published var profileDateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var profileImage: UIImage? = nil

    // MARK: - Current User
    @Published var currentUserId: String? = nil
    @Published var currentUserName: String = ""
    @Published var currentUserPhone: String = ""
    @Published var currentUserGender: String = ""
    @Published var currentUserDateOfBirth: Date? = nil
    @Published var currentUserAvatar: UIImage? = nil
    @Published var currentUserAvatarPath: String = ""
    @Published var selectedCountryCodeForCurrentUser: String = "+84"

    // MARK: - Helper Properties
    let genderOptions = ["Nữ", "Nam", "Khác"]
    private let userRepo = UserRepository()
    private let savedUserIdKey = "mc_saved_user_id"
    private var appleSignInCoordinator: AppleSignInCoordinator?

    /// Chuẩn hóa số điện thoại: loại bỏ khoảng trắng, dấu gạch, và số 0 đầu
    private func normalizePhone(_ phone: String) -> String {
        var p = phone.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: ".", with: "")
        if p.hasPrefix("0") { p = String(p.dropFirst()) }
        return p
    }

    var maskedPhoneNumber: String {
        let phone = phoneNumber.trimmingCharacters(in: .whitespaces)
        guard phone.count >= 4 else { return phone }
        let prefix = String(phone.prefix(3))
        let suffix = String(phone.suffix(2))
        let mask = String(repeating: "*", count: max(0, phone.count - 5))
        return "\(selectedCountryCode) \(prefix)\(mask)\(suffix)"
    }

    struct CountryCode: Identifiable {
        let id = UUID()
        let flag: String
        let name: String
        let code: String
    }

    let countryCodes: [CountryCode] = [
        CountryCode(flag: "🇻🇳", name: "Việt Nam", code: "+84"),
        CountryCode(flag: "🇺🇸", name: "Hoa Kỳ", code: "+1"),
        CountryCode(flag: "🇬🇧", name: "Anh", code: "+44"),
        CountryCode(flag: "🇯🇵", name: "Nhật Bản", code: "+81"),
        CountryCode(flag: "🇰🇷", name: "Hàn Quốc", code: "+82"),
        CountryCode(flag: "🇨🇳", name: "Trung Quốc", code: "+86"),
        CountryCode(flag: "🇹🇭", name: "Thái Lan", code: "+66"),
        CountryCode(flag: "🇸🇬", name: "Singapore", code: "+65"),
        CountryCode(flag: "🇦🇺", name: "Úc", code: "+61")
    ]

    // MARK: - Init — Auto-login
    init() {
        requestNotificationPermission()
        loadSavedUserAsync()
    }
    
    private func loadSavedUserAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let savedId = UserDefaults.standard.string(forKey: self.savedUserIdKey) {
                if let userInfo = self.userRepo.fetchUser(byId: savedId) {
                    let avatar = !userInfo.avatarPath.isEmpty ? AvatarHelper.loadAvatar(fileName: userInfo.avatarPath) : nil
                    
                    DispatchQueue.main.async {
                        self.currentUserId = savedId
                        self.currentUserName = userInfo.name
                        self.currentUserPhone = userInfo.phone
                        self.currentUserGender = userInfo.gender
                        self.currentUserDateOfBirth = userInfo.dateOfBirth
                        self.selectedCountryCodeForCurrentUser = userInfo.countryCode
                        self.currentUserAvatarPath = userInfo.avatarPath
                        self.currentUserAvatar = avatar
                        self.isAuthenticated = true
                    }
                } else {
                    // User ID exists in UserDefaults but not in SQLite — try restoring from server token
                    if APIService.shared.hasValidToken() {
                        // User was authenticated via server but local DB was wiped
                        let _ = self.userRepo.ensureLocalUser(userId: savedId)
                        DispatchQueue.main.async {
                            self.currentUserId = savedId
                            self.isAuthenticated = true
                        }
                    }
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Step 1: Send OTP
    func sendOTP() {
        let phone = phoneNumber.trimmingCharacters(in: .whitespaces)
        guard !phone.isEmpty else {
            showErrorMessage("Vui lòng nhập số điện thoại")
            return
        }
        
        isLoading = true
        let normalizedPhone = normalizePhone(phone)
        let fullPhone = "\(selectedCountryCode)\(normalizedPhone)"
        
        APIService.shared.sendOTP(target: fullPhone, type: "sms", purpose: "login") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    if response.success {
                        // Chuyển sang bước nhập OTP
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.currentStep = .otp
                        }
                        self.startCountdown()
                        
                        // Dev mode: nếu server trả OTP thì tự điền
                        if let otpCode = response.data?.otpCode, !otpCode.isEmpty {
                            self.autoFilledOTP = otpCode
                            self.otpCode = otpCode
                            self.sendLocalNotification(otpCode: otpCode)
                            // Auto-verify sau 1 giây
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if !self.otpCode.isEmpty {
                                    self.verifyOTP()
                                }
                            }
                        }
                    } else {
                        self.showErrorMessage(response.message)
                    }
                case .failure(let error):
                    self.showErrorMessage("Lỗi kết nối: \(error.localizedDescription)")
                }
            }
        }
    }

    private func sendLocalNotification(otpCode: String) {
        let content = UNMutableNotificationContent()
        content.title = "💬 Tin nhắn từ Chérie Glow"
        content.body = "Mã xác thực OTP của bạn là: \(otpCode). Vui lòng không chia sẻ mã này."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: "otpNotification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Step 2: Verify OTP
    func verifyOTP() {
        let code = otpCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else {
            showErrorMessage("Vui lòng nhập mã OTP")
            return
        }
        
        isLoading = true
        let normalizedPhone = normalizePhone(phoneNumber.trimmingCharacters(in: .whitespaces))
        let fullPhone = "\(selectedCountryCode)\(normalizedPhone)"
        
        APIService.shared.verifyOTP(target: fullPhone, otpCode: code, purpose: "login") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                self.stopCountdown()
                
                switch result {
                case .success(let response):
                    if response.success, let authData = response.data {
                        let phoneClean = self.phoneNumber.trimmingCharacters(in: .whitespaces)
                        let countryCodeClean = self.selectedCountryCode
                        
                        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                            guard let self = self else { return }
                            
                            let _ = self.userRepo.ensureLocalUser(
                                userId: authData.user.id,
                                countryCode: countryCodeClean,
                                phone: self.normalizePhone(phoneClean),
                                name: authData.user.name ?? "",
                                provider: "phone",
                                profileCompleted: authData.user.profileCompleted
                            )
                            
                            // Di chuyển dữ liệu cũ nếu userId thay đổi
                            let oldUserId = UserDefaults.standard.string(forKey: self.savedUserIdKey)
                            if let oldId = oldUserId, !oldId.isEmpty, oldId != authData.user.id {
                                self.migrateLocalData(from: oldId, to: authData.user.id)
                            }
                            
                            DispatchQueue.main.async {
                                self.currentUserId = authData.user.id
                                UserDefaults.standard.set(authData.user.id, forKey: self.savedUserIdKey)
                                
                                if authData.user.profileCompleted {
                                    self.currentUserName = authData.user.name ?? ""
                                    self.currentUserPhone = authData.user.phone ?? ""
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        self.isAuthenticated = true
                                    }
                                } else {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        self.currentStep = .profile
                                    }
                                }
                            }
                        }
                    } else {
                        self.showErrorMessage(response.message)
                    }
                case .failure(let error):
                    self.showErrorMessage("Xác thực thất bại: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Step 3: Save Profile
    func saveProfile() {
        let name = profileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            showErrorMessage("Vui lòng nhập tên của bạn")
            return
        }

        isLoading = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dobString = formatter.string(from: profileDateOfBirth)
        
        // Lưu profile vào SQLite local trước
        if let userId = currentUserId {
            var avatarFileName = ""
            if let image = profileImage {
                avatarFileName = AvatarHelper.saveAvatar(image, userId: userId) ?? ""
            }
            let _ = userRepo.updateProfile(userId: userId, name: name, gender: profileGender, dateOfBirth: profileDateOfBirth, avatarPath: avatarFileName)
            currentUserAvatarPath = avatarFileName
            if !avatarFileName.isEmpty {
                currentUserAvatar = profileImage
            }
        }
        
        // Cũng gửi lên server (nếu có token)
        APIService.shared.saveProfileInfo(name: name, gender: profileGender, dob: dobString) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    if response.success {
                        self.currentUserName = name
                        self.currentUserGender = self.profileGender
                        self.currentUserDateOfBirth = self.profileDateOfBirth
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.isAuthenticated = true
                        }
                    } else {
                        // Server lỗi nhưng đã lưu local → vẫn cho đăng nhập
                        self.currentUserName = name
                        self.currentUserGender = self.profileGender
                        self.currentUserDateOfBirth = self.profileDateOfBirth
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.isAuthenticated = true
                        }
                    }
                case .failure(_):
                    // Offline nhưng đã lưu local → vẫn cho đăng nhập
                    self.currentUserName = name
                    self.currentUserGender = self.profileGender
                    self.currentUserDateOfBirth = self.profileDateOfBirth
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isAuthenticated = true
                    }
                }
            }
        }
    }

    // MARK: - Sign in with Apple (iCloud)
    func loginWithApple() {
        isLoading = true
        appleSignInCoordinator = AppleSignInCoordinator()
        
        appleSignInCoordinator?.onComplete = { [weak self] appleUserId, fullName, email in
            guard let self = self else { return }
            
            let name = fullName.isEmpty ? "Người dùng Apple" : fullName
            guard let userId = self.userRepo.findOrCreateByApple(appleUserId: appleUserId, fullName: name) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showErrorMessage("Đăng nhập bằng iCloud thất bại. Vui lòng thử lại.")
                }
                return
            }

            DispatchQueue.main.async {
                self.currentUserId = userId
                UserDefaults.standard.set(userId, forKey: self.savedUserIdKey)

                if self.userRepo.isProfileCompleted(userId: userId) {
                    self.loadUserInfo(userId: userId)
                    self.isLoading = false
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isAuthenticated = true
                    }
                } else {
                    self.isLoading = false
                    self.profileName = name
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.currentStep = .profile
                    }
                }
            }
        }

        appleSignInCoordinator?.onError = { [weak self] errorMsg in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.showErrorMessage(errorMsg)
            }
        }

        appleSignInCoordinator?.startSignIn()
    }

    // MARK: - Google Sign-In (OAuth thật)
    func loginWithGoogle() {
        isLoading = true
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isLoading = false
            showErrorMessage("Không thể mở màn hình đăng nhập Google.")
            return
        }
        
        // Sử dụng GIDSignIn SDK — chuyển hướng sang trang đăng nhập Google thật
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    // Người dùng cancel thì không hiện lỗi
                    if (error as NSError).code == GIDSignInError.canceled.rawValue {
                        return
                    }
                    self.showErrorMessage("Đăng nhập Google thất bại: \(error.localizedDescription)")
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.isLoading = false
                    self.showErrorMessage("Không thể lấy thông tin từ Google.")
                    return
                }
                
                let email = user.profile?.email ?? ""
                let fullName = user.profile?.name ?? ""
                let avatarURL = user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""
                
                // Gửi idToken lên backend để xác thực + tạo tài khoản
                APIService.shared.loginWithGoogle(idToken: idToken) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.isLoading = false
                        
                        switch result {
                        case .success(let response):
                            if response.success, let authData = response.data {
                                self.handleSocialAuthSuccess(
                                    authData: authData,
                                    provider: "google",
                                    displayName: fullName,
                                    email: email
                                )
                            } else {
                                // Nếu backend không có endpoint Google → fallback tạo tài khoản local
                                self.handleSocialFallback(provider: "google", name: fullName, email: email)
                            }
                        case .failure(_):
                            // Server không kết nối → fallback tạo tài khoản local
                            self.handleSocialFallback(provider: "google", name: fullName, email: email)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Facebook Login (OAuth thật)
    func loginWithFacebook() {
        isLoading = true
        
        let loginManager = LoginManager()
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isLoading = false
            showErrorMessage("Không thể mở màn hình đăng nhập Facebook.")
            return
        }
        
        // Sử dụng Facebook LoginManager — chuyển hướng sang trang đăng nhập Facebook thật
        loginManager.logIn(permissions: ["public_profile", "email"], from: rootVC) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    self.showErrorMessage("Đăng nhập Facebook thất bại: \(error.localizedDescription)")
                    return
                }
                
                guard let result = result, !result.isCancelled else {
                    self.isLoading = false
                    return // Người dùng cancel
                }
                
                guard let accessToken = AccessToken.current?.tokenString else {
                    self.isLoading = false
                    self.showErrorMessage("Không thể lấy token từ Facebook.")
                    return
                }
                
                // Gửi accessToken lên backend để xác thực
                APIService.shared.loginWithFacebook(accessToken: accessToken) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.isLoading = false
                        
                        switch result {
                        case .success(let response):
                            if response.success, let authData = response.data {
                                self.handleSocialAuthSuccess(
                                    authData: authData,
                                    provider: "facebook",
                                    displayName: authData.user.name ?? "",
                                    email: authData.user.email ?? ""
                                )
                            } else {
                                // Fallback: lấy thông tin từ Graph API rồi tạo local
                                self.fetchFacebookProfileAndFallback(accessToken: accessToken)
                            }
                        case .failure(_):
                            // Server không kết nối → fallback
                            self.fetchFacebookProfileAndFallback(accessToken: accessToken)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Social Auth Helpers
    
    /// Xử lý khi backend trả về thành công cho social login
    private func handleSocialAuthSuccess(authData: APIService.AuthData, provider: String, displayName: String, email: String) {
        let nameToUse = displayName.isEmpty ? (authData.user.name ?? "") : displayName
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let _ = self.userRepo.ensureLocalUser(
                userId: authData.user.id,
                phone: "",
                name: nameToUse,
                provider: provider,
                profileCompleted: authData.user.profileCompleted
            )
            
            DispatchQueue.main.async {
                self.currentUserId = authData.user.id
                UserDefaults.standard.set(authData.user.id, forKey: self.savedUserIdKey)
                
                if authData.user.profileCompleted {
                    self.currentUserName = authData.user.name ?? displayName
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isAuthenticated = true
                    }
                } else {
                    self.profileName = nameToUse
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.currentStep = .profile
                    }
                }
            }
        }
    }
    
    /// Fallback: tìm hoặc tạo tài khoản local khi server không có/không kết nối
    private func handleSocialFallback(provider: String, name: String, email: String) {
        let displayName = name.isEmpty ? "Người dùng \(provider.capitalized)" : name
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Tìm user cũ theo provider + email trước, không tạo mới mỗi lần
            let existingUserId = self.userRepo.findByProviderEmail(provider: provider, email: email)
            let userId = existingUserId ?? UUID().uuidString
            
            if existingUserId == nil {
                let _ = self.userRepo.ensureLocalUser(
                    userId: userId,
                    phone: "",
                    name: displayName,
                    provider: provider,
                    profileCompleted: false
                )
            }
            
            // Di chuyển dữ liệu cũ nếu userId thay đổi
            let oldUserId = UserDefaults.standard.string(forKey: self.savedUserIdKey)
            if let oldId = oldUserId, !oldId.isEmpty, oldId != userId {
                self.migrateLocalData(from: oldId, to: userId)
            }
            
            DispatchQueue.main.async {
                self.currentUserId = userId
                UserDefaults.standard.set(userId, forKey: self.savedUserIdKey)
                self.profileName = displayName
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentStep = .profile
                }
            }
        }
    }
    
    /// Lấy profile Facebook từ Graph API rồi tạo tài khoản local
    private func fetchFacebookProfileAndFallback(accessToken: String) {
        let graphRequest = GraphRequest(graphPath: "me", parameters: ["fields": "name,email,picture.width(200)"])
        graphRequest.start { [weak self] _, result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                var name = "Người dùng Facebook"
                var email = ""
                
                if let userData = result as? [String: Any] {
                    name = userData["name"] as? String ?? name
                    email = userData["email"] as? String ?? ""
                }
                
                self.handleSocialFallback(provider: "facebook", name: name, email: email)
            }
        }
    }

    // MARK: - Timer Countdown
    private func startCountdown() {
        otpCountdown = 60
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.otpCountdown > 0 {
                    self.otpCountdown -= 1
                } else {
                    self.stopCountdown()
                }
            }
    }

    private func stopCountdown() {
        countdownTimer?.cancel()
        countdownTimer = nil
        otpCountdown = 0
    }

    // MARK: - Back to Previous Step
    func goBackStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .otp:
                otpCode = ""
                autoFilledOTP = ""
                currentStep = .phone
            case .profile:
                break
            case .phone:
                break
            }
        }
    }

    // MARK: - Logout
    func logout() {
        // Đăng xuất Google
        GIDSignIn.sharedInstance.signOut()
        
        // Đăng xuất Facebook
        LoginManager().logOut()
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isAuthenticated = false
        }
        UserDefaults.standard.removeObject(forKey: savedUserIdKey)
        APIService.shared.clearTokens()
        resetAllState()
    }

    // MARK: - Private Helpers
    private func loadUserInfo(userId: String) {
        if let userInfo = userRepo.fetchUser(byId: userId) {
            currentUserName = userInfo.name
            currentUserPhone = userInfo.phone
            currentUserGender = userInfo.gender
            currentUserDateOfBirth = userInfo.dateOfBirth
            currentUserAvatarPath = userInfo.avatarPath
            selectedCountryCodeForCurrentUser = userInfo.countryCode
            if !userInfo.avatarPath.isEmpty {
                currentUserAvatar = AvatarHelper.loadAvatar(fileName: userInfo.avatarPath)
            } else {
                currentUserAvatar = nil
            }
        }
    }

    private func resetAllState() {
        currentUserId = nil
        currentUserName = ""
        currentUserPhone = ""
        currentUserGender = ""
        currentUserDateOfBirth = nil
        currentUserAvatar = nil
        currentUserAvatarPath = ""
        currentStep = .phone
        phoneNumber = ""
        otpCode = ""
        generatedOTP = ""
        autoFilledOTP = ""
        profileName = ""
        profileGender = ""
        profileDateOfBirth = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
        profileImage = nil
        errorMessage = ""
        showError = false
        stopCountdown()
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Data Migration Helper
    private func migrateLocalData(from oldUserId: String, to newUserId: String) {
        userRepo.migrateUserData(from: oldUserId, to: newUserId)
    }
}
