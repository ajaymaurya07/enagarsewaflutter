import UIKit

/// Port of lib/otp_login_screen.dart.
/// Step 1: enter mobile number → send OTP. Step 2: 6-digit OTP with a resend countdown driven
/// entirely by the API's `expiresInSeconds`. Success → Search Property.
final class OtpLoginViewController: BaseViewController {

    override var hidesNavigationBar: Bool { true }
    override var screenBackground: UIColor { .appFieldFill }

    private enum Step { case mobileEntry, otpEntry }
    private var step = Step.mobileEntry

    private let cardStack = UIStackView.v(0, [])
    private let signUpRow = UIView()

    private lazy var mobileField: ENSTextField = {
        var c = ENSTextField.Config()
        c.placeholder = "Enter 10-digit mobile number"
        c.icon = "iphone"
        c.keyboard = .phonePad
        c.maxLength = 10
        c.digitsOnly = true
        c.fontSize = 15
        let f = ENSTextField(c)
        f.onSubmit = { [weak self] in self?.handleSendOtp() }
        return f
    }()

    private let sendButton = PrimaryButton("Send OTP")
    private let verifyButton = PrimaryButton("Verify OTP")
    private let otpBoxes = OtpBoxesView(count: 6)
    private let otpSentLabel = UILabel(nil, font: .poppins(13), color: .grey500, lines: 0)
    private let otpErrorLabel = UILabel(nil, font: .poppins(12), color: .mRed600, lines: 0)
    private let resendContainer = UIView()
    private var changeButton: UIButton!

    private var maskedMobile: String?
    private var isResending = false
    private var timer: Timer?
    private var secondsRemaining = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        renderStep(animated: false)
        sendButton.onEvent { [weak self] in self?.handleSendOtp() }
        verifyButton.onEvent { [weak self] in self?.handleVerifyOtp() }
        otpBoxes.onChange = { [weak self] _ in self?.setOtpError(nil) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if step == .mobileEntry { _ = mobileField.becomeFirstResponder() }
    }

    deinit { timer?.invalidate() }

    // MARK: - Layout

    private func buildUI() {
        let logo = UIImageView(image: UIImage(named: "AppLogo"))
        logo.contentMode = .scaleAspectFit
        logo.setSize(width: 130, height: 130)

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 20
        card.addSubview(cardStack)
        cardStack.pinToEdges(of: card, insets: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24))

