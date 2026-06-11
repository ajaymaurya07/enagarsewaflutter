import Foundation
import Contacts

@MainActor
final class SignUpViewModel: ObservableObject {

    @Published var name: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var detectedPhones: [String] = []
    @Published var detectedEmails: [String] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var otpRequired: Bool = false
    @Published var otpVerified: Bool = false
    @Published var otp: String = ""

    /// Full password regex — matches Flutter exactly:
    /// min 6 chars, uppercase, lowercase, digit, special (@#$%^&+=!), no whitespace
    private let passwordPattern = #"^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=!])(?=\S+$).{6,}$"#

    private let api = APIService.shared
    let onSignUpSuccess: () -> Void

    init(onSignUpSuccess: @escaping () -> Void) {
        self.onSignUpSuccess = onSignUpSuccess
    }

    // MARK: - Device contact prefill (iOS — Contacts framework, no SIM API)

    func loadDeviceContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else { return }
            let keys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var phones: Set<String> = []
            var emails: Set<String> = []
            try? store.enumerateContacts(with: request) { contact, _ in
                contact.phoneNumbers.forEach  { phones.insert($0.value.stringValue) }
                contact.emailAddresses.forEach { emails.insert($0.value as String) }
            }
            DispatchQueue.main.async {
                self.detectedPhones = Array(phones).prefix(5).map { $0 }
                self.detectedEmails = Array(emails).prefix(5).map { $0 }
            }
        }
    }

    // MARK: - Registration

    func register() {
        guard validate() else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let sanitized = sanitizePhone(phoneNumber)
                let response = try await api.signup(SignUpRequest(
                    name: name,
                    email: email,
                    password: password,
                    phoneNumber: sanitized,
                    deviceId: DeviceSecurityService.shared.deviceId,
                    fcmToken: UserDefaults.standard.fcmToken ?? ""
                ))
                if response.success {
                    otpRequired = true
                } else {
                    errorMessage = response.message.isEmpty
                        ? "Sign up failed. Please try again."
                        : response.message
                }
            } catch {
                errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - OTP verification

    func verifyOtp() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let response = try await api.verifyOtpEmail(
                    VerifyOtpMailRequest(email: email, otp: otp)
                )
                if response.success {
                    otpVerified = true
                    onSignUpSuccess()
                } else {
                    errorMessage = response.message.isEmpty
                        ? "OTP verification failed. Please try again."
                        : response.message
                }
            } catch {
                errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Validation (matches Flutter _handleSignUp order exactly)

    private func validate() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if trimmedName.isEmpty {
            errorMessage = "Please enter your name"; return false
        }
        if trimmedName.count < 3 {
            errorMessage = "Name must be at least 3 characters"; return false
        }
        if phoneNumber.isEmpty {
            errorMessage = "Please select a phone number"; return false
        }
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter email address"; return false
        }
        if !email.contains("@") {
            errorMessage = "Please enter a valid email address"; return false
        }
        if password.isEmpty {
            errorMessage = "Please enter password"; return false
        }
        if password.range(of: passwordPattern, options: .regularExpression) == nil {
            errorMessage = "Password must be at least 6 characters with uppercase, lowercase, number & special character (@#$%^&+=!)"
            return false
        }
        if password != confirmPassword {
            errorMessage = "Passwords do not match"; return false
        }
        return true
    }

    // MARK: - Phone sanitization (matches Flutter _sanitizePhone)
    /// Strips spaces, dashes, brackets; removes +91 / 91 prefix; keeps last 10 digits.
    private func sanitizePhone(_ phone: String) -> String {
        var cleaned = phone.components(separatedBy: CharacterSet(charactersIn: " -()")).joined()
        if cleaned.hasPrefix("+91") {
            cleaned = String(cleaned.dropFirst(3))
        } else if cleaned.hasPrefix("91") && cleaned.count > 10 {
            cleaned = String(cleaned.dropFirst(2))
        }
        if cleaned.count > 10 {
            cleaned = String(cleaned.suffix(10))
        }
        return cleaned
    }
}
