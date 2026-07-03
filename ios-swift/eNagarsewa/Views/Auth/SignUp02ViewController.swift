import UIKit
import Combine

// MARK: - Help content (matches Flutter `lib/help/signup_help.dart` + the inline strings in `sign_up_02.dart`)

enum SignUp02Help {
    static let fullNameTitle = "Full Name"
    static let fullNameMessage =
        "Enter your full name as it appears on official documents.\n" +
        "Example: Rajesh Kumar Sharma\n\n" +
        "This name will be used on your account profile."

    static let fatherHusbandTitle = "Father/Husband Name"
    static let fatherHusbandMessage = "Enter the name of your father or husband as per official records."

    static let address1Title = "Address Line 1"
    static let address1Message = "Enter your primary address (House No., Street, Locality)."

    static let address2Title = "Address Line 2"
    static let address2Message = "Enter additional address details (Area, Landmark, etc.)."

    static let ulbTypeTitle = "ULB Type"
    static let ulbTypeMessage =
        "Select the type of Urban Local Body (Nagar Nigam, Nagar Palika Parishad, or Nagar Panchayat)."

    static let cityTitle = "City"
    static let cityMessage = "Select your city. You will only be able to avail services of the selected city."

    static let phoneTitle = "Phone Number"
    static let phoneMessage =
        "Enter your 10-digit mobile number.\n" +
        "Example: 9876543210\n\n" +
        "The app can auto-detect SIM numbers on your device."

    static let passwordTitle = "Password"
    static let passwordMessage =
        "Create a strong password with at least 6 characters.\n\n" +
        "Your password must include:\n" +
        "• At least one uppercase letter (A–Z)\n" +
        "• At least one lowercase letter (a–z)\n" +
        "• At least one number (0–9)\n" +
        "• At least one special character (@#$%^&+=!)"

    static let confirmPasswordTitle = "Confirm Password"
    static let confirmPasswordMessage =
        "Re-enter the same password you entered above.\n\n" +
        "Both passwords must match to proceed."

    static let emailTitle = "Email ID"
    static let emailMessage =
        "Enter a valid email address.\n" +
        "Example: name@example.com\n\n" +
        "An OTP will be sent to this email to verify your account. " +
        "The app can auto-detect email accounts on your device."

    static let captchaTitle = "Captcha"
    static let captchaMessage = "Enter the text shown in the image to verify you are not a robot."
}

// MARK: - Lightweight text-field character/length filter (matches Flutter's `inputFormatters`)

final class SignUp02FieldFilter: NSObject, UITextFieldDelegate {
    enum Mode {
        case allow(CharacterSet, maxLength: Int)
        case deny(CharacterSet, maxLength: Int)
        case digitsOnly(maxLength: Int)
        case maxLengthOnly(Int)
    }

    private let mode: Mode
    init(_ mode: Mode) { self.mode = mode }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let current = textField.text, let r = Range(range, in: current) else { return true }
        let updated = current.replacingCharacters(in: r, with: string)

        switch mode {
        case .allow(let set, let maxLength):
            if string.unicodeScalars.contains(where: { !set.contains($0) }) { return false }
            return updated.count <= maxLength
        case .deny(let set, let maxLength):
            if string.unicodeScalars.contains(where: { set.contains($0) }) { return false }
            return updated.count <= maxLength
        case .digitsOnly(let maxLength):
            if !string.isEmpty && !string.allSatisfy({ $0.isNumber }) { return false }
            return updated.count <= maxLength
        case .maxLengthOnly(let maxLength):
            return updated.count <= maxLength
        }
    }
}

// MARK: - Captcha view (image + refresh button, matches Flutter's captcha Row)

final class SignUp02CaptchaView: UIView {

    var onRefresh: (() -> Void)?

