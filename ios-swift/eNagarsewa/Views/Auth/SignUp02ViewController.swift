import UIKit

/// Port of lib/sign_up_02.dart — citizen self-registration ("Create Account").
final class SignUp02ViewController: BaseViewController {

    override var hidesNavigationBar: Bool { true }

    private lazy var flow = SignupOtpFlow(host: self)

    private let ulbTypes = ["Nagar Nigam", "Nagar Palika Parishad", "Nagar Panchayat"]
    private let ulbTypeCodes = ["Nagar Nigam": "NN", "Nagar Palika Parishad": "NPP", "Nagar Panchayat": "NP"]
    private var selectedUlbType: String?
    private var selectedCity: SignupCity?
    private var cities: [SignupCity] = []
    private var loadingCities = false

    private static let namePattern = "[a-zA-Z\\s\\.]"
    private static let unsafeChars = "[<>\"\\\\]"

    private lazy var nameField = makeField("Enter your full name", max: 100, allow: Self.namePattern) {
        $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Name is required" : nil
    }
    private lazy var fatherField = makeField("Enter father/husband name", max: 100, allow: Self.namePattern) {
        $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Father/Husband name is required" : nil
    }
    private lazy var address1Field = makeField("House No., Street, Locality", max: 100, deny: Self.unsafeChars) {
        $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Address 1 is required" : nil
    }
    private lazy var address2Field = makeField("Area, Landmark", max: 100, deny: Self.unsafeChars) {
        $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Address 2 is required" : nil
    }
    private lazy var mobileField: ENSTextField = {
        let f = makeField("Enter 10 digit mobile number", max: 10, keyboard: .numberPad, digits: true) { v in
            let t = v.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return "Mobile number is required" }
            return t.count != 10 ? "Mobile number must be 10 digits" : nil
        }
        return f
    }()
    private lazy var passwordField = makeField("Enter your password", max: 25, secure: true) {
        $0.isEmpty ? "Password is required" : nil
    }
    private lazy var confirmField = makeField("Re-enter your password", max: 25, secure: true) { [weak self] v in
        if v.isEmpty { return "Confirm Password is required" }
        return v != self?.passwordField.text ? "Passwords do not match" : nil
    }
    private lazy var emailField = makeField("Enter your email (optional)", max: 50, keyboard: .emailAddress,
                                            deny: Self.unsafeChars) { v in
        let t = v.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        return t.range(of: #"^[\w\.\-\+]+@[\w\-]+\.[a-zA-Z]{2,}$"#, options: .regularExpression) == nil
            ? "Please enter a valid email address" : nil
    }
    private lazy var captchaField = makeField("Enter image text", max: 10, allow: "[a-zA-Z0-9]") {
        $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Please enter the captcha text" : nil
    }
    private let ulbTypeField = SelectField(placeholder: "Select ULB Type")
    private let cityField = SelectField(placeholder: "Select City")
    private let captchaView = CaptchaView()
    private let createButton = PrimaryButton("Create Account")

    private func makeField(_ placeholder: String, max: Int, keyboard: UIKeyboardType = .default,
                           allow: String? = nil, deny: String? = nil, digits: Bool = false, secure: Bool = false,
                           validator: @escaping (String) -> String?) -> ENSTextField {
        var c = ENSTextField.Config()
        c.placeholder = placeholder
        c.maxLength = max
        c.keyboard = keyboard
        c.allow = allow
        c.deny = deny
        c.digitsOnly = digits
        c.isSecure = secure
        c.capitalization = (allow == Self.namePattern) ? .words : .none
        let f = ENSTextField(c)
        f.validator = validator
        return f
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        captchaView.onLoaded = { [weak self] in self?.captchaField.text = "" }
        Task { await captchaView.load() }
    }

    // MARK: - Layout

    private func buildUI() {
        let back = iconButton("chevron.backward", color: .appPrimary, size: 18) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        let header = UIStackView.h(4, [back, UILabel("Create Account", font: .poppins(18, .bold), color: .appTextDark), FlexSpacer()])
        view.addSubview(header)
        header.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ])

        let card = CardView(radius: 20, padding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
                            shadowOpacity: 0.06, shadowBlur: 20, shadowY: 8)
        let s = card.stack
        s.add(UILabel("Join eNagarSewa", font: .poppins(20, .bold), color: .appTextDark))
        s.addSpacer(4)
        s.add(UILabel("Create your account to get started", font: .poppins(13), color: .grey500))
        s.addSpacer(24)

        func section(_ label: UIView, _ field: UIView, gap: CGFloat = 20) {
            s.add(label)
            s.addSpacer(8)
            s.add(field)
            s.addSpacer(gap)
        }
        section(InfoLabel("Full Name", helpTitle: SignUpHelp.fullNameTitle, helpMessage: SignUpHelp.fullNameMessage), nameField)
        section(InfoLabel("Father/Husband Name", helpTitle: "Father/Husband Name",
                          helpMessage: "Enter the name of your father or husband as per official records."), fatherField)
        section(InfoLabel("Address 1", helpTitle: "Address Line 1",
                          helpMessage: "Enter your primary address (House No., Street, Locality)."), address1Field)
        section(InfoLabel("Address 2", helpTitle: "Address Line 2",
                          helpMessage: "Enter additional address details (Area, Landmark, etc.)."), address2Field)
        section(InfoLabel("ULB Type", helpTitle: "ULB Type",
                          helpMessage: "Select the type of Urban Local Body (Nagar Nigam, Nagar Palika Parishad, or Nagar Panchayat)."), ulbTypeField)
        section(InfoLabel("City", helpTitle: "City",
                          helpMessage: "Select your city. You will only be able to avail services of the selected city."), cityField)
        section(InfoLabel("Mobile No.", helpTitle: SignUpHelp.phoneTitle, helpMessage: SignUpHelp.phoneMessage), mobileField)
        section(InfoLabel("Password", helpTitle: SignUpHelp.passwordTitle, helpMessage: SignUpHelp.passwordMessage), passwordField)
        section(InfoLabel("Confirm Password", helpTitle: SignUpHelp.confirmPasswordTitle,
                          helpMessage: SignUpHelp.confirmPasswordMessage), confirmField)
        section(InfoLabel("Email ID (Optional)", helpTitle: SignUpHelp.emailTitle, helpMessage: SignUpHelp.emailMessage), emailField)
        section(InfoLabel("Captcha", helpTitle: "Captcha",
                          helpMessage: "Enter the text shown in the image to verify you are not a robot."), captchaView, gap: 12)
        s.add(captchaField)
        s.addSpacer(28)
        s.add(createButton)
        s.addSpacer(16)

        let verifyText = NSMutableAttributedString(
            string: "Already registered? Verify your mobile number and email ID. ",
            attributes: [.font: UIFont.poppins(13), .foregroundColor: UIColor.grey600])
        verifyText.append(NSAttributedString(string: "Click here.", attributes: [
            .font: UIFont.poppins(13, .bold), .foregroundColor: UIColor.appPrimary]))
        let verifyLabel = UILabel()
        verifyLabel.attributedText = verifyText
        verifyLabel.numberOfLines = 0
        verifyLabel.textAlignment = .center
        verifyLabel.onTap { [weak self] in
            guard let self else { return }
            self.push(SignUpVerifyViewController(initialMobile: self.mobileField.trimmedText,
                                                 email: self.emailField.trimmedText))
        }
        s.add(verifyLabel)

        let loginRow = UIStackView.h(0, [
            UILabel("Already have an account? ", font: .poppins(14), color: .grey600),
            textButton("Login", size: 14, weight: .bold) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            },
        ])

        installScrollStack(insets: UIEdgeInsets(top: 8, left: 8, bottom: 32, right: 8), below: header)
        contentStack.add(card)
        contentStack.addSpacer(24)
        contentStack.add(centered(loginRow))

        ulbTypeField.onTap = { [weak self] in self?.showUlbTypeSheet() }
        cityField.onTap = { [weak self] in self?.showCitySheet() }
        cityField.loadingText = "Loading cities..."
        createButton.onEvent { [weak self] in self?.handleSubmit() }
    }

    // MARK: - ULB type / city

    private func showUlbTypeSheet() {
        OptionPickerSheet.present(on: self, title: "Select ULB Type", options: ulbTypes,
                                  selected: selectedUlbType.flatMap(ulbTypes.firstIndex(of:))) { [weak self] i in
            guard let self else { return }
            self.selectedUlbType = self.ulbTypes[i]
            self.ulbTypeField.value = self.ulbTypes[i]
            self.selectedCity = nil
            self.cityField.value = nil
            self.cities = []
            Task { await self.fetchCities(self.ulbTypes[i]) }
        }
    }

    private func fetchCities(_ ulbType: String) async {
        guard let code = ulbTypeCodes[ulbType] else { return }
        loadingCities = true
        cityField.isLoading = true
        cities = []
        selectedCity = nil
        do {
            cities = try await APIService.shared.getSignupCities(ulbTypeCode: code)
        } catch {
            snack(APIError.userMessage(error, fallback: "Unable to load cities. Please try again."), .error)
        }
        loadingCities = false
        cityField.isLoading = false
    }

    private func showCitySheet() {
        guard selectedUlbType != nil else { snack("Please select ULB Type first", .error); return }
        guard !loadingCities else { snack("Loading cities, please wait...", .error); return }
        guard !cities.isEmpty else { snack("No cities available for selected ULB Type", .error); return }
        OptionPickerSheet.present(on: self, title: "Select City", options: cities.map(\.name),
                                  selected: selectedCity.flatMap { c in cities.firstIndex { $0.id == c.id } },
                                  searchable: true) { [weak self] i in
            guard let self else { return }
            self.selectedCity = self.cities[i]
            self.cityField.value = self.cities[i].name
        }
    }

    // MARK: - Submit

    private func handleSubmit() {
        let fields = [nameField, fatherField, address1Field, address2Field, mobileField,
                      passwordField, confirmField, emailField, captchaField]
        let results = fields.map { $0.validate() }
        guard !results.contains(false) else { return }

        let password = passwordField.text
        let confirm = confirmField.text
        guard let ulbType = selectedUlbType else { snack("Please select ULB Type", .error); return }
        guard let city = selectedCity else { snack("Please select City", .error); return }
        guard password.range(of: #"^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=!])(?=\S+$).{6,}$"#,
                             options: .regularExpression) != nil else {
            snack("Password must be at least 6 characters with uppercase, lowercase, number & special character (@#$%^&+=!)", .error)
            return
        }
        guard password == confirm else { snack("Passwords do not match", .error); return }
        guard let captchaId = captchaView.captchaId else { snack("Please wait for captcha to load", .error); return }

        let encrypted: String, encryptedConfirm: String
        do {
            encrypted = try RsaService.encrypt(password)
            encryptedConfirm = try RsaService.encrypt(confirm)
        } catch {
            snack("Unable to create account right now. Please try again.", .error)
            return
        }
        Task {
            await doSignUp(ulbTypeCode: ulbTypeCodes[ulbType] ?? "", city: city.id, captchaId: captchaId,
                           encryptedPassword: encrypted, encryptedConfirmPassword: encryptedConfirm)
        }
    }

    private func doSignUp(ulbTypeCode: String, city: Int, captchaId: String,
                          encryptedPassword: String, encryptedConfirmPassword: String) async {
        let mobile = mobileField.trimmedText
        let email = emailField.trimmedText
        createButton.isLoading = true
        do {
            let result = try await APIService.shared.registerCitizen(
                name: nameField.trimmedText, fatherHusbandName: fatherField.trimmedText,
                address1: address1Field.trimmedText, address2: address2Field.trimmedText,
                ulbType: ulbTypeCode, city: city, mobileNo: mobile, email: email,
                encryptedPassword: encryptedPassword, encryptedConfirmPassword: encryptedConfirmPassword,
                captchaId: captchaId, captcha: captchaField.trimmedText)
            createButton.isLoading = false

            if result.responseCode == 0 {
                Task { await captchaView.load() }
                let message = result.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                flow.showMessageDialog(title: "Registration Failed",
                                       message: message.isEmpty ? "Registration failed. Please try again." : result.message!)
                return
            }
            guard result.status == true else {
                Task { await captchaView.load() }
                flow.showMessageDialog(title: "Registration Failed",
                                       message: result.message ?? "Registration failed. Please try again.")
                return
            }

            var needEmailOtp = result.emailOtpRequired == true
            var nextMessage = result.message

            if result.mobileOtpRequired == true {
                guard let mobileResult = await flow.showOtpBottomSheet(
                    title: "Verify Mobile OTP", subtitle: result.message ?? "OTP sent to your mobile number",
                    highlightText: mobile, mobileNo: mobile,
                    onVerify: { otp in SignupOtpVerifyOutcome(try await APIService.shared.verifyCitizenOtp(mobileNo: mobile, otp: otp)) }
                ) else { return }
                if mobileResult.registrationComplete {
                    flow.showSuccessAndGoBack(mobileResult.message ?? "Registration complete!")
                    return
                }
                needEmailOtp = mobileResult.emailOtpRequired
                nextMessage = mobileResult.message
            }

            if needEmailOtp {
                guard let emailResult = await flow.showOtpBottomSheet(
                    title: "Verify Email OTP", subtitle: nextMessage ?? "OTP sent to your email",
                    highlightText: email, mobileNo: mobile,
                    onVerify: { otp in SignupOtpVerifyOutcome(try await APIService.shared.verifyOtpEmail(email: email, otp: otp)) }
                ) else { return }
                flow.showSuccessAndGoBack(emailResult.message ?? "Registration complete!")
            }
        } catch {
            createButton.isLoading = false
            Task { await captchaView.load() }
            flow.showMessageDialog(title: "Error", message: APIError.userMessage(
                error, fallback: "Unable to create account right now. Please try again."))
        }
    }
}

