import UIKit
import Combine

final class SignUpViewController: UIViewController {

    private let viewModel: SignUpViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: SignUpViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private let scrollView  = UIScrollView()
    private let contentView = UIView()
    private let cardView    = UIView.cardContainer()

    private let cardTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Join e-Nagarseva"
        l.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        l.textColor = .appCardText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cardSubtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Create your account to get started"
        l.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        l.textColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Fields
    private lazy var nameLabel     = UILabel.fieldLabel("Full Name")
    private lazy var nameField     = ENSInputField(placeholder: "Enter your full name", icon: "person")

    private lazy var phoneLabel    = UILabel.fieldLabel("Phone Number")
    // Selector tile — tap to pick / enter phone
    private lazy var phoneTile     = ENSSelectorTile(label: "Phone Number", placeholder: "Select Phone Number", icon: "phone")

    private lazy var emailLabel    = UILabel.fieldLabel("Email ID")
    // Selector tile — tap to pick / enter email
    private lazy var emailTile     = ENSSelectorTile(label: "Email ID", placeholder: "Select Email Address", icon: "envelope")

    private lazy var passwordLabel  = UILabel.fieldLabel("Password")
    private lazy var passwordField  = ENSInputField(placeholder: "Enter your password",   icon: "lock", isPassword: true)

    private lazy var confirmLabel   = UILabel.fieldLabel("Confirm Password")
    private lazy var confirmField   = ENSInputField(placeholder: "Re-enter your password", icon: "lock", isPassword: true)

    // "Create Account" button — matches Flutter
    private lazy var createButton: UIButton = {
        let b = UIButton.primaryButton(title: "Create Account")
        b.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return b
    }()

