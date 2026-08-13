//
//  AppleSignInCoordinator.swift
//  MenstrualCycle
//
//  Coordinator cho Sign in with Apple (ASAuthorizationController).
//  Tương thích iOS 15+.
//

import AuthenticationServices
import Foundation

class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    var onComplete: ((String, String, String) -> Void)?  // (appleUserId, fullName, email)
    var onError: ((String) -> Void)?

    func startSignIn() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            onError?("Không thể lấy thông tin xác thực Apple")
            return
        }

        let userId = appleIDCredential.user
        let fullName: String = {
            if let nameComponents = appleIDCredential.fullName {
                let givenName = nameComponents.givenName ?? ""
                let familyName = nameComponents.familyName ?? ""
                let name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                return name.isEmpty ? "" : name
            }
            return ""
        }()
        let email = appleIDCredential.email ?? ""

        onComplete?(userId, fullName, email)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.code == ASAuthorizationError.canceled.rawValue {
            // Người dùng huỷ → không hiển thị lỗi
            return
        }
        onError?("Đăng nhập Apple thất bại: \(error.localizedDescription)")
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