    private let imageContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .appFieldFill
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.appFieldBorder.cgColor
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 140).isActive = true
        v.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return v
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = .appPrimary
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let failedLabel: UILabel = {
        let l = UILabel()
        l.text = "Failed"
        l.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        l.textColor = .systemRed
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isHidden = true
        return l
    }()

    private lazy var refreshButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        b.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: cfg), for: .normal)
        b.tintColor = .appPrimary
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        return b
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        imageContainer.addSubview(imageView)
        imageContainer.addSubview(spinner)
        imageContainer.addSubview(failedLabel)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            failedLabel.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            failedLabel.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
        ])

        let row = UIStackView(arrangedSubviews: [imageContainer, refreshButton])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        row.pinToEdges(of: self)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setLoading(_ loading: Bool) {
        refreshButton.isEnabled = !loading
        if loading {
            spinner.startAnimating()
            imageView.isHidden = true
            failedLabel.isHidden = true
        } else {
            spinner.stopAnimating()
        }
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
        imageView.isHidden = image == nil
        failedLabel.isHidden = image != nil
    }

    @objc private func refreshTapped() { onRefresh?() }
}

// MARK: - SignUp02ViewController

final class SignUp02ViewController: UIViewController {

    private let viewModel: SignUp02ViewModel
    private var cancellables = Set<AnyCancellable>()

