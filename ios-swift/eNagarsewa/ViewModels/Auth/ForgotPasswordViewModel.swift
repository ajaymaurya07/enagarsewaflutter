import Foundation
import CryptoKit

@MainActor
final class ForgotPasswordViewModel: ObservableObject {

    enum Step { case enterEmail, enterOtp, done }

    @Published var step: Step = .enterEmail
    @Published var email: String = ""
    @Published var otp: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api = APIService.shared
    let onSuccess: () -> Void

    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
    }

    func requestOtp() {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your email."; return
        }
        isLoading = true; errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let r = try await api.forgotPasswordRequest(email: email)
                if r.success { step = .enterOtp } else { errorMessage = r.message }
            } catch { errorMessage = networkMessage(error) }
        }
    }

    func verifyOtpAndReset() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."; return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."; return
        }
        isLoading = true; errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let hashedPass = sha512(newPassword)
                let r = try await api.verifyForgotPasswordOtp(
                    VerifyForgotPasswordOtpRequest(email: email, otp: otp, newPassword: hashedPass)
                )
                if r.success {
                    step = .done
                    successMessage = "Password reset successfully."
                    onSuccess()
                } else {
                    errorMessage = r.message
                }
            } catch { errorMessage = networkMessage(error) }
        }
    }

    private func sha512(_ input: String) -> String {
        SHA512.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func networkMessage(_ error: Error) -> String {
        (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
}