        let prompt = UILabel("Don't have an account? ", font: .poppins(14), color: .grey600)
        let signUp = textButton("Sign Up", size: 14, weight: .bold) { [weak self] in
            self?.push(SignUp02ViewController())
        }
        let row = UIStackView.h(0, [prompt, signUp])
        signUpRow.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: signUpRow.topAnchor, constant: 20),
            row.bottomAnchor.constraint(equalTo: signUpRow.bottomAnchor),
            row.centerXAnchor.constraint(equalTo: signUpRow.centerXAnchor),
        ])

        installScrollStack(insets: UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16))
        contentStack.alignment = .fill
        contentStack.add(centered(logo))
        contentStack.addSpacer(28)
        contentStack.add(card, signUpRow)
        contentStack.addSpacer(24)

        // Vertically centre the column when it is shorter than the screen (Flutter `Center`).
        let minHeight = contentStack.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor, constant: -48)
        minHeight.isActive = true
        contentStack.distribution = .fill
        let topSpacer = FlexSpacer(), bottomSpacer = FlexSpacer()
        contentStack.insertArrangedSubview(topSpacer, at: 0)
        contentStack.addArrangedSubview(bottomSpacer)
        topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor).isActive = true

        otpErrorLabel.isHidden = true
        changeButton = textButton("Change", size: 12) { [weak self] in self?.handleChangeNumber() }
    }

    private func renderStep(animated: Bool) {
        cardStack.removeAllArranged()
        if step == .mobileEntry {
            cardStack.add(UILabel("Login with OTP", font: .poppins(22, .bold), color: .appTextDark))
            cardStack.addSpacer(4)
            cardStack.add(UILabel("Enter your registered mobile number to receive an OTP", font: .poppins(13), color: .grey500, lines: 0))
            cardStack.addSpacer(28)
            cardStack.add(fieldLabel("Mobile Number"))
            cardStack.addSpacer(8)
            cardStack.add(mobileField)
            cardStack.addSpacer(24)
            cardStack.add(sendButton)
            signUpRow.isHidden = false
        } else {
            cardStack.add(UILabel("Verify OTP", font: .poppins(22, .bold), color: .appTextDark))
            cardStack.addSpacer(4)
            otpSentLabel.text = "OTP sent to \(maskedMobile ?? mobileField.trimmedText)"
            cardStack.add(UIStackView.h(8, [otpSentLabel, changeButton]))
            cardStack.addSpacer(24)
            cardStack.add(otpBoxes)
            cardStack.add(otpErrorLabel)
            cardStack.addSpacer(18)
            cardStack.add(resendContainer)
            cardStack.addSpacer(10)
            cardStack.add(verifyButton)
            signUpRow.isHidden = true
            renderResend()
        }
        if animated {
            cardStack.alpha = 0
            UIView.animate(withDuration: 0.25) { self.cardStack.alpha = 1 }
        }
    }

    private func renderResend() {
        resendContainer.subviews.forEach { $0.removeFromSuperview() }
        let view: UIView
        if secondsRemaining > 0 {
            let text = NSMutableAttributedString(string: "Resend OTP in ", attributes: [
                .font: UIFont.poppins(13), .foregroundColor: UIColor.grey600])
            let m = String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
            text.append(NSAttributedString(string: m, attributes: [
                .font: UIFont.poppins(13, .bold), .foregroundColor: UIColor.appPrimary]))
            let l = UILabel()
            l.attributedText = text
            view = l
        } else if isResending {
            let s = UIActivityIndicatorView(style: .medium)
            s.color = .appPrimary
            s.startAnimating()
            view = s
        } else {
            view = textButton("Resend OTP") { [weak self] in self?.handleResendOtp() }
        }
        resendContainer.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: resendContainer.topAnchor, constant: 4),
            view.bottomAnchor.constraint(equalTo: resendContainer.bottomAnchor, constant: -4),
            view.centerXAnchor.constraint(equalTo: resendContainer.centerXAnchor),
            resendContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])
    }

    private func setOtpError(_ message: String?) {
        otpErrorLabel.text = message
        otpErrorLabel.isHidden = message == nil
        if message != nil, otpErrorLabel.superview != nil {
            cardStack.setCustomSpacing(10, after: otpBoxes)
        }
    }

    // MARK: - Countdown

    private func startCountdown(_ seconds: Int) {
        timer?.invalidate()
        secondsRemaining = seconds
        renderResend()
        guard seconds > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            if self.secondsRemaining <= 1 {
                t.invalidate()
                self.secondsRemaining = 0
            } else {
                self.secondsRemaining -= 1
            }
            self.renderResend()
        }
    }

    // MARK: - Actions

    private var isValidMobile: Bool {
        mobileField.trimmedText.range(of: #"^[6-9]\d{9}$"#, options: .regularExpression) != nil
    }

    private func handleSendOtp() {
        guard !sendButton.isLoading else { return }
        let mobile = mobileField.trimmedText
        if mobile.isEmpty { mobileField.setError("Please enter your mobile number"); return }
        if !isValidMobile { mobileField.setError("Please enter a valid 10-digit mobile number"); return }
        mobileField.setError(nil)
        sendButton.isLoading = true
        Task {
            do {
                let response = try await APIService.shared.otpLoginSendOtp(mobileNo: mobile)
                sendButton.isLoading = false
                if response.status {
                    maskedMobile = response.maskedMobile ?? mobile
                    step = .otpEntry
                    setOtpError(nil)
                    otpBoxes.clear()
                    renderStep(animated: true)
                    startCountdown(response.expiresInSeconds ?? 0)
                    _ = otpBoxes.becomeFirstResponder()
                } else {
                    mobileField.setError(response.message)
                }
            } catch {
                sendButton.isLoading = false
                mobileField.setError(APIError.userMessage(error, fallback: "Unable to send OTP. Please try again."))
            }
        }
    }

    private func handleResendOtp() {
        guard secondsRemaining <= 0, !isResending else { return }
        isResending = true
        setOtpError(nil)
        renderResend()
        Task {
            do {
                let response = try await APIService.shared.otpLoginSendOtp(mobileNo: mobileField.trimmedText)
                isResending = false
                if response.status {
                    otpBoxes.clear()
                    maskedMobile = response.maskedMobile ?? maskedMobile
                    otpSentLabel.text = "OTP sent to \(maskedMobile ?? mobileField.trimmedText)"
                    startCountdown(response.expiresInSeconds ?? 0)
                    _ = otpBoxes.becomeFirstResponder()
                    snack("OTP has been resent", .success, duration: 2)
                } else {
                    renderResend()
                    setOtpError(response.message)
                }
            } catch {
                isResending = false
                renderResend()
                setOtpError(APIError.userMessage(error, fallback: "Unable to resend OTP. Please try again."))
            }
        }
    }

    private func handleVerifyOtp() {
        guard !verifyButton.isLoading else { return }
        let otp = otpBoxes.code
        guard otp.count == 6 else { setOtpError("Please enter the complete 6-digit OTP"); return }
        verifyButton.isLoading = true
        changeButton.isEnabled = false
        setOtpError(nil)
        Task {
            do {
                let response = try await APIService.shared.otpLoginVerifyOtp(mobileNo: mobileField.trimmedText, otp: otp)
                if response.status {
                    timer?.invalidate()
                    snack(response.message.isEmpty ? "Login successful" : response.message, .success, duration: 2)
                    AppRouter.shared.showSearchProperty()
                } else {
                    verifyButton.isLoading = false
                    changeButton.isEnabled = true
                    setOtpError(response.message)
                }
            } catch {
                verifyButton.isLoading = false
                changeButton.isEnabled = true
                setOtpError(APIError.userMessage(error, fallback: "Unable to verify OTP. Please try again."))
            }
        }
    }

    private func handleChangeNumber() {
        timer?.invalidate()
        otpBoxes.clear()
        secondsRemaining = 0
        step = .mobileEntry
        setOtpError(nil)
        renderStep(animated: true)
    }
}