    // Retained delegates (UITextField.delegate is weak)
    private let nameFilter = SignUp02FieldFilter(.allow(CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ. "), maxLength: 100))
    private let fatherFilter = SignUp02FieldFilter(.allow(CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ. "), maxLength: 100))
    private let address1Filter = SignUp02FieldFilter(.deny(CharacterSet(charactersIn: "<>\"\\"), maxLength: 100))
    private let address2Filter = SignUp02FieldFilter(.deny(CharacterSet(charactersIn: "<>\"\\"), maxLength: 100))
    private let mobileFilter = SignUp02FieldFilter(.digitsOnly(maxLength: 10))
    private let emailFilter = SignUp02FieldFilter(.deny(CharacterSet(charactersIn: "<>\"\\"), maxLength: 50))
    private let passwordFilter = SignUp02FieldFilter(.maxLengthOnly(25))
    private let confirmPasswordFilter = SignUp02FieldFilter(.maxLengthOnly(25))
    private let captchaFilter = SignUp02FieldFilter(.allow(CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"), maxLength: 10))

    init(viewModel: SignUp02ViewModel) {
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

    private lazy var nameLabel     = makeFieldLabel("Full Name", helpTitle: SignUp02Help.fullNameTitle, helpMessage: SignUp02Help.fullNameMessage)
    private lazy var nameField     = ENSInputField(placeholder: "Enter your full name", icon: "person")

    private lazy var fatherLabel   = makeFieldLabel("Father/Husband Name", helpTitle: SignUp02Help.fatherHusbandTitle, helpMessage: SignUp02Help.fatherHusbandMessage)
    private lazy var fatherField   = ENSInputField(placeholder: "Enter father/husband name", icon: "person.2")

    private lazy var address1Label = makeFieldLabel("Address 1", helpTitle: SignUp02Help.address1Title, helpMessage: SignUp02Help.address1Message)
    private lazy var address1Field = ENSInputField(placeholder: "House No., Street, Locality", icon: "house")

    private lazy var address2Label = makeFieldLabel("Address 2", helpTitle: SignUp02Help.address2Title, helpMessage: SignUp02Help.address2Message)
    private lazy var address2Field = ENSInputField(placeholder: "Area, Landmark", icon: "mappin.and.ellipse")

    private lazy var ulbTypeLabel  = makeFieldLabel("ULB Type", helpTitle: SignUp02Help.ulbTypeTitle, helpMessage: SignUp02Help.ulbTypeMessage)
    private lazy var ulbTypeTile   = ENSSelectorTile(label: "ULB Type", placeholder: "Select ULB Type", icon: "building.2")

    private lazy var cityLabel     = makeFieldLabel("City", helpTitle: SignUp02Help.cityTitle, helpMessage: SignUp02Help.cityMessage)
    private lazy var cityTile      = ENSSelectorTile(label: "City", placeholder: "Select City", icon: "mappin.circle")

    private lazy var mobileLabel   = makeFieldLabel("Mobile No.", helpTitle: SignUp02Help.phoneTitle, helpMessage: SignUp02Help.phoneMessage)
    private lazy var mobileField   = ENSInputField(placeholder: "Enter 10 digit mobile number", icon: "phone", keyboardType: .numberPad)

    private lazy var passwordLabel = makeFieldLabel("Password", helpTitle: SignUp02Help.passwordTitle, helpMessage: SignUp02Help.passwordMessage)
    private lazy var passwordField = ENSInputField(placeholder: "Enter your password", icon: "lock", isPassword: true)

    private lazy var confirmLabel  = makeFieldLabel("Confirm Password", helpTitle: SignUp02Help.confirmPasswordTitle, helpMessage: SignUp02Help.confirmPasswordMessage)
    private lazy var confirmField  = ENSInputField(placeholder: "Re-enter your password", icon: "lock", isPassword: true)

    private lazy var emailLabel    = makeFieldLabel("Email ID", helpTitle: SignUp02Help.emailTitle, helpMessage: SignUp02Help.emailMessage)
    private lazy var emailField    = ENSInputField(placeholder: "Enter your email", icon: "envelope", keyboardType: .emailAddress)

    private lazy var captchaLabel  = makeFieldLabel("Captcha", helpTitle: SignUp02Help.captchaTitle, helpMessage: SignUp02Help.captchaMessage)
    private let captchaView        = SignUp02CaptchaView()
    private lazy var captchaField  = ENSInputField(placeholder: "Enter image text", icon: "checkmark.shield")

    private lazy var createButton: UIButton = {
        let b = UIButton.primaryButton(title: "Create Account")
        b.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return b
    }()

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
        setupFieldFilters()
        bindViewModel()
        setupActions()
        setupKeyboardDismiss()
        Task { await viewModel.fetchCaptcha() }
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

        let backButton = makeBackButton()
        let navTitleLabel = UILabel()
        navTitleLabel.text = "Create Account"
        navTitleLabel.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        navTitleLabel.textColor = .appCardText
        navTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let navRow = UIStackView(arrangedSubviews: [backButton, navTitleLabel])
        navRow.axis = .horizontal; navRow.spacing = 4; navRow.alignment = .center
        navRow.translatesAutoresizingMaskIntoConstraints = false

        let captchaRow = UIStackView(arrangedSubviews: [captchaLabel, captchaView, captchaField])
        captchaRow.axis = .vertical
        captchaRow.alignment = .fill
        captchaRow.setCustomSpacing(8, after: captchaLabel)
        captchaRow.setCustomSpacing(12, after: captchaView)

        let cardStack = UIStackView(arrangedSubviews: [
            cardTitleLabel, cardSubtitleLabel,
            nameLabel,      nameField,
            fatherLabel,    fatherField,
            address1Label,  address1Field,
            address2Label,  address2Field,
            ulbTypeLabel,   ulbTypeTile,
            cityLabel,      cityTile,
            mobileLabel,    mobileField,
            passwordLabel,  passwordField,
            confirmLabel,   confirmField,
            emailLabel,     emailField,
            captchaRow,
            createButton,
        ])
        cardStack.axis = .vertical
        cardStack.alignment = .fill
        cardStack.setCustomSpacing(4,  after: cardTitleLabel)
        cardStack.setCustomSpacing(24, after: cardSubtitleLabel)
        for (label, field) in [
            (nameLabel, nameField), (fatherLabel, fatherField),
            (address1Label, address1Field), (address2Label, address2Field),
            (mobileLabel, mobileField), (passwordLabel, passwordField),
            (emailLabel, emailField),
        ] {
            cardStack.setCustomSpacing(8, after: label)
            cardStack.setCustomSpacing(20, after: field)
        }
        cardStack.setCustomSpacing(8, after: ulbTypeLabel)
        cardStack.setCustomSpacing(20, after: ulbTypeTile)
        cardStack.setCustomSpacing(8, after: cityLabel)
        cardStack.setCustomSpacing(20, after: cityTile)
        cardStack.setCustomSpacing(8, after: confirmLabel)
        cardStack.setCustomSpacing(20, after: confirmField)
        cardStack.setCustomSpacing(28, after: captchaRow)
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

    /// Matches Flutter's `InfoLabel`: a field label with a tappable info icon showing a help alert.
    private func makeFieldLabel(_ text: String, helpTitle: String, helpMessage: String) -> UIView {
        let label = UILabel.fieldLabel(text)
        let infoButton = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        infoButton.setImage(UIImage(systemName: "info.circle", withConfiguration: cfg), for: .normal)
        infoButton.tintColor = .appPrimary
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.setSize(width: 24, height: 24)
        infoButton.addAction(UIAction { [weak self] _ in
            self?.showHelp(title: helpTitle, message: helpMessage)
        }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [label, infoButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 2
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func showHelp(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setupFieldFilters() {
        nameField.textField.delegate = nameFilter
        fatherField.textField.delegate = fatherFilter
        address1Field.textField.delegate = address1Filter
        address2Field.textField.delegate = address2Filter
        mobileField.textField.delegate = mobileFilter
        emailField.textField.delegate = emailFilter
        passwordField.textField.delegate = passwordFilter
        confirmField.textField.delegate = confirmPasswordFilter
        captchaField.textField.delegate = captchaFilter
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

        viewModel.$loadingCaptcha.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.captchaView.setLoading(loading)
        }.store(in: &cancellables)

        viewModel.$captchaImage.receive(on: DispatchQueue.main).sink { [weak self] image in
            self?.captchaView.setImage(image)
        }.store(in: &cancellables)

        viewModel.$captchaRefreshTick.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.captchaField.textField.text = ""
        }.store(in: &cancellables)

        viewModel.$selectedUlbType.receive(on: DispatchQueue.main).sink { [weak self] type in
            guard let self, let type else { return }
            self.ulbTypeTile.setValue(type)
        }.store(in: &cancellables)

        viewModel.$loadingCities.receive(on: DispatchQueue.main).sink { [weak self] loading in
            guard let self else { return }
            if loading {
                self.cityTile.setValue("Loading cities...")
            } else if self.viewModel.selectedCity == nil {
                self.cityTile.reset(placeholder: "Select City")
            }
        }.store(in: &cancellables)

        viewModel.$selectedCity.receive(on: DispatchQueue.main).sink { [weak self] city in
            guard let self, let city else { return }
            self.cityTile.setValue(city.name)
        }.store(in: &cancellables)
    }

    // MARK: - Actions

    private func setupActions() {
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        loginLink.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        captchaView.onRefresh = { [weak self] in
            Task { await self?.viewModel.fetchCaptcha() }
        }
        ulbTypeTile.onTap = { [weak self] in self?.showUlbTypeSheet() }
        cityTile.onTap = { [weak self] in self?.showCitySheet() }
    }

    @objc private func backTapped() { navigationController?.popViewController(animated: true) }

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - ULB Type sheet (matches Flutter `_showUlbTypeSheet`)

    private func showUlbTypeSheet() {
        let alert = UIAlertController(title: "Select ULB Type", message: nil, preferredStyle: .actionSheet)
        for type in viewModel.ulbTypes {
            let isSelected = viewModel.selectedUlbType == type
            alert.addAction(UIAlertAction(title: isSelected ? "\(type)  ✓" : type, style: .default) { [weak self] _ in
                self?.viewModel.selectUlbType(type)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = ulbTypeTile
            popover.sourceRect = ulbTypeTile.bounds
        }
        present(alert, animated: true)
    }

    // MARK: - City sheet (matches Flutter `_showCitySheet`)

    private func showCitySheet() {
        if viewModel.selectedUlbType == nil {
            ENSSnackbar.show(in: view, message: "Please select ULB Type first", isError: true)
            return
        }
        if viewModel.loadingCities {
            ENSSnackbar.show(in: view, message: "Loading cities, please wait...", isError: true)
            return
        }
        if viewModel.cities.isEmpty {
            ENSSnackbar.show(in: view, message: "No cities available for selected ULB Type", isError: true)
            return
        }
        let sheet = SignUp02CitySheetViewController(
            cities: viewModel.cities,
            selectedCityId: viewModel.selectedCity?.id
        ) { [weak self] city in
            self?.viewModel.selectedCity = city
        }
        sheet.modalPresentationStyle = .pageSheet
        if let pc = sheet.sheetPresentationController {
            pc.detents = [.medium(), .large()]
            pc.prefersGrabberVisible = true
            pc.preferredCornerRadius = 24
        }
        present(sheet, animated: true)
    }

    // MARK: - Submit (matches Flutter `_handleSubmit` → `_doSignUp`)

    @objc private func createTapped() {
        view.endEditing(true)
        Task { await handleSubmit() }
    }

    private func handleSubmit() async {
        let result = await viewModel.submit(
            name: nameField.textField.text ?? "",
            fatherHusbandName: fatherField.textField.text ?? "",
            address1: address1Field.textField.text ?? "",
            address2: address2Field.textField.text ?? "",
            mobileNo: mobileField.textField.text ?? "",
            email: emailField.textField.text ?? "",
            password: passwordField.textField.text ?? "",
            confirmPassword: confirmField.textField.text ?? "",
            captchaText: captchaField.textField.text ?? ""
        )

        switch result {
        case .validationFailed(let message):
            ENSSnackbar.show(in: view, message: message, isError: true)

        case .registrationFailed(let message):
            showMessageDialog(title: "Registration Failed", message: message)

        case .noOtpRequired:
            // Matches Flutter: neither OTP flag came back true — no further action.
            break

        case .mobileOtpRequired(let message):
            await handleMobileOtp(message: message)

        case .emailOtpRequired(let message):
            await handleEmailOtp(message: message)
        }
    }

    private func handleMobileOtp(message: String) async {
        let mobile = viewModel.currentMobile
        let outcome = await showOtpSheet(
            title: "Verify Mobile OTP",
            subtitle: message,
            highlightText: mobile
        ) { [weak self] otp in
            guard let self else { throw CancellationError() }
            return try await self.viewModel.verifyMobileOtp(otp: otp)
        }
        guard let outcome else { return } // user cancelled

        if outcome.registrationComplete {
            showSuccessAndGoBack(outcome.message ?? "Registration complete!")
            return
        }
        if outcome.emailOtpRequired {
            await handleEmailOtp(message: outcome.message ?? "OTP sent to your email")
        }
        // else: matches Flutter's silent fallthrough when neither flag is set afterwards.
    }

    private func handleEmailOtp(message: String) async {
        let email = viewModel.currentEmail
        let outcome = await showOtpSheet(
            title: "Verify Email OTP",
            subtitle: message,
            highlightText: email
        ) { [weak self] otp in
            guard let self else { throw CancellationError() }
            return try await self.viewModel.verifyEmailOtp(otp: otp)
        }
        guard let outcome else { return } // user cancelled

        showSuccessAndGoBack(outcome.message ?? "Registration complete!")
    }

    /// Presents the OTP bottom sheet and awaits its result — mirrors Flutter's
    /// `Future<_OtpResult?> _showOtpBottomSheet(...)`.
    private func showOtpSheet(
        title: String,
        subtitle: String,
        highlightText: String,
        onVerify: @escaping (String) async throws -> SignUp02OtpVerifyOutcome
    ) async -> SignUp02OtpVerifyOutcome? {
        await withCheckedContinuation { continuation in
            let sheet = SignUp02OtpSheetViewController(
                title: title,
                subtitle: subtitle,
                highlightText: highlightText,
                onVerify: onVerify
            ) { outcome in
                continuation.resume(returning: outcome)
            }
            sheet.modalPresentationStyle = .pageSheet
            if let pc = sheet.sheetPresentationController {
                pc.detents = [.medium()]
                pc.prefersGrabberVisible = true
                pc.preferredCornerRadius = 24
            }
            present(sheet, animated: true)
        }
    }

    private func showMessageDialog(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showSuccessAndGoBack(_ message: String) {
        let alert = UIAlertController(title: "Registration Complete", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - City selection bottom sheet (matches Flutter `_showCitySheet`)

final class SignUp02CitySheetViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    private let allCities: [SignupCity]
    private let selectedCityId: Int?
    private let onSelect: (SignupCity) -> Void
    private var filtered: [SignupCity]

    init(cities: [SignupCity], selectedCityId: Int?, onSelect: @escaping (SignupCity) -> Void) {
        self.allCities = cities
        self.selectedCityId = selectedCityId
        self.filtered = cities
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Select City"
        l.font = UIFont(name: "Poppins-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        l.textColor = .appCardText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let searchField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Search city..."
        tf.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        tf.backgroundColor = .appFieldFill
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.appFieldBorder.cgColor
        tf.clearButtonMode = .whileEditing
        let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iconView.tintColor = .appPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.frame = CGRect(x: 12, y: 0, width: 20, height: 20)
        let leftContainer = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 20))
        leftContainer.addSubview(iconView)
        tf.leftView = leftContainer
        tf.leftViewMode = .always
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return tf
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.separatorInset = .zero
        return tv
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "No cities found"
        l.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        l.textColor = UIColor(red: 0.741, green: 0.741, blue: 0.741, alpha: 1)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isHidden = true
        return l
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "city")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchField.becomeFirstResponder()
    }

    private func setupLayout() {
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [titleLabel, closeButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.distribution = .equalSpacing
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        [headerRow, searchField, tableView, emptyLabel].forEach { view.addSubview($0) }
        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            searchField.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -40),
        ])
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    @objc private func searchChanged() {
        let query = (searchField.text ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        filtered = query.isEmpty ? allCities : allCities.filter { $0.name.lowercased().contains(query) }
        tableView.reloadData()
        emptyLabel.isHidden = !filtered.isEmpty
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "city", for: indexPath)
        let city = filtered[indexPath.row]
        cell.textLabel?.text = city.name
        cell.textLabel?.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        cell.accessoryType = city.id == selectedCityId ? .checkmark : .none
        cell.tintColor = .appPrimary
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 48 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let city = filtered[indexPath.row]
        onSelect(city)
        dismiss(animated: true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - OTP verification bottom sheet (matches Flutter `_showOtpBottomSheet`)

final class SignUp02OtpSheetViewController: UIViewController {

    private let titleText: String
    private let subtitleText: String
    private let highlightText: String
    private let onVerify: (String) async throws -> SignUp02OtpVerifyOutcome
    private let onResult: (SignUp02OtpVerifyOutcome?) -> Void
    private var isVerifying = false

    init(title: String,
         subtitle: String,
         highlightText: String,
         onVerify: @escaping (String) async throws -> SignUp02OtpVerifyOutcome,
         onResult: @escaping (SignUp02OtpVerifyOutcome?) -> Void) {
        self.titleText = title
        self.subtitleText = subtitle
        self.highlightText = highlightText
        self.onVerify = onVerify
        self.onResult = onResult
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = titleText
        l.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        l.textColor = .appCardText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = subtitleText
        l.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        l.textColor = UIColor(red: 0.376, green: 0.376, blue: 0.376, alpha: 1)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var highlightLabel: UILabel = {
        let l = UILabel()
        l.text = highlightText
        l.font = UIFont(name: "Poppins-SemiBold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .appPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var otpField: ENSInputField = {
        let f = ENSInputField(placeholder: "------", icon: "number", keyboardType: .numberPad)
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
        b.layer.borderColor = UIColor(red: 0.820, green: 0.820, blue: 0.820, alpha: 1).cgColor
        b.layer.borderWidth = 1
        b.heightAnchor.constraint(equalToConstant: 52).isActive = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        isModalInPresentation = true // matches Flutter's `isDismissible: false`
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        otpField.textField.becomeFirstResponder()
    }

    private func setupLayout() {
        let subtitleStack = UIStackView(arrangedSubviews: [subtitleLabel, highlightLabel])
        subtitleStack.axis = .vertical
        subtitleStack.spacing = 4

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleStack, otpField, errorLabel, verifyButton, cancelButton,
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.setCustomSpacing(16, after: titleLabel)
        stack.setCustomSpacing(24, after: subtitleStack)
        stack.setCustomSpacing(8, after: otpField)
        stack.setCustomSpacing(28, after: errorLabel)
        stack.setCustomSpacing(12, after: verifyButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func setVerifying(_ verifying: Bool) {
        isVerifying = verifying
        verifyButton.setLoading(verifying)
        cancelButton.isEnabled = !verifying
        otpField.textField.isEnabled = !verifying
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    @objc private func verifyTapped() {
        guard !isVerifying else { return }
        view.endEditing(true)
        let otp = otpField.textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !otp.isEmpty else {
            showError("Please enter OTP")
            return
        }
        errorLabel.isHidden = true
        setVerifying(true)

        Task {
            do {
                let outcome = try await onVerify(otp)
                if outcome.status {
                    dismiss(animated: true) { [weak self] in self?.onResult(outcome) }
                } else {
                    setVerifying(false)
                    showError(outcome.message ?? "OTP verification failed.")
                }
            } catch {
                setVerifying(false)
                let message = (error as? NetworkError)?.errorDescription ?? "Unable to verify OTP."
                showError(message)
            }
        }
    }

    @objc private func cancelTapped() {
        guard !isVerifying else { return }
        dismiss(animated: true) { [weak self] in self?.onResult(nil) }
    }
}
