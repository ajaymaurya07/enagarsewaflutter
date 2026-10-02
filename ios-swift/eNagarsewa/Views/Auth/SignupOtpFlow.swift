import UIKit

/// Result of a verified OTP step (Dart `OtpResult`).
struct SignupOtpResult {
    let message: String?
    let registrationComplete: Bool
    let emailOtpRequired: Bool
}

/// Outcome normalised from either `CitizenVerifyOtpResponse` or `VerifyOtpMailResponse`.
struct SignupOtpVerifyOutcome {
    let status: Bool?
    let message: String?
    let registrationComplete: Bool?
    let emailOtpRequired: Bool?

    init(_ r: CitizenVerifyOtpResponse) {
        status = r.status
        message = r.message
        registrationComplete = r.registrationComplete
        emailOtpRequired = r.emailOtpRequired
    }

    /// Email verification always completes registration.
    init(_ r: VerifyOtpMailResponse) {
        status = r.status
        message = r.message
        registrationComplete = true
        emailOtpRequired = false
    }
}

// MARK: - Captcha image + refresh (the captcha `Row` used on all sign-up surfaces)

final class CaptchaView: UIView {

    private let imageBox = UIView()
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let failedLabel = UILabel("Failed", font: .poppins(12), color: .mRed400, alignment: .center)
    private let refreshButton: UIButton
    private var widthConstraint: NSLayoutConstraint!

    private(set) var captchaId: String?
    private(set) var isLoading = false
    var onLoaded: (() -> Void)?

    init(refreshIconSize: CGFloat = 26) {
        refreshButton = UIButton(type: .system)
        super.init(frame: .zero)
        refreshButton.setImage(.symbol("arrow.clockwise", size: refreshIconSize * 0.8, weight: .semibold), for: .normal)
        refreshButton.tintColor = .appPrimary
        refreshButton.setSize(width: 44, height: 44)
        refreshButton.onEvent { [weak self] in Task { await self?.load() } }

        imageBox.backgroundColor = .appFieldFill
        imageBox.layer.cornerRadius = 12
        imageBox.layer.borderWidth = 1
        imageBox.layer.borderColor = UIColor.grey200.cgColor
        imageBox.clipsToBounds = true
        imageBox.setSize(height: 50)
        widthConstraint = imageBox.widthAnchor.constraint(equalToConstant: 120)
        widthConstraint.isActive = true
        imageView.contentMode = .scaleAspectFit
        spinner.color = .appPrimary
        spinner.hidesWhenStopped = true
        [imageView, spinner, failedLabel].forEach { imageBox.addSubview($0) }
        imageView.pinToEdges(of: imageBox)
        spinner.center(in: imageBox)
        failedLabel.center(in: imageBox)
        failedLabel.isHidden = true

        let row = UIStackView.h(12, [imageBox, refreshButton, FlexSpacer()])
        addSubview(row)
        row.pinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// `getSignupCaptcha` → shows the base64 image; failure shows "Failed".
    func load() async {
        isLoading = true
        refreshButton.isEnabled = false
        imageView.image = nil
        failedLabel.isHidden = true
        widthConstraint.constant = 120
        spinner.startAnimating()
        defer {
            isLoading = false
            refreshButton.isEnabled = true
            spinner.stopAnimating()
        }
        do {
            let captcha = try await APIService.shared.getSignupCaptcha()
            let base64 = captcha.captchaImage.components(separatedBy: ",").last ?? captcha.captchaImage
            if let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters), let image = UIImage(data: data) {
                captchaId = captcha.captchaId
                imageView.image = image
                // `Image.memory(height: 50, fit: contain)` sizes the box to the image's aspect.
                widthConstraint.constant = min(220, max(80, 50 * image.size.width / max(image.size.height, 1)))
                onLoaded?()
            } else {
                captchaId = nil
                failedLabel.isHidden = false
            }
        } catch {
            captchaId = nil
            failedLabel.isHidden = false
        }
    }
}

// MARK: - Shared flow (Dart `SignupOtpFlowMixin`)

@MainActor
final class SignupOtpFlow {

    private weak var host: UIViewController?

    init(host: UIViewController) { self.host = host }

    private func captchaField() -> ENSTextField {
        var c = ENSTextField.Config()
        c.placeholder = "Enter image text"
        c.maxLength = 10
        c.allow = "[a-zA-Z0-9]"
        return ENSTextField(c)
    }

