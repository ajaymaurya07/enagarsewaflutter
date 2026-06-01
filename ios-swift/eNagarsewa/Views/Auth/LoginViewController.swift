import UIKit
import Combine

final class LoginViewController: UIViewController {

    private let viewModel: LoginViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI Elements

    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "e_nagar_seva_logo"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Welcome Back"
        l.font = .boldSystemFont(ofSize: 26)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var emailField  = UITextField.styledTextField(placeholder: "Email address")
    private lazy var passwordField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "Password")
        tf.isSecureTextEntry = true
        return tf
    }()

    private let rememberMeSwitch: UISwitch = {
        let s = UISwitch()
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let rememberMeLabel: UILabel = {
        let l = UILabel()
        l.text = "Remember me"
        l.font = .systemFont(ofSize: 14)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var loginButton  = UIButton.primaryButton(title: "Login")
    private lazy var signupButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Don't have an account? Sign Up", for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private lazy var forgotButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Forgot Password?", for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let errorLabel: UILabel = {
        let l = UILabel()
        l.textColor = .appError
        l.font = .systemFont(ofSize: 14)
        l.numberOfLines = 0
        l.textAlignment = .center
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
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
        setupActions()
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

        let rememberRow = UIStackView(arrangedSubviews: [rememberMeSwitch, rememberMeLabel])
        rememberRow.spacing = 8; rememberRow.alignment = .center
        rememberRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [
            logoImageView, titleLabel, emailField, passwordField,
            rememberRow, errorLabel, loginButton, forgotButton, signupButton, activityIndicator
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            logoImageView.heightAnchor.constraint(equalToConstant: 100),
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 48),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -32),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            loading ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
            self?.loginButton.isEnabled = !loading
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            self?.errorLabel.text = msg
            self?.errorLabel.isHidden = msg == nil
        }.store(in: &cancellables)

        // Prefill
        emailField.text    = viewModel.email
        passwordField.text = viewModel.password
        rememberMeSwitch.isOn = viewModel.rememberMe
    }

    // MARK: - Actions

    private func setupActions() {
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        signupButton.addTarget(self, action: #selector(signupTapped), for: .touchUpInside)
        forgotButton.addTarget(self, action: #selector(forgotTapped), for: .touchUpInside)
        rememberMeSwitch.addTarget(self, action: #selector(rememberSwitched), for: .valueChanged)
        emailField.addTarget(self, action: #selector(emailChanged), for: .editingChanged)
        passwordField.addTarget(self, action: #selector(passwordChanged), for: .editingChanged)
    }

    @objc private func loginTapped()     { view.endEditing(true); viewModel.login() }
    @objc private func signupTapped()    { viewModel.onSignUp() }
    @objc private func forgotTapped()    { viewModel.onForgotPass() }
    @objc private func rememberSwitched(){ viewModel.rememberMe = rememberMeSwitch.isOn }
    @objc private func emailChanged()    { viewModel.email = emailField.text ?? "" }
    @objc private func passwordChanged() { viewModel.password = passwordField.text ?? "" }
}