    // "Already have an account? Login"
    private lazy var loginLink: UIButton = {
        let b = UIButton(type: .system)
        let str = NSMutableAttributedString(
            string: "Already have an account? ",
            attributes: [
                .font: UIFont(name: "Poppins-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor(red: 0.376, green: 0.376, blue: 0.376, alpha: 1),
            ]
        )
        str.append(NSAttributedString(
            string: "Login",
            attributes: [
                .font: UIFont(name: "Poppins-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.appPrimary,
            ]
        ))
        b.setAttributedTitle(str, for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupLayout()
        bindViewModel()
        setupActions()
        setupKeyboardDismiss()
        viewModel.loadDeviceContacts()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.pinToEdges(of: view)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Nav row
        let backButton = makeBackButton()
        let navTitleLabel = UILabel()
        navTitleLabel.text = "Create Account"
        navTitleLabel.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        navTitleLabel.textColor = .appCardText
        navTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let navRow = UIStackView(arrangedSubviews: [backButton, navTitleLabel])
        navRow.axis = .horizontal; navRow.spacing = 4; navRow.alignment = .center
        navRow.translatesAutoresizingMaskIntoConstraints = false

        // Card inner stack
        let cardStack = UIStackView(arrangedSubviews: [
            cardTitleLabel, cardSubtitleLabel,
            nameLabel,     nameField,
            phoneLabel,    phoneTile,
            emailLabel,    emailTile,
            passwordLabel, passwordField,
            confirmLabel,  confirmField,
            createButton,
        ])
        cardStack.axis = .vertical
        cardStack.alignment = .fill
        cardStack.setCustomSpacing(4,  after: cardTitleLabel)
        cardStack.setCustomSpacing(24, after: cardSubtitleLabel)
        cardStack.setCustomSpacing(8,  after: nameLabel)
        cardStack.setCustomSpacing(20, after: nameField)
        cardStack.setCustomSpacing(8,  after: phoneLabel)
        cardStack.setCustomSpacing(20, after: phoneTile)
        cardStack.setCustomSpacing(8,  after: emailLabel)
        cardStack.setCustomSpacing(20, after: emailTile)
        cardStack.setCustomSpacing(8,  after: passwordLabel)
        cardStack.setCustomSpacing(20, after: passwordField)
        cardStack.setCustomSpacing(8,  after: confirmLabel)
        cardStack.setCustomSpacing(28, after: confirmField)
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor,      constant: 24),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor,  constant: 24),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor,   constant: -24),
        ])

        [navRow, cardView, loginLink].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            navRow.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 8),
            navRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),

            cardView.topAnchor.constraint(equalTo: navRow.bottomAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,   constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor,  constant: -16),

            loginLink.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 24),
            loginLink.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loginLink.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -32),
        ])
    }

    private func makeBackButton() -> UIButton {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        b.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        b.tintColor = .appPrimary
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setSize(width: 44, height: 44)
        b.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return b
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.createButton.setLoading(loading)
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            guard let self, let msg else { return }
            ENSSnackbar.show(in: self.view, message: msg, isError: true)
        }.store(in: &cancellables)

        // When OTP required → show OTP bottom sheet
        viewModel.$otpRequired.receive(on: DispatchQueue.main).sink { [weak self] needed in
            guard let self, needed else { return }
            self.showOtpSheet()
        }.store(in: &cancellables)

        // Prefill phone if exactly one detected
        viewModel.$detectedPhones.receive(on: DispatchQueue.main).sink { [weak self] phones in
            guard let self else { return }
            phoneTile.stopLoading()
            if phones.count == 1 {
                phoneTile.setValue(phones.first!)
                viewModel.phoneNumber = phones.first!
            }
        }.store(in: &cancellables)

        // Prefill email if exactly one detected
        viewModel.$detectedEmails.receive(on: DispatchQueue.main).sink { [weak self] emails in
            guard let self else { return }
            emailTile.stopLoading()
            if emails.count == 1 {
                emailTile.setValue(emails.first!)
                viewModel.email = emails.first!
            }
        }.store(in: &cancellables)
    }

    // MARK: - Actions

    private func setupActions() {
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        loginLink.addTarget(self,    action: #selector(backTapped),   for: .touchUpInside)
        phoneTile.onTap = { [weak self] in self?.showPhoneSelectionDialog() }
        emailTile.onTap = { [weak self] in self?.showEmailSelectionDialog() }
    }

    @objc private func createTapped() {
        view.endEditing(true)
        viewModel.name            = nameField.textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        viewModel.phoneNumber     = phoneTile.currentValue ?? ""
        viewModel.email           = emailTile.currentValue ?? ""
        viewModel.password        = passwordField.textField.text ?? ""
        viewModel.confirmPassword = confirmField.textField.text ?? ""
        viewModel.register()
    }

    @objc private func backTapped() { navigationController?.popViewController(animated: true) }

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - Phone selection dialog (matches Flutter _showPhoneSelectionDialog)

    private func showPhoneSelectionDialog() {
        let phones = viewModel.detectedPhones
        if phones.isEmpty {
            showManualEntryAlert(
                title: "Enter Phone Number",
                placeholder: "Enter 10 digit number",
                keyboardType: .phonePad,
                maxLength: 10
            ) { [weak self] value in
                self?.phoneTile.setValue(value)
                self?.viewModel.phoneNumber = value
            }
        } else {
            let alert = UIAlertController(title: "Select Phone Number", message: "Available Phone Numbers:", preferredStyle: .actionSheet)
            phones.forEach { phone in
                alert.addAction(UIAlertAction(title: phone, style: .default) { [weak self] _ in
                    self?.phoneTile.setValue(phone)
                    self?.viewModel.phoneNumber = phone
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }

    // MARK: - Email selection dialog (matches Flutter _showEmailSelectionDialog)

    private func showEmailSelectionDialog() {
        let emails = viewModel.detectedEmails
        if emails.isEmpty {
            showManualEntryAlert(
                title: "Enter Email Address",
                placeholder: "Enter your email address",
                keyboardType: .emailAddress,
                maxLength: 50
            ) { [weak self] value in
                self?.emailTile.setValue(value)
                self?.viewModel.email = value
            }
        } else {
            let alert = UIAlertController(title: "Select Email Address", message: "Available Email Addresses:", preferredStyle: .actionSheet)
            emails.forEach { email in
                alert.addAction(UIAlertAction(title: email, style: .default) { [weak self] _ in
                    self?.emailTile.setValue(email)
                    self?.viewModel.email = email
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }

    private func showManualEntryAlert(title: String,
                                      placeholder: String,
                                      keyboardType: UIKeyboardType,
                                      maxLength: Int,
                                      completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder    = placeholder
            tf.keyboardType   = keyboardType
        }
        alert.addAction(UIAlertAction(title: "Use This", style: .default) { [weak self] _ in
            let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            if keyboardType == .phonePad && value.count != 10 {
                self?.ENSSnackbarShow("Phone number must be 10 digits")
                return
            }
            if keyboardType == .emailAddress && !value.contains("@") {
                self?.ENSSnackbarShow("Please enter a valid email address")
                return
            }
            completion(value)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func ENSSnackbarShow(_ message: String) {
        ENSSnackbar.show(in: self.view, message: message, isError: true)
    }

    // MARK: - OTP Bottom Sheet (matches Flutter _showOtpDialog)

    private func showOtpSheet() {
        let sheet = OtpVerificationSheetViewController(
            email: viewModel.email,
            serverMessage: nil,
            viewModel: viewModel
        ) { [weak self] in
            self?.showSuccessDialog()
        }
        sheet.modalPresentationStyle = .pageSheet
        if let pc = sheet.sheetPresentationController {
            pc.detents = [.medium()]
            pc.prefersGrabberVisible = true
        }
        present(sheet, animated: true)
    }

    private func showSuccessDialog() {
        let alert = UIAlertController(title: "✓  Success", message: nil, preferredStyle: .alert)
        alert.message = "Account created successfully!"
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - OTP Verification Bottom Sheet (matches Flutter _showOtpDialog)

final class OtpVerificationSheetViewController: UIViewController {

    private let email: String
    private let serverMessage: String?
    private let viewModel: SignUpViewModel
    private let onSuccess: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(email: String, serverMessage: String?, viewModel: SignUpViewModel, onSuccess: @escaping () -> Void) {
        self.email         = email
        self.serverMessage = serverMessage
        self.viewModel     = viewModel
        self.onSuccess     = onSuccess
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Verify Email"
        l.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        l.textColor = .appCardText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var subtitleLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        if let msg = serverMessage {
            l.text = msg
            l.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
            l.textColor = UIColor(red: 0.376, green: 0.376, blue: 0.376, alpha: 1)
        } else {
            let str = NSMutableAttributedString(
                string: "An OTP has been sent to\n",
                attributes: [
                    .font: UIFont(name: "Poppins-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor(red: 0.376, green: 0.376, blue: 0.376, alpha: 1),
                ]
            )
            str.append(NSAttributedString(
                string: email,
                attributes: [
                    .font: UIFont(name: "Poppins-SemiBold", size: 13) ?? UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.appPrimary,
                ]
            ))
            l.attributedText = str
        }
        return l
    }()

    // OTP field — centred, large letterSpacing, bold
    private lazy var otpField: ENSInputField = {
        let f = ENSInputField(placeholder: "------", icon: "number.circle", keyboardType: .numberPad)
        f.textField.textAlignment = .center
        f.textField.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        return f
    }()

    private let errorLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "Poppins-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .systemRed
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var verifyButton: UIButton = {
        let b = UIButton.primaryButton(title: "Verify OTP")
        b.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return b
    }()

    private lazy var cancelButton: UIButton = {
        let b = UIButton(type: .custom)
        b.setTitle("Cancel", for: .normal)
        b.setTitleColor(UIColor(red: 0.376, green: 0.376, blue: 0.376, alpha: 1), for: .normal)
        b.titleLabel?.font = UIFont(name: "Poppins-SemiBold", size: 16) ?? .boldSystemFont(ofSize: 16)
        b.layer.cornerRadius = 12
        b.layer.borderColor  = UIColor(red: 0.820, green: 0.820, blue: 0.820, alpha: 1).cgColor
        b.layer.borderWidth  = 1
        b.heightAnchor.constraint(equalToConstant: 52).isActive = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        bindViewModel()
        verifyButton.addTarget(self, action: #selector(verifyTapped),  for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped),  for: .touchUpInside)
        isModalInPresentation = true   // isDismissible: false
    }

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, otpField, errorLabel,
            verifyButton, cancelButton,
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.setCustomSpacing(16, after: titleLabel)
        stack.setCustomSpacing(24, after: subtitleLabel)
        stack.setCustomSpacing(8,  after: otpField)
        stack.setCustomSpacing(28, after: errorLabel)
        stack.setCustomSpacing(12, after: verifyButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor,      constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor,  constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.verifyButton.setLoading(loading)
            self?.cancelButton.isEnabled = !loading
            self?.otpField.textField.isEnabled = !loading
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            guard let self else { return }
            if let msg {
                errorLabel.text = msg; errorLabel.isHidden = false
            } else {
                errorLabel.isHidden = true
            }
        }.store(in: &cancellables)

        viewModel.$otpVerified.receive(on: DispatchQueue.main).sink { [weak self] verified in
            guard let self, verified else { return }
            self.dismiss(animated: true) { self.onSuccess() }
        }.store(in: &cancellables)
    }

    @objc private func verifyTapped() {
        view.endEditing(true)
        let otp = otpField.textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !otp.isEmpty else {
            errorLabel.text = "Please enter OTP"
            errorLabel.isHidden = false
            return
        }
        viewModel.otp = otp
        viewModel.verifyOtp()
    }

    @objc private func cancelTapped() { dismiss(animated: true) }
}

// MARK: - ENSSelectorTile (matches Flutter _SelectorTile widget)
/// Tappable row: icon + label/value + loading spinner or chevron.
final class ENSSelectorTile: UIView {

    var onTap: (() -> Void)?
    private(set) var currentValue: String?

    private let iconView   = UIImageView()
    private let topLabel   = UILabel()
    private let valueLabel = UILabel()
    private let spinner    = UIActivityIndicatorView(style: .small)
    private let chevron    = UIImageView()

    convenience init(label: String, placeholder: String, icon: String) {
        self.init(frame: .zero)
        configure(labelText: label, placeholder: placeholder, iconName: icon)
    }

    override init(frame: CGRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }

    private func configure(labelText: String, placeholder: String, iconName: String) {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .appFieldFill
        layer.cornerRadius = 12
        layer.borderColor  = UIColor.appFieldBorder.cgColor
        layer.borderWidth  = 1
        clipsToBounds = true
        heightAnchor.constraint(equalToConstant: 50).isActive = true

        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        iconView.image = UIImage(systemName: iconName, withConfiguration: cfg)
        iconView.tintColor = .appPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        topLabel.text = labelText
        topLabel.font = UIFont(name: "Poppins-Regular", size: 11) ?? .systemFont(ofSize: 11)
        topLabel.textColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1)
        topLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text = "Tap to select"
        valueLabel.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        valueLabel.textColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let chCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: chCfg)
        chevron.tintColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1)
        chevron.translatesAutoresizingMaskIntoConstraints = false

        spinner.color = .appPrimary
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = UIStackView(arrangedSubviews: [topLabel, valueLabel])
        labelStack.axis = .vertical; labelStack.spacing = 2
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView); addSubview(labelStack); addSubview(chevron); addSubview(spinner)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),

            labelStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor),
            labelStack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            labelStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),

            spinner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(tileTapped))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    func setValue(_ value: String) {
        currentValue = value
        valueLabel.text = value
        valueLabel.font = UIFont(name: "Poppins-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1)
    }

    func startLoading() {
        spinner.startAnimating()
        chevron.isHidden = true
        isUserInteractionEnabled = false
    }

    func stopLoading() {
        spinner.stopAnimating()
        chevron.isHidden = false
        isUserInteractionEnabled = true
    }

    @objc private func tileTapped() { onTap?() }
}