    /// Captcha-challenge dialog → (captchaId, captcha) or nil when cancelled.
    func showCaptchaChallengeDialog(errorMessage: String?) async -> (captchaId: String, captcha: String)? {
        guard let host else { return nil }
        let captcha = CaptchaView(refreshIconSize: 24)
        let field = captchaField()
        let error = UILabel(errorMessage, font: .poppins(12, .medium), color: .mRed600, lines: 0)
        error.isHidden = errorMessage == nil
        let intro = UILabel("Please fill the captcha shown below to continue.", font: .poppins(13), color: .grey600, lines: 0)
        let content = UIStackView.v(12, [intro, captcha, field, error])
        content.setCustomSpacing(16, after: intro)
        content.setCustomSpacing(4, after: field)

        return await withCheckedContinuation { continuation in
            var finished = false
            func finish(_ value: (String, String)?) {
                guard !finished else { return }
                finished = true
                continuation.resume(returning: value)
            }
            let submit = PrimaryButton("Submit", height: 40, radius: 10, fontSize: 14, weight: .semibold)
            submit.contentEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
            submit.isEnabled = false
            captcha.onLoaded = { submit.isEnabled = true }
            let cancel = textButton("Cancel", color: .grey600, size: 14) {}
            let actions = UIStackView.h(8, [FlexSpacer(), cancel, submit])
            content.addArrangedSubview(actions)
            content.setCustomSpacing(20, after: error)

            let dialog = AppDialog.show(on: host, icon: "lock.shield", iconColor: .appPrimary, title: "Captcha Required",
                                        content: content, actions: [], dismissible: false)
            cancel.onEvent { dialog.close { finish(nil) } }
            submit.onEvent {
                let text = field.trimmedText
                guard let id = captcha.captchaId, !captcha.isLoading else { return }
                if text.isEmpty {
                    error.text = "Please enter the captcha text"
                    error.isHidden = false
                    return
                }
                dialog.close { finish((id, text)) }
            }
            Task { await captcha.load() }
        }
    }

    /// Repeats the captcha dialog while the API keeps answering responseCode 9.
    func promptCaptchaLoop<R>(call: (String, String) async throws -> R, responseCode: (R) -> Int?,
                              message: (R) -> String?, initialError: String? = nil) async throws -> R? {
        var error = initialError
        while true {
            guard let entry = await showCaptchaChallengeDialog(errorMessage: error) else { return nil }
            let result = try await call(entry.captchaId, entry.captcha)
            if responseCode(result) == 9 {
                error = message(result) ?? "Invalid captcha. Please try again."
                continue
            }
            return result
        }
    }

    /// Mobile / email OTP bottom sheet. Returns nil when the user cancels.
    func showOtpBottomSheet(title: String, subtitle: String, highlightText: String, mobileNo: String,
                            onVerify: @escaping (String) async throws -> SignupOtpVerifyOutcome) async -> SignupOtpResult? {
        guard let host else { return nil }
        return await withCheckedContinuation { continuation in
            let sheet = SignupOtpSheet(title: title, subtitle: subtitle, highlightText: highlightText,
                                       mobileNo: mobileNo, flow: self, onVerify: onVerify) { result in
                continuation.resume(returning: result)
            }
            host.topPresented.present(sheet, animated: true)
        }
    }

    func showMessageDialog(title: String, message: String, icon: String = "exclamationmark.circle",
                           iconColor: UIColor = .mRed600) {
        guard let host else { return }
        AppDialog.show(on: host, icon: icon, iconColor: iconColor, iconSize: 28, title: title, message: message,
                       actions: [.init(title: "OK")])
    }

    /// "Registration complete" dialog; OK pops the hosting screen.
    func showSuccessAndGoBack(_ message: String, title: String = "Registration Complete") {
        guard let host else { return }
        AppDialog.show(on: host, icon: "checkmark.circle.fill", iconColor: .mGreen, iconSize: 28, title: title,
                       message: message, actions: [.init(title: "OK", handler: { [weak host] in
                           host?.navigationController?.popViewController(animated: true)
                       })], dismissible: false)
    }
}

/// The OTP bottom sheet body from `showOtpBottomSheet`.
private final class SignupOtpSheet: BottomSheetController {

    private let titleText: String
    private let subtitle: String
    private let highlightText: String
    private let mobileNo: String
    private weak var flow: SignupOtpFlow?
    private let onVerify: (String) async throws -> SignupOtpVerifyOutcome
    private var completion: ((SignupOtpResult?) -> Void)?

