import UIKit

// MARK: - Result types (mirror Flutter sign_up_02.dart's control flow)

/// Outcome of `SignUp02ViewModel.submit(...)` — mirrors the branches walked in
/// Flutter's `_handleSubmit` / `_doSignUp`.
enum SignUp02SubmitResult {
    case validationFailed(String)
    case registrationFailed(String)
    /// Neither `mobile_otp_required` nor `email_otp_required` came back true.
    /// Flutter silently falls through in this case (no dialog) — replicated as-is.
    case noOtpRequired
    case mobileOtpRequired(message: String)
    case emailOtpRequired(message: String)
}

/// Normalized OTP-verification outcome — mirrors Flutter's private `_OtpResult`
/// (used for both the mobile OTP endpoint and the generic email OTP endpoint).
struct SignUp02OtpVerifyOutcome {
    let status: Bool
    let message: String?
    let registrationComplete: Bool
    let emailOtpRequired: Bool
}

@MainActor
final class SignUp02ViewModel: ObservableObject {

    // MARK: - Captcha state

    @Published var captchaId: String?
    @Published var captchaImage: UIImage?
    @Published var loadingCaptcha: Bool = false
    /// Bumped on every successful captcha load — the VC observes this (skipping the
    /// initial value) to clear the entered captcha text, matching Flutter's
    /// `_captchaController.clear()` inside `_fetchCaptcha`'s success branch.
    @Published private(set) var captchaRefreshTick: Int = 0

    // MARK: - ULB Type / City state

    let ulbTypes = ["Nagar Nigam", "Nagar Palika Parishad", "Nagar Panchayat"]
    let ulbTypeCodes: [String: String] = [
        "Nagar Nigam": "NN",
        "Nagar Palika Parishad": "NPP",
        "Nagar Panchayat": "NP",
    ]

    @Published var selectedUlbType: String?
    @Published var selectedCity: SignupCity?
    @Published var cities: [SignupCity] = []
    @Published var loadingCities: Bool = false

    // MARK: - Misc

    @Published var isLoading: Bool = false
    /// One-off, non-blocking errors (e.g. city-fetch failures) surfaced via a snackbar.
    @Published var errorMessage: String?

    /// Mobile/email used in the last submitted registration — needed by the
    /// chained OTP verification steps.
    private(set) var currentMobile: String = ""
    private(set) var currentEmail: String = ""

    private let api = APIService.shared

    /// Full password regex — matches Flutter exactly:
    /// min 6 chars, uppercase, lowercase, digit, special (@#$%^&+=!), no whitespace
    private let passwordPattern = #"^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=!])(?=\S+$).{6,}$"#

    // MARK: - Captcha

    func fetchCaptcha() async {
        loadingCaptcha = true
        do {
            let captcha = try await api.getSignupCaptcha()
            captchaId = captcha.captchaId
            captchaImage = UIImage(data: Data(base64Encoded: captcha.captchaImage) ?? Data())
            captchaRefreshTick += 1
        } catch {
            captchaId = nil
            captchaImage = nil
        }
        loadingCaptcha = false
    }

    // MARK: - ULB Type / City

    func selectUlbType(_ type: String) {
        selectedUlbType = type
        selectedCity = nil
        cities = []
        Task { await fetchCities(for: type) }
    }

    func fetchCities(for ulbType: String) async {
        guard let code = ulbTypeCodes[ulbType] else { return }
        loadingCities = true
        cities = []
        selectedCity = nil
        do {
            cities = try await api.getSignupCities(ulbType: code)
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription
                ?? "Unable to load cities. Please try again."
        }
        loadingCities = false
    }

    // MARK: - Registration (matches Flutter `_handleSubmit` → `_doSignUp` exactly)

