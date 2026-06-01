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

    private lazy var emailField    = UITextField.styledTextField(placeholder: "Registered email")
    private lazy var otpField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "OTP")
        tf.keyboardType = .numberPad; tf.isHidden = true; return tf
    }()
    private lazy var newPassField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "New password")
        tf.isSecureTextEntry = true; tf.isHidden = true; return tf
    }()
    private lazy var confirmPassField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "Confirm new password")
        tf.isSecureTextEntry = true; tf.isHidden = true; return tf
    }()
    private lazy var actionButton = UIButton.primaryButton(title: "Send OTP")
    private let errorLabel: UILabel = {
        let l = UILabel(); l.textColor = .appError; l.numberOfLines = 0
        l.isHidden = true; l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()
    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium); ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false; return ai
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Forgot Password"
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [
            emailField, otpField, newPassField, confirmPassField,
            errorLabel, actionButton, activityIndicator
        ])
        stack.axis = .vertical; stack.spacing = 16; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            actionButton.heightAnchor.constraint(equalToConstant: 50),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in
            l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            self?.errorLabel.text = msg; self?.errorLabel.isHidden = msg == nil
        }.store(in: &cancellables)

        viewModel.$step.receive(on: DispatchQueue.main).sink { [weak self] step in
            let isOtp = step == .enterOtp
            self?.otpField.isHidden      = !isOtp
            self?.newPassField.isHidden   = !isOtp
            self?.confirmPassField.isHidden = !isOtp
            self?.emailField.isEnabled   = !isOtp
            self?.actionButton.setTitle(isOtp ? "Reset Password" : "Send OTP", for: .normal)
        }.store(in: &cancellables)
    }

    @objc private func actionTapped() {
        view.endEditing(true)
        switch viewModel.step {
        case .enterEmail:
            viewModel.email = emailField.text ?? ""
            viewModel.requestOtp()
        case .enterOtp:
            viewModel.otp             = otpField.text ?? ""
            viewModel.newPassword     = newPassField.text ?? ""
            viewModel.confirmPassword = confirmPassField.text ?? ""
            viewModel.verifyOtpAndReset()
        case .done:
            break
        }
    }
}
