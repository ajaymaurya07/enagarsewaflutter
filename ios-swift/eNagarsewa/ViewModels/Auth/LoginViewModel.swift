import Foundation
import Combine
import CryptoKit

@MainActor
final class LoginViewModel: ObservableObject {

    @Published var email: String = ""
    @Published var password: String = ""
    @Published var rememberMe: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api      = APIService.shared
    private let auth     = AuthManager.shared
    private let keychain = KeychainService.shared

    let onLoginSuccess: () -> Void
    let onSignUp: () -> Void
    let onForgotPass: () -> Void

    init(onLoginSuccess: @escaping () -> Void,
         onSignUp: @escaping () -> Void,
         onForgotPass: @escaping () -> Void) {
        self.onLoginSuccess = onLoginSuccess
        self.onSignUp = onSignUp
        self.onForgotPass = onForgotPass
        prefillRememberedCredentials()
    }

    // MARK: - Login flow (secure double-hash challenge-response, matches Flutter secureLogin)
    // hash = SHA512( SHA512(password) + challenge + timestamp + nonce )

    func login() {
        guard validate() else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let deviceId = DeviceSecurityService.shared.deviceId

                // Step 1: get challenge
                let challengeResp = try await api.getChallenge(username: email, deviceId: deviceId)
                guard challengeResp.status, let challengeData = challengeResp.data else {
                    errorMessage = challengeResp.message ?? "Challenge generation failed"
                    return
                }

                // Step 2: build the double-hash
                let hashedPassword = sha512(password)
                let nonce = generateNonce(16)
                let combined = hashedPassword + challengeData.challenge + challengeData.timestamp + nonce
                let finalHash = sha512(combined)

                // Step 3: submit login
                let loginResp = try await api.login(LoginRequest(
                    username: email,
                    deviceId: deviceId,
                    challengeId: challengeData.challengeId,
                    timestamp: challengeData.timestamp,
                    nonce: nonce,
                    hash: finalHash
                ))
                guard loginResp.success, let data = loginResp.data else {
                    errorMessage = loginResp.message
                    return
                }
                if rememberMe {
                    keychain.saveRememberMe(email: email, password: password)
                } else {
                    keychain.clearRememberMe()
                }
                successMessage = "Login successful!"
                // Clear fields after login (matches Flutter)
                email = ""
                password = ""
                auth.handleLoginSuccess(data)
                onLoginSuccess()
            } catch {
                errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Validation

    private func validate() -> Bool {
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter your email address."
            return false
        }
        if password.isEmpty {
            errorMessage = "Please enter your password."
            return false
        }
        return true
    }

    // MARK: - Remember-me prefill

    private func prefillRememberedCredentials() {
        if let saved = keychain.rememberMeEmail, !saved.isEmpty {
            email = saved
            password = keychain.rememberMePass ?? ""
            rememberMe = true
        }
    }

    // MARK: - SHA-512

    private func sha512(_ input: String) -> String {
        let hash = SHA512.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Matches Flutter's `_generateNonce`: `length` random lowercase-hex characters.
    private func generateNonce(_ length: Int) -> String {
        let chars = Array("0123456789abcdef")
        return String((0..<length).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }
}