    func submit(name: String,
                fatherHusbandName: String,
                address1: String,
                address2: String,
                mobileNo: String,
                email: String,
                password: String,
                confirmPassword: String,
                captchaText: String) async -> SignUp02SubmitResult {

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedFather = fatherHusbandName.trimmingCharacters(in: .whitespaces)
        let trimmedAddress1 = address1.trimmingCharacters(in: .whitespaces)
        let trimmedAddress2 = address2.trimmingCharacters(in: .whitespaces)
        let trimmedMobile = mobileNo.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedCaptcha = captchaText.trimmingCharacters(in: .whitespaces)

        // --- Form-field validators, in the same top-to-bottom order as the Flutter form ---
        if trimmedName.isEmpty { return .validationFailed("Name is required") }
        if trimmedFather.isEmpty { return .validationFailed("Father/Husband name is required") }
        if trimmedAddress1.isEmpty { return .validationFailed("Address 1 is required") }
        if trimmedAddress2.isEmpty { return .validationFailed("Address 2 is required") }
        if trimmedMobile.isEmpty { return .validationFailed("Mobile number is required") }
        if trimmedMobile.count != 10 { return .validationFailed("Mobile number must be 10 digits") }
        if password.isEmpty { return .validationFailed("Password is required") }
        if confirmPassword.isEmpty { return .validationFailed("Confirm Password is required") }
        if confirmPassword != password { return .validationFailed("Passwords do not match") }
        if trimmedCaptcha.isEmpty { return .validationFailed("Please enter the captcha text") }

        // --- Manual checks performed in `_handleSubmit` after `Form.validate()` passes ---
        guard let ulbType = selectedUlbType else { return .validationFailed("Please select ULB Type") }
        guard let city = selectedCity else { return .validationFailed("Please select City") }

        if password.range(of: passwordPattern, options: .regularExpression) == nil {
            return .validationFailed(
                "Password must be at least 6 characters with uppercase, lowercase, number & special character (@#$%^&+=!)"
            )
        }
        if password != confirmPassword {
            return .validationFailed("Passwords do not match")
        }
        guard let captchaId else {
            return .validationFailed("Please wait for captcha to load")
        }
        guard let ulbCode = ulbTypeCodes[ulbType] else {
            return .validationFailed("Please select ULB Type")
        }

        let encryptedPassword: String
        let encryptedConfirmPassword: String
        do {
            encryptedPassword = try RsaService.encrypt(password)
            encryptedConfirmPassword = try RsaService.encrypt(confirmPassword)
        } catch {
            return .registrationFailed("Unable to secure your password. Please try again.")
        }

        currentMobile = trimmedMobile
        currentEmail = trimmedEmail

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await api.registerCitizen(CitizenRegisterRequest(
                name: trimmedName,
                fatherHusbandName: trimmedFather,
                address1: trimmedAddress1,
                address2: trimmedAddress2,
                ulbType: ulbCode,
                city: city.id,
                mobileNo: trimmedMobile,
                email: trimmedEmail,
                encryptedPassword: encryptedPassword,
                encryptedConfirmPassword: encryptedConfirmPassword,
                captchaId: captchaId,
                captcha: trimmedCaptcha
            ))

            guard response.status == true else {
                await fetchCaptcha()
                return .registrationFailed(response.message ?? "Registration failed. Please try again.")
            }

            if response.mobileOtpRequired == true {
                return .mobileOtpRequired(message: response.message ?? "OTP sent to your mobile number")
            }
            if response.emailOtpRequired == true {
                return .emailOtpRequired(message: response.message ?? "OTP sent to your email")
            }
            return .noOtpRequired
        } catch {
            await fetchCaptcha()
            let message = (error as? NetworkError)?.errorDescription
                ?? "Unable to create account right now. Please try again."
            return .registrationFailed(message)
        }
    }

    // MARK: - OTP verification

    func verifyMobileOtp(otp: String) async throws -> SignUp02OtpVerifyOutcome {
        let response = try await api.verifyCitizenOtp(
            CitizenVerifyOtpRequest(mobileNo: currentMobile, otp: otp)
        )
        return SignUp02OtpVerifyOutcome(
            status: response.status ?? false,
            message: response.message,
            registrationComplete: response.registrationComplete ?? false,
            emailOtpRequired: response.emailOtpRequired ?? false
        )
    }

    func verifyEmailOtp(otp: String) async throws -> SignUp02OtpVerifyOutcome {
        let response = try await api.verifyOtpEmail(
            VerifyOtpMailRequest(email: currentEmail, otp: otp)
        )
        // Matches Flutter: a successful VerifyOtpMailResponse always completes registration.
        return SignUp02OtpVerifyOutcome(
            status: response.success,
            message: response.message,
            registrationComplete: true,
            emailOtpRequired: false
        )
    }
}