// MARK: - OTP digit boxes

/// Six 44×52 digit boxes with auto-advance, backspace-to-previous and paste spreading —
/// the `_buildOtpDigitBox` row from otp_login_screen.dart.
final class OtpBoxesView: UIView, UITextFieldDelegate {

    private var fields: [BackspaceTextField] = []
    var onChange: ((String) -> Void)?

    var code: String { fields.map { $0.text ?? "" }.joined() }

    init(count: Int) {
        super.init(frame: .zero)
        let row = UIStackView.h(0, alignment: .fill, [])
        row.distribution = .equalSpacing
        for i in 0..<count {
            let f = BackspaceTextField()
            f.tag = i
            f.delegate = self
            f.textAlignment = .center
            f.font = .poppins(20, .semibold)
            f.keyboardType = .numberPad
            f.textContentType = i == 0 ? .oneTimeCode : nil
            f.backgroundColor = .appFieldFill
            f.layer.cornerRadius = 12
            f.layer.borderWidth = 1
            f.layer.borderColor = UIColor.grey200.cgColor
            f.setSize(width: 44, height: 52)
            f.onBackspaceWhenEmpty = { [weak self] in self?.focus(i - 1) }
            f.addTarget(self, action: #selector(beganEditing(_:)), for: .editingDidBegin)
            f.addTarget(self, action: #selector(endedEditing(_:)), for: .editingDidEnd)
            fields.append(f)
            row.addArrangedSubview(f)
        }
        addSubview(row)
        row.pinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    func clear() { fields.forEach { $0.text = "" } }

    override func becomeFirstResponder() -> Bool {
        let index = fields.firstIndex { ($0.text ?? "").isEmpty } ?? fields.count - 1
        return fields[index].becomeFirstResponder()
    }

    private func focus(_ index: Int) {
        guard fields.indices.contains(index) else { return }
        fields[index].becomeFirstResponder()
    }

    @objc private func beganEditing(_ f: UITextField) {
        f.layer.borderColor = UIColor.appPrimary.cgColor
        f.layer.borderWidth = 1.5
    }

    @objc private func endedEditing(_ f: UITextField) {
        f.layer.borderColor = UIColor.grey200.cgColor
        f.layer.borderWidth = 1
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let digits = string.filter(\.isNumber)
        let index = textField.tag
        if string.isEmpty {
            textField.text = ""
            onChange?(code)
            return false
        }
        guard !digits.isEmpty else { return false }
        if digits.count > 1 {
            // Pasted / autofilled OTP spreads across the boxes starting here.
            for (offset, ch) in digits.enumerated() where index + offset < fields.count {
                fields[index + offset].text = String(ch)
            }
            if index + digits.count >= fields.count { endEditing(true) } else { focus(index + digits.count) }
        } else {
            textField.text = digits
            if index < fields.count - 1 { focus(index + 1) } else { endEditing(true) }
        }
        onChange?(code)
        return false
    }
}

/// Text field that reports a backspace on an already-empty box.
final class BackspaceTextField: UITextField {
    var onBackspaceWhenEmpty: (() -> Void)?

    override func deleteBackward() {
        if (text ?? "").isEmpty { onBackspaceWhenEmpty?() }
        super.deleteBackward()
    }
}
