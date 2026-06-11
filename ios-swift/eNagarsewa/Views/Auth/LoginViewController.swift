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

    // MARK: - UI

    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    // Logo — 150×150 (matches Flutter)
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "e_nagar_seva_logo"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Card — white, radius-20, shadow
    private let cardView = UIView.cardContainer()

    // "Welcome Back" — Poppins Bold 22, #333333, left-aligned
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Welcome Back"
        l.font = UIFont(name: "Poppins-Bold", size: 22) ?? .boldSystemFont(ofSize: 22)
        l.textColor = .appCardText
        l.textAlignment = .left
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // "Sign in to continue" — Poppins Regular 14, grey
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Sign in to continue"
        l.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        l.textColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1) // grey.shade500
        l.textAlignment = .left
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Fields
    private lazy var emailLabel    = UILabel.fieldLabel("Email")
    private lazy var emailField    = ENSInputField(placeholder: "Enter email", icon: "envelope", keyboardType: .emailAddress)
    private lazy var passwordLabel = UILabel.fieldLabel("Password")
    private lazy var passwordField = ENSInputField(placeholder: "Enter your password", icon: "lock", isPassword: true)

    // Remember me row — checkbox + label (left) | Forgot Password (right)
    private let rememberCheckbox = ENSCheckbox()
    private let rememberLabel: UILabel = {
        let l = UILabel()
        l.text = "Remember me"
        l.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        l.textColor = UIColor(red: 0.420, green: 0.420, blue: 0.420, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var forgotButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Forgot Password?", for: .normal)
        b.setTitleColor(.appPrimary, for: .normal)
        b.titleLabel?.font = UIFont(name: "Poppins-SemiBold", size: 12) ?? .boldSystemFont(ofSize: 12)
        b.contentHorizontalAlignment = .right
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // Login button — height 52, radius 14
    private lazy var loginButton: UIButton = {
        let b = UIButton.primaryButton(title: "Login")
        b.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return b
    }()

    // "Don't have an account?  Sign Up"  (attributed)
    private lazy var signUpButton: UIButton = {
        let b = UIButton(type: .system)
        let str = NSMutableAttributedString(
            string: "Don't have an account? ",
            attributes: [
                .font: UIFont(name: "Poppins-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor(red: 0.376, green: 0.376, blue: 0.376, alpha: 1),
            ]
        )
        str.append(NSAttributedString(
            string: "Sign Up",
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
        setupLayout()
        bindViewModel()
        setupActions()
        setupKeyboardDismiss()
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

        // Remember-me row: [checkbox][label]----------[forgotButton]
        let rememberRow = UIStackView(arrangedSubviews: [rememberCheckbox, rememberLabel])
        rememberRow.axis = .horizontal
        rememberRow.spacing = 8
        rememberRow.alignment = .center
        rememberRow.translatesAutoresizingMaskIntoConstraints = false

        let rememberForgotRow = UIStackView(arrangedSubviews: [rememberRow, forgotButton])
        rememberForgotRow.axis = .horizontal
        rememberForgotRow.distribution = .equalSpacing
        rememberForgotRow.alignment = .center
        rememberForgotRow.translatesAutoresizingMaskIntoConstraints = false

        // Card inner stack
        let cardStack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel,
            emailLabel, emailField,
            passwordLabel, passwordField,
            rememberForgotRow,
            loginButton,
        ])
        cardStack.axis = .vertical
        cardStack.alignment = .fill
        cardStack.setCustomSpacing(4,  after: titleLabel)
        cardStack.setCustomSpacing(28, after: subtitleLabel)
        cardStack.setCustomSpacing(8,  after: emailLabel)
        cardStack.setCustomSpacing(20, after: emailField)
        cardStack.setCustomSpacing(8,  after: passwordLabel)
        cardStack.setCustomSpacing(8,  after: passwordField)
        cardStack.setCustomSpacing(20, after: rememberForgotRow)
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor,     constant: 24),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor,  constant: -24),
        ])

        // Main content
        [logoImageView, cardView, signUpButton].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 150),
            logoImageView.heightAnchor.constraint(equalToConstant: 150),

            cardView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 36),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,  constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            signUpButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 28),
            signUpButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            signUpButton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -32),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.loginButton.setLoading(loading)
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            guard let self, let msg else { return }
            ENSSnackbar.show(in: self.view, message: msg, isError: true)
        }.store(in: &cancellables)

        viewModel.$successMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            guard let self, let msg else { return }
            ENSSnackbar.show(in: self.view, message: msg, isError: false)
        }.store(in: &cancellables)

        // Prefill remembered credentials
        emailField.textField.text    = viewModel.email
        passwordField.textField.text = viewModel.password
        rememberCheckbox.isChecked   = viewModel.rememberMe
    }

    // MARK: - Actions

    private func setupActions() {
        loginButton.addTarget(self, action: #selector(loginTapped),  for: .touchUpInside)
        signUpButton.addTarget(self, action: #selector(signupTapped), for: .touchUpInside)
        forgotButton.addTarget(self, action: #selector(forgotTapped), for: .touchUpInside)
        rememberCheckbox.addTarget(self, action: #selector(rememberToggled), for: .valueChanged)

        // Tap on "Remember me" label also toggles
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(rememberLabelTapped))
        rememberLabel.isUserInteractionEnabled = true
        rememberLabel.addGestureRecognizer(tapGesture)
    }

    @objc private func loginTapped() {
        view.endEditing(true)
        viewModel.email    = emailField.textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        viewModel.password = passwordField.textField.text ?? ""
        viewModel.login()
    }

    @objc private func signupTapped()      { viewModel.onSignUp() }
    @objc private func forgotTapped()      { viewModel.onForgotPass() }
    @objc private func rememberToggled()   { viewModel.rememberMe = rememberCheckbox.isChecked }
    @objc private func rememberLabelTapped() {
        rememberCheckbox.isChecked.toggle()
        viewModel.rememberMe = rememberCheckbox.isChecked
    }

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
}