/// Port of lib/sign_up_verify_screen.dart — confirm mobile + captcha to resend the
/// registration OTPs, then run the same mobile → email OTP sequence.
final class SignUpVerifyViewController: BaseViewController {

    private let initialMobile: String
    private let email: String
    private let initialMessage: String?
    private lazy var flow = SignupOtpFlow(host: self)

    private let mobileField: ENSTextField = {
        var c = ENSTextField.Config()
        c.placeholder = "Enter 10 digit mobile number"
        c.maxLength = 10
        c.keyboard = .numberPad
        c.digitsOnly = true
        return ENSTextField(c)
    }()
    private let captchaField: ENSTextField = {
        var c = ENSTextField.Config()
        c.placeholder = "Enter image text"
        c.maxLength = 10
        c.allow = "[a-zA-Z0-9]"
        return ENSTextField(c)
    }()
    private let captchaView = CaptchaView(refreshIconSize: 24)
    private let errorLabel = UILabel(nil, font: .poppins(12, .medium), color: .mRed600, lines: 0)
    private let submitButton = PrimaryButton("Submit", radius: 12, weight: .semibold)

    init(initialMobile: String, email: String, initialMessage: String? = nil) {
        self.initialMobile = initialMobile
        self.email = email
        self.initialMessage = initialMessage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Verify Mobile Number", titleSize: 16, titleWeight: .semibold)
        mobileField.text = initialMobile
        setError(initialMessage)

        installScrollStack(insets: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24))
        let s = contentStack
        s.alignment = .fill
        s.add(UIStackView.h(0, [UIImageView(symbol: "lock.shield", size: 40, color: .appPrimary), FlexSpacer()]))
        s.addSpacer(16)
        s.add(UILabel("Confirm your mobile number and fill the captcha below to continue.",
                      font: .poppins(13), color: .grey600, lines: 0))
        s.addSpacer(24)
        s.add(fieldLabel("Mobile No.", color: .black87))
        s.addSpacer(8)
        s.add(mobileField)
        s.addSpacer(16)
        s.add(fieldLabel("Captcha", color: .black87))
        s.addSpacer(8)
        s.add(captchaView)
        s.addSpacer(12)
        s.add(captchaField)
        s.addSpacer(8)
        s.add(errorLabel)
        s.addSpacer(28)
        s.add(submitButton)

