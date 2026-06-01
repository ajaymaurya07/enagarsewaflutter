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
    @Published var otp: String = ""

    private let api = APIService.shared
    let onSignUpSuccess: () -> Void

    init(onSignUpSuccess: @escaping () -> Void) {
        self.onSignUpSuccess = onSignUpSuccess
    }

    // MARK: - Device contact prefill

    func loadDeviceContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else { return }
            let keys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var phones: Set<String> = []
            var emails: Set<String> = []
            try? store.enumerateContacts(with: request) { contact, _ in
                contact.phoneNumbers.forEach { phones.insert($0.value.stringValue) }
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
        isLoading = true; errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let response = try await api.signup(SignUpRequest(
                    name: name,
                    email: email,
                    password: password,
                    phoneNumber: phoneNumber,
                    deviceId: DeviceSecurityService.shared.deviceId,
                    fcmToken: UserDefaults.standard.fcmToken ?? ""
                ))
                if response.success {
                    otpRequired = true
                } else {
                    errorMessage = response.message
                }
            } catch {
                errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func verifyOtp() {
        isLoading = true; errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let response = try await api.verifyOtpEmail(
                    VerifyOtpMailRequest(email: email, otp: otp)
                )
                if response.success {
                    onSignUpSuccess()
                } else {
                    errorMessage = response.message
                }
            } catch {
                errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Validation

    private func validate() -> Bool {
        if name.trimmingCharacters(in: .whitespaces).isEmpty   { errorMessage = "Name is required."; return false }
        if email.trimmingCharacters(in: .whitespaces).isEmpty  { errorMessage = "Email is required."; return false }
        if phoneNumber.isEmpty                                  { errorMessage = "Phone number is required."; return false }
        if password.count < 6                                   { errorMessage = "Password must be at least 6 characters."; return false }
        if password != confirmPassword                          { errorMessage = "Passwords do not match."; return false }
        return true
    }
}
