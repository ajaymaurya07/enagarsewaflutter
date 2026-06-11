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
    /// Shown as floating snackbar on the parent screen (email step)
    @Published var errorMessage: String?
    /// Shown inline inside the reset bottom sheet
    @Published var sheetErrorMessage: String?
    @Published var successMessage: String?

    /// Full password regex — matches Flutter:
    /// min 6 chars, uppercase, lowercase, digit, special char (@#$%^&+=!), no spaces
    private let passwordPattern = #"^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=!])(?=\S+$).{6,}$"#

    private let api = APIService.shared
    let onSuccess: () -> Void

    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
    }

    func requestOtp() {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your email."
            return
        }
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let r = try await api.forgotPasswordRequest(email: email)
                if r.success {
                    step = .enterOtp
                } else {
                    errorMessage = r.message.isEmpty ? "Failed to send OTP" : r.message
                }
            } catch { errorMessage = networkMessage(error) }
        }
    }

    func verifyOtpAndReset() {
        sheetErrorMessage = nil

        // Matches Flutter validation order exactly
        guard !otp.isEmpty else {
            sheetErrorMessage = "Please enter OTP"; return
        }
        guard otp.count >= 4 else {
            sheetErrorMessage = "Please enter valid OTP"; return
        }
        guard !newPassword.isEmpty else {
            sheetErrorMessage = "Please enter new password"; return
        }
        guard newPassword.range(of: passwordPattern, options: .regularExpression) != nil else {
            sheetErrorMessage = "Password must be at least 6 characters with uppercase, lowercase, number & special character (@#$%^&+=!)"
            return
        }
        guard newPassword == confirmPassword else {
            sheetErrorMessage = "Passwords do not match"; return
        }

        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                let hashedPass = sha512(newPassword)
                let r = try await api.verifyForgotPasswordOtp(
                    VerifyForgotPasswordOtpRequest(email: email, otp: otp, newPassword: hashedPass)
                )
                if r.success {
                    successMessage = r.message.isEmpty ? "Password reset successfully!" : r.message
                    step = .done
                    onSuccess()
                } else {
                    // Show attemptsLeft if present (matches Flutter attemptsLeft logic)
                    let attemptsMsg = r.attemptsLeft != nil ? " (\(r.attemptsLeft!) attempts left)" : ""
                    sheetErrorMessage = (r.message.isEmpty ? "Failed to reset password" : r.message) + attemptsMsg
                }
            } catch {
                sheetErrorMessage = networkMessage(error)
            }
        }
    }

    private func sha512(_ input: String) -> String {
        SHA512.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    private func networkMessage(_ error: Error) -> String {
        (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
}