    private let otpField: ENSTextField = {
        var c = ENSTextField.Config()
        c.placeholder = "------"
        c.keyboard = .numberPad
        c.maxLength = 6
        c.digitsOnly = true
        c.fontSize = 20
        c.textAlignment = .center
        return ENSTextField(c)
    }()
    private let errorLabel = UILabel(nil, font: .poppins(12, .medium), color: .mRed600, lines: 0)
    private let verifyButton = PrimaryButton("Verify OTP", radius: 12, weight: .semibold)
    private let cancelButton = OutlineButton("Cancel")
    private let resendButton = UIButton(type: .system)
    private let resendSpinner = UIActivityIndicatorView(style: .medium)

    init(title: String, subtitle: String, highlightText: String, mobileNo: String, flow: SignupOtpFlow,
         onVerify: @escaping (String) async throws -> SignupOtpVerifyOutcome,
         completion: @escaping (SignupOtpResult?) -> Void) {
        self.titleText = title
        self.subtitle = subtitle
        self.highlightText = highlightText
        self.mobileNo = mobileNo
        self.flow = flow
        self.onVerify = onVerify
        self.completion = completion
        super.init()
        isDismissible = false
        contentInsets = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func buildContent() {
        otpField.textField?.defaultTextAttributes[.kern] = 6
        contentStack.add(UILabel(titleText, font: .poppins(18, .bold), color: .black87))
        contentStack.addSpacer(16)
        contentStack.add(UILabel(subtitle, font: .poppins(13), color: .grey600, lines: 0))
        contentStack.addSpacer(4)
        contentStack.add(UILabel(highlightText, font: .poppins(13, .semibold), color: .appPrimary, lines: 0))
        contentStack.addSpacer(24)
        contentStack.add(otpField)
        errorLabel.isHidden = true
        contentStack.add(errorLabel)
        contentStack.setCustomSpacing(8, after: otpField)
        contentStack.addSpacer(28)
        contentStack.add(verifyButton)
        contentStack.addSpacer(12)
        contentStack.add(cancelButton)
        contentStack.addSpacer(12)

        resendButton.setTitle("Didn't receive OTP? Resend", for: .normal)
        resendButton.setTitleColor(.appPrimary, for: .normal)
        resendButton.titleLabel?.font = .poppins(13, .semibold)
        resendSpinner.color = .grey500
        resendSpinner.hidesWhenStopped = true
        let resendRow = UIView()
        resendRow.addSubview(resendButton)
        resendRow.addSubview(resendSpinner)
        resendButton.center(in: resendRow)
        resendSpinner.center(in: resendRow)
        resendRow.setSize(height: 40)
        contentStack.add(resendRow)
        contentStack.addSpacer(16)

        verifyButton.onEvent { [weak self] in self?.verify() }
        cancelButton.onEvent { [weak self] in self?.finish(nil) }
        resendButton.onEvent { [weak self] in self?.resend() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = otpField.becomeFirstResponder()
    }

    private func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
    }

    private func setVerifying(_ verifying: Bool) {
        verifyButton.isLoading = verifying
        otpField.isEnabled = !verifying
        cancelButton.isEnabled = !verifying
        resendButton.isEnabled = !verifying
    }

    private func finish(_ result: SignupOtpResult?) {
        let done = completion
        completion = nil
        close { done?(result) }
    }

    private func verify() {
        let otp = otpField.trimmedText
        guard !otp.isEmpty else { setError("Please enter OTP"); return }
        setError(nil)
        setVerifying(true)
        Task {
            do {
                let outcome = try await onVerify(otp)
                if outcome.status == true {
                    finish(SignupOtpResult(message: outcome.message,
                                           registrationComplete: outcome.registrationComplete ?? false,
                                           emailOtpRequired: outcome.emailOtpRequired ?? false))
                    return
                }
                setVerifying(false)
                setError(outcome.message ?? "OTP verification failed.")
            } catch {
                setVerifying(false)
                setError(APIError.userMessage(error, fallback: "Unable to verify OTP."))
            }
        }
    }

    private func resend() {
        guard let flow else { return }
        resendButton.isHidden = true
        resendSpinner.startAnimating()
        verifyButton.isEnabled = false
        setError(nil)
        let mobile = mobileNo
        Task {
            let result = try? await flow.promptCaptchaLoop(
                call: { id, captcha in
                    try await APIService.shared.resendSignupOtp(mobileNo: mobile, captchaId: id, captcha: captcha)
                },
                responseCode: { $0.responseCode }, message: { $0.message })
            resendButton.isHidden = false
            resendSpinner.stopAnimating()
            verifyButton.isEnabled = true
            guard let result else { return }
            if result.status != true {
                setError(result.message ?? "Unable to resend OTP. Please try again.")
                return
            }
            Snackbar.show(result.message ?? "OTP resent successfully", style: .success)
        }
    }
}
