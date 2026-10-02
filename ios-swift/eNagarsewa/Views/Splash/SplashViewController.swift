import UIKit

/// Port of lib/splash_screen.dart: logo fade/scale-in, a 3-second hold while push
/// notifications initialise, then the update / device / integrity checks and routing to
/// OTP login, Search Property or the Dashboard.
final class SplashViewController: BaseViewController {

    override var hidesNavigationBar: Bool { true }

    private let content = UIStackView.v(0, alignment: .center, [])
    private var didStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        let logoCircle = UIView()
        logoCircle.backgroundColor = .white
        logoCircle.layer.cornerRadius = 74
        logoCircle.setSize(width: 148, height: 148)
        logoCircle.layer.shadowColor = UIColor.appPrimary.cgColor
        logoCircle.layer.shadowOpacity = 0.3
        logoCircle.layer.shadowRadius = 24
        logoCircle.layer.shadowOffset = .zero
        let logo = UIImageView(image: UIImage(named: "AppLogo"))
        logo.contentMode = .scaleAspectFit
        logoCircle.addSubview(logo)
        logo.setSize(width: 100, height: 100)
        logo.center(in: logoCircle)

        let name = UILabel(AppConstants.appName, font: .poppins(30, .bold), color: .appPrimary)
        let attributed = NSMutableAttributedString(string: AppConstants.appName,
                                                   attributes: [.kern: 1, .font: UIFont.poppins(30, .bold),
                                                                .foregroundColor: UIColor.appPrimary])
        name.attributedText = attributed
        let tagline = UILabel("Smart Urban Services at Your Fingertips", font: .poppins(13),
                              color: UIColor.appPrimary.withAlphaComponent(0.7), alignment: .center)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .appPrimary
        spinner.startAnimating()
        spinner.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)

        let version = UILabel("Version \(AppConstants.appVersion)", font: .poppins(12), color: .grey400)

        // Spacer(flex: 3) · logo/title · Spacer(flex: 2) · loader · Spacer(flex: 1) · version
        let top = UILayoutGuide(), middle = UILayoutGuide(), lower = UILayoutGuide()
        [top, middle, lower].forEach(view.addLayoutGuide)
        let header = UIStackView.v(0, alignment: .center, [logoCircle, name, tagline])
        header.setCustomSpacing(28, after: logoCircle)
        header.setCustomSpacing(8, after: name)
        [header, spinner, version].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.topAnchor.constraint(equalTo: top.bottomAnchor),
            middle.topAnchor.constraint(equalTo: header.bottomAnchor),
            spinner.topAnchor.constraint(equalTo: middle.bottomAnchor),
            lower.topAnchor.constraint(equalTo: spinner.bottomAnchor),
            version.topAnchor.constraint(equalTo: lower.bottomAnchor),
            version.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            middle.heightAnchor.constraint(equalTo: top.heightAnchor, multiplier: 2.0 / 3.0),
            lower.heightAnchor.constraint(equalTo: top.heightAnchor, multiplier: 1.0 / 3.0),
        ])

        [header, spinner, version].forEach { $0.alpha = 0 }
        header.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 1.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
            header.transform = .identity
        }
        UIView.animate(withDuration: 1.2, delay: 0, options: .curveEaseIn) {
            [header, spinner, version].forEach { $0.alpha = 1 }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        Task { await checkLoginStatus() }
    }

    private func checkLoginStatus() async {
        // Firebase/push init runs concurrently with the 3-second splash hold.
        PushNotificationService.shared.configure()
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        // Forced update check (Flutter shows a non-dismissible sheet).
        if let update = await AppUpdateService.shared.checkForUpdate() {
            present(UpdateSheetViewController(updateInfo: update), animated: true)
            return
        }

        let security = DeviceSecurityService.shared
        if security.isDeveloperModeEnabled {
            AppRouter.shared.replaceStack(with: RootedDeviceViewController(reason: .developerMode))
            return
        }
        if security.isTamperingDetected {
            AppRouter.shared.replaceStack(with: RootedDeviceViewController(reason: .tampered))
            return
        }
        guard await IntegrityService.shared.verify() else {
            AppRouter.shared.replaceStack(with: RootedDeviceViewController(reason: .rooted))
            return
        }

        if StorageService.isLoggedIn {
            if StorageService.isPropertyVerified {
                AppRouter.shared.showDashboard()
            } else {
                AppRouter.shared.showSearchProperty()
            }
        } else {
            AppRouter.shared.showOtpLogin()
        }
    }
}

/// Port of lib/rooted_device_screen.dart.
final class RootedDeviceViewController: BaseViewController {

    enum Reason { case rooted, developerMode, tampered }

    override var hidesNavigationBar: Bool { true }
    private let reason: Reason

    init(reason: Reason = .rooted) {
        self.reason = reason
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        interceptsBack = true

        typealias Config = (icon: String, iconBg: UIColor, iconColor: UIColor, title: String, message: String)
        let config: Config
        switch reason {
        case .developerMode:
            config = ("hammer.circle", UIColor(argb: 0xFFFFF3E0), UIColor(argb: 0xFFE65100), "Developer Mode Detected",
                      "This app cannot run with Developer Options or USB Debugging enabled.\n\nPlease disable Developer Options from Settings and restart the app.")
        case .rooted:
            config = ("lock.shield", UIColor(argb: 0xFFFFEBEE), UIColor(argb: 0xFFD32F2F), "Device Not Supported",
                      "This app cannot run on a rooted or modified device. Please use a standard device to continue.")
        case .tampered:
            config = ("exclamationmark.shield", UIColor(argb: 0xFFFFEBEE), UIColor(argb: 0xFFB71C1C), "App Integrity Violated",
                      "A security threat was detected on this device. This app cannot run in an instrumented or tampered environment.")
        }
        let (icon, iconBg, iconColor, title, message) = config

        let circle = iconTile(icon, color: iconColor, background: iconBg, size: 96, iconSize: 46, radius: 48)
        let titleLabel = UILabel(title, font: .poppins(20, .bold), color: UIColor(argb: 0xFF1A1A1A), lines: 0, alignment: .center)
        let messageLabel = UILabel(message, font: .poppins(14), color: .grey600, lines: 0, alignment: .center)
        messageLabel.setLineHeight(1.4)
        let button = PrimaryButton("Close App", color: iconColor, height: 50, radius: 12, fontSize: 15, weight: .semibold)
        // iOS has no programmatic "exit"; suspending to the home screen is the closest
        // equivalent of `SystemNavigator.pop()`.
        button.onEvent { UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil) }

        let info = UIStackView.v(0, alignment: .center, [circle, titleLabel, messageLabel])
        info.setCustomSpacing(28, after: circle)
        info.setCustomSpacing(12, after: titleLabel)
        view.addSubview(info)
        view.addSubview(button)
        info.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            info.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: -30),
            info.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            info.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
        ])
    }

    override func handleBack() {}
}