        captchaView.onLoaded = { [weak self] in self?.captchaField.text = "" }
        submitButton.onEvent { [weak self] in self?.submit() }
        Task { await captchaView.load() }
    }

    private func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
    }

    private func reloadCaptcha() {
        captchaField.text = ""
        Task { await captchaView.load() }
    }

    private func submit() {
        let mobile = mobileField.trimmedText
        guard mobile.count == 10 else { setError("Please enter a valid 10 digit mobile number"); return }
        let captcha = captchaField.trimmedText
        guard !captcha.isEmpty else { setError("Please enter the captcha text"); return }
        guard let captchaId = captchaView.captchaId else { return }

        submitButton.isLoading = true
        mobileField.isEnabled = false
        captchaField.isEnabled = false
        setError(nil)
        Task {
            defer {
                submitButton.isLoading = false
                mobileField.isEnabled = true
                captchaField.isEnabled = true
            }
            do {
                let result = try await APIService.shared.resendSignupOtp(mobileNo: mobile, captchaId: captchaId, captcha: captcha)
                if result.responseCode == 9 {
                    setError(result.message ?? "Invalid captcha. Please try again.")
                    reloadCaptcha()
                    return
                }
                guard result.status == true else {
                    reloadCaptcha()
                    flow.showMessageDialog(title: "Registration Failed",
                                           message: result.message ?? "Registration failed. Please try again.")
                    return
                }
                submitButton.isLoading = false
                await handleOtpSequence(mobile: mobile, mobileOtpSent: result.mobileOtpSent == true,
                                        emailOtpSent: result.emailOtpSent == true, message: result.message)
            } catch {
                reloadCaptcha()
                flow.showMessageDialog(title: "Error", message: APIError.userMessage(
                    error, fallback: "Unable to resend OTP right now. Please try again."))
            }
        }
    }

    private func handleOtpSequence(mobile: String, mobileOtpSent: Bool, emailOtpSent: Bool, message: String?) async {
        if mobileOtpSent {
            guard let mobileResult = await flow.showOtpBottomSheet(
                title: "Verify Mobile OTP", subtitle: message ?? "OTP sent to your mobile number",
                highlightText: mobile, mobileNo: mobile,
                onVerify: { otp in SignupOtpVerifyOutcome(try await APIService.shared.verifyCitizenOtp(mobileNo: mobile, otp: otp)) }
            ) else { return }
            if !emailOtpSent {
                flow.showSuccessAndGoBack(mobileResult.message ?? "Registration complete!")
                return
            }
        }
        if emailOtpSent {
            let email = self.email
            guard let emailResult = await flow.showOtpBottomSheet(
                title: "Verify Email OTP", subtitle: "OTP sent to your email", highlightText: email, mobileNo: mobile,
                onVerify: { otp in SignupOtpVerifyOutcome(try await APIService.shared.verifyOtpEmail(email: email, otp: otp)) }
            ) else { return }
            flow.showSuccessAndGoBack(emailResult.message ?? "Registration Successful", title: "Registration Successful")
            return
        }
        flow.showSuccessAndGoBack(message ?? "Registration Successful", title: "Registration Successful")
    }
}

/// lib/help/signup_help.dart
enum SignUpHelp {
    static let fullNameTitle = "Full Name"
    static let fullNameMessage = "Enter your full name as it appears on official documents.\nExample: Rajesh Kumar Sharma\n\nThis name will be used on your account profile."
    static let phoneTitle = "Phone Number"
    static let phoneMessage = "Enter your 10-digit mobile number.\nExample: 9876543210"
    static let emailTitle = "Email ID"
    static let emailMessage = "Enter a valid email address.\nExample: name@example.com\n\nAn OTP will be sent to this email to verify your account."
    static let passwordTitle = "Password"
    static let passwordMessage = "Create a strong password with at least 6 characters.\n\nYour password must include:\n• At least one uppercase letter (A–Z)\n• At least one lowercase letter (a–z)\n• At least one number (0–9)\n• At least one special character (@#$%^&+=!)"
    static let confirmPasswordTitle = "Confirm Password"
    static let confirmPasswordMessage = "Re-enter the same password you entered above.\n\nBoth passwords must match to proceed."
}
