import UIKit
import Combine

final class ForgotPasswordViewController: UIViewController {

    private let viewModel: ForgotPasswordViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ForgotPasswordViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    // Lock-reset icon in orange circle (matches Flutter Icons.lock_reset_rounded in circle)
    private let iconCircle: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 0.1)
        v.layer.cornerRadius = 40   // 80×80 → radius 40
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setSize(width: 80, height: 80)
        return v
    }()

    private let iconImageView: UIImageView = {
        let cfg = UIImage.SymbolConfiguration(pointSize: 32, weight: .regular)
        let iv = UIImageView(image: UIImage(systemName: "lock.rotation", withConfiguration: cfg))
        iv.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Card
    private let cardView = UIView.cardContainer()

    private let cardTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Reset your password"
        l.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        l.textColor = .appCardText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cardSubtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Enter your registered email to receive an OTP"
        l.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        l.textColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1)
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var emailLabel = UILabel.fieldLabel("Email")
    private lazy var emailField = ENSInputField(placeholder: "Enter your email", icon: "envelope", keyboardType: .emailAddress)

    private lazy var sendOtpButton: UIButton = {
        let b = UIButton.primaryButton(title: "Send OTP")
        b.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return b
    }()

    private lazy var backToLoginButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Back to Login", for: .normal)
        b.setTitleColor(.appPrimary, for: .normal)
        b.titleLabel?.font = UIFont(name: "Poppins-SemiBold", size: 14) ?? .boldSystemFont(ofSize: 14)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavBar()
        setupLayout()
        bindViewModel()
        setupActions()
        setupKeyboardDismiss()
    }

    // MARK: - NavBar (custom: back chevron + title, no system nav bar)

    private func setupNavBar() {
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    private lazy var backButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        b.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        b.tintColor = .appPrimary
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setSize(width: 44, height: 44)
        return b
    }()

    private let navTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Forgot Password"
        l.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        l.textColor = .appCardText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Layout

    private func setupLayout() {
        let scrollView  = UIScrollView()
        let contentView = UIView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Icon assembly
        iconCircle.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
        ])

        // Card inner stack
        let cardStack = UIStackView(arrangedSubviews: [
            cardTitleLabel, cardSubtitleLabel,
            emailLabel, emailField,
            sendOtpButton,
        ])
        cardStack.axis = .vertical
        cardStack.alignment = .fill
        cardStack.setCustomSpacing(4,  after: cardTitleLabel)
        cardStack.setCustomSpacing(28, after: cardSubtitleLabel)
        cardStack.setCustomSpacing(8,  after: emailLabel)
        cardStack.setCustomSpacing(28, after: emailField)
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor,      constant: 24),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor,  constant: 24),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor,   constant: -24),
        ])

        // Nav bar row
        let navRow = UIStackView(arrangedSubviews: [backButton, navTitleLabel])
        navRow.axis = .horizontal
        navRow.spacing = 4
        navRow.alignment = .center
        navRow.translatesAutoresizingMaskIntoConstraints = false

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

        [navRow, iconCircle, cardView, backToLoginButton].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            navRow.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 8),
            navRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),

            iconCircle.topAnchor.constraint(equalTo: navRow.bottomAnchor, constant: 24),
            iconCircle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            cardView.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 24),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,   constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor,  constant: -16),

            backToLoginButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 24),
            backToLoginButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            backToLoginButton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -32),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.sendOtpButton.setLoading(loading)
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            guard let self, let msg else { return }
            ENSSnackbar.show(in: self.view, message: msg, isError: true)
        }.store(in: &cancellables)

        // When step moves to enterOtp → show bottom sheet
        viewModel.$step.receive(on: DispatchQueue.main).sink { [weak self] step in
            guard let self, step == .enterOtp else { return }
            self.showResetBottomSheet()
        }.store(in: &cancellables)
    }

    // MARK: - Actions

    private func setupActions() {
        sendOtpButton.addTarget(self,  action: #selector(sendOtpTapped), for: .touchUpInside)
        backButton.addTarget(self,     action: #selector(backTapped),    for: .touchUpInside)
        backToLoginButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    @objc private func sendOtpTapped() {
        view.endEditing(true)
        viewModel.email = emailField.textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        viewModel.requestOtp()
    }

    @objc private func backTapped() { navigationController?.popViewController(animated: true) }

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - Reset Password Bottom Sheet (matches Flutter showModalBottomSheet)

    private func showResetBottomSheet() {
        let sheet = ResetPasswordSheetViewController(
            username: viewModel.email,
            viewModel: viewModel
        ) { [weak self] in
            // On success: success dialog then pop
            self?.showSuccessDialog()
        }
        sheet.modalPresentationStyle = .pageSheet
        if let pc = sheet.sheetPresentationController {
            pc.detents = [.large()]
            pc.prefersGrabberVisible = true
            pc.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(sheet, animated: true)
    }

    private func showSuccessDialog() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        // Green checkmark title (matches Flutter AlertDialog with check_circle_outline_rounded)
        let titleStr = NSMutableAttributedString(string: "✓  Success")
        alert.setValue(titleStr, forKey: "attributedTitle")
        let successMsg = viewModel.successMessage ?? "Password reset successfully!"
        alert.message = successMsg
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - Reset Password Bottom Sheet VC

/// Modal sheet: drag handle, OTP field, new/confirm password, inline error, Verify button, Cancel.
/// Matches Flutter's _showResetBottomSheet exactly.
final class ResetPasswordSheetViewController: UIViewController {

    private let username: String
    private let viewModel: ForgotPasswordViewModel
    private let onSuccess: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(username: String, viewModel: ForgotPasswordViewModel, onSuccess: @escaping () -> Void) {
        self.username  = username
        self.viewModel = viewModel
        self.onSuccess = onSuccess
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // Inline error container (matches Flutter red box with icon)
    private let errorContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemRed.withAlphaComponent(0.05)
        v.layer.cornerRadius = 10
        v.layer.borderColor  = UIColor.systemRed.withAlphaComponent(0.3).cgColor
        v.layer.borderWidth  = 1
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let errorIcon: UIImageView = {
        let cfg = UIImage.SymbolConfiguration(pointSize: 16)
        let iv = UIImageView(image: UIImage(systemName: "exclamationmark.circle", withConfiguration: cfg))
        iv.tintColor = .systemRed
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let errorLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        l.textColor = UIColor.systemRed.withAlphaComponent(0.85)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let sheetTitle: UILabel = {
        let l = UILabel()
        l.text = "Reset Password"
        l.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        l.textColor = .appCardText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var sheetSubtitle: UILabel = {
        let l = UILabel()
        l.text = "OTP sent to \(username)"
        l.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        l.textColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // OTP — letterSpacing 4, number pad
    private lazy var otpLabel = UILabel.fieldLabel("Enter OTP")
    private lazy var otpField: ENSInputField = {
        let f = ENSInputField(placeholder: "------", icon: "number.circle", keyboardType: .numberPad)
        f.textField.attributedPlaceholder = NSAttributedString(
            string: "------",
            attributes: [.kern: 4.0, .foregroundColor: UIColor(red: 0.741, green: 0.741, blue: 0.741, alpha: 1)]
        )
        return f
    }()

    private lazy var newPassLabel    = UILabel.fieldLabel("New Password")
    private lazy var newPassField    = ENSInputField(placeholder: "Enter new password",    icon: "lock", isPassword: true)
    private let passwordHintLabel: UILabel = {
        let l = UILabel()
        l.text = "Min 6 chars • Uppercase • Lowercase • Number • Special (@#$%^&+=!)"
        l.font = UIFont(name: "Poppins-Regular", size: 11) ?? .systemFont(ofSize: 11)
        l.textColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1)
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var confirmPassLabel = UILabel.fieldLabel("Confirm Password")
    private lazy var confirmPassField = ENSInputField(placeholder: "Re-enter new password", icon: "lock", isPassword: true)

    private lazy var resetButton: UIButton = {
        let b = UIButton.primaryButton(title: "Verify & Reset Password")
        b.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return b
    }()

    private lazy var cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.setTitleColor(UIColor(red: 0.376, green: 0.376, blue: 0.376, alpha: 1), for: .normal)
        b.titleLabel?.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        bindViewModel()
        resetButton.addTarget(self,  action: #selector(resetTapped),  for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        // Cannot dismiss by dragging (isDismissible: false in Flutter)
        isModalInPresentation = true
    }

    private func setupLayout() {
        // Error container assembly
        let errRow = UIStackView(arrangedSubviews: [errorIcon, errorLabel])
        errRow.axis = .horizontal; errRow.spacing = 8; errRow.alignment = .top
        errRow.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.addSubview(errRow)
        NSLayoutConstraint.activate([
            errRow.topAnchor.constraint(equalTo: errorContainer.topAnchor,     constant: 10),
            errRow.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor,  constant: 12),
            errRow.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor, constant: -12),
            errRow.bottomAnchor.constraint(equalTo: errorContainer.bottomAnchor,   constant: -10),
        ])

        let scrollView  = UIScrollView()
        let contentView = UIView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        let mainStack = UIStackView(arrangedSubviews: [
            sheetTitle, sheetSubtitle,
            errorContainer,
            otpLabel, otpField,
            newPassLabel, newPassField, passwordHintLabel,
            confirmPassLabel, confirmPassField,
            resetButton, cancelButton,
        ])
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.setCustomSpacing(4,  after: sheetTitle)
        mainStack.setCustomSpacing(16, after: sheetSubtitle)
        mainStack.setCustomSpacing(16, after: errorContainer)
        mainStack.setCustomSpacing(8,  after: otpLabel)
        mainStack.setCustomSpacing(20, after: otpField)
        mainStack.setCustomSpacing(8,  after: newPassLabel)
        mainStack.setCustomSpacing(6,  after: newPassField)
        mainStack.setCustomSpacing(16, after: passwordHintLabel)
        mainStack.setCustomSpacing(8,  after: confirmPassLabel)
        mainStack.setCustomSpacing(28, after: confirmPassField)
        mainStack.setCustomSpacing(12, after: resetButton)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor,     constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,  constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
        ])
    }

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.resetButton.setLoading(loading)
            self?.cancelButton.isEnabled = !loading
        }.store(in: &cancellables)

        viewModel.$sheetErrorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            guard let self else { return }
            if let msg {
                errorLabel.text = msg
                errorContainer.isHidden = false
            } else {
                errorContainer.isHidden = true
            }
        }.store(in: &cancellables)

        viewModel.$step.receive(on: DispatchQueue.main).sink { [weak self] step in
            guard let self, step == .done else { return }
            self.dismiss(animated: true) { self.onSuccess() }
        }.store(in: &cancellables)
    }

    @objc private func resetTapped() {
        view.endEditing(true)
        viewModel.otp             = otpField.textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        viewModel.newPassword     = newPassField.textField.text ?? ""
        viewModel.confirmPassword = confirmPassField.textField.text ?? ""
        viewModel.verifyOtpAndReset()
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
        viewModel.step = .enterEmail  // Reset so user can re-enter email
    }
}
