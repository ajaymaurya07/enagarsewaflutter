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

    private lazy var nameField     = UITextField.styledTextField(placeholder: "Full name")
    private lazy var emailField    = UITextField.styledTextField(placeholder: "Email address")
    private lazy var phoneField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "Mobile number")
        tf.keyboardType = .phonePad
        return tf
    }()
    private lazy var passwordField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "Password")
        tf.isSecureTextEntry = true
        return tf
    }()
    private lazy var confirmPasswordField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "Confirm password")
        tf.isSecureTextEntry = true
        return tf
    }()

    private lazy var registerButton = UIButton.primaryButton(title: "Register")
    private lazy var otpField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "Enter OTP")
        tf.keyboardType = .numberPad
        tf.isHidden = true
        return tf
    }()
    private lazy var verifyOtpButton: UIButton = {
        let b = UIButton.primaryButton(title: "Verify OTP")
        b.isHidden = true
        return b
    }()

    private let errorLabel: UILabel = {
        let l = UILabel()
        l.textColor = .appError
        l.font = .systemFont(ofSize: 14)
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Create Account"
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
        setupActions()
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

        let stack = UIStackView(arrangedSubviews: [
            nameField, emailField, phoneField, passwordField, confirmPasswordField,
            errorLabel, registerButton, otpField, verifyOtpButton, activityIndicator
        ])
        stack.axis = .vertical; stack.spacing = 16; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            registerButton.heightAnchor.constraint(equalToConstant: 50),
            verifyOtpButton.heightAnchor.constraint(equalToConstant: 50),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -32),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            loading ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            self?.errorLabel.text = msg
            self?.errorLabel.isHidden = msg == nil
        }.store(in: &cancellables)

        viewModel.$requiresOtp.receive(on: DispatchQueue.main).sink { [weak self] needed in
            self?.otpField.isHidden     = !needed
            self?.verifyOtpButton.isHidden = !needed
            self?.registerButton.isHidden  = needed
        }.store(in: &cancellables)

        // Prefill phone if detected
        viewModel.$detectedPhones.receive(on: DispatchQueue.main).sink { [weak self] phones in
            if let first = phones.first, self?.phoneField.text?.isEmpty == true {
                self?.phoneField.text = first
                self?.viewModel.phoneNumber = first
            }
        }.store(in: &cancellables)
    }

    // MARK: - Actions

    private func setupActions() {
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
        verifyOtpButton.addTarget(self, action: #selector(verifyOtpTapped), for: .touchUpInside)
        [nameField, emailField, phoneField, passwordField, confirmPasswordField, otpField].forEach {
            $0.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        }
    }

    @objc private func registerTapped() {
        view.endEditing(true)
        viewModel.name            = nameField.text ?? ""
        viewModel.email           = emailField.text ?? ""
        viewModel.phoneNumber     = phoneField.text ?? ""
        viewModel.password        = passwordField.text ?? ""
        viewModel.confirmPassword = confirmPasswordField.text ?? ""
        viewModel.register()
    }

    @objc private func verifyOtpTapped() {
        view.endEditing(true)
        viewModel.otp = otpField.text ?? ""
        viewModel.verifyOtp()
    }

    @objc private func textChanged() {} // live binding handled on submit
}
