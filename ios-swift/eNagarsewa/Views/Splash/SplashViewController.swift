import UIKit
import Combine

/// Splash screen — white background, logo with orange glow, fade+scale animation, 3-second minimum wait.
/// Matches Flutter SplashScreen exactly.
final class SplashViewController: UIViewController {

    private let viewModel: SplashViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: SplashViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.viewModel.onUpdateRequired = { [weak self] info in
            self?.presentUpdateSheet(info)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    /// White circle container with orange glow shadow — matches Flutter BoxShadow(color: 0xFFE67514, blurRadius:40, spreadRadius:8)
    private let logoContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 74   // (100 logo + 2*24 padding) / 2
        v.layer.shadowColor   = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 0.3).cgColor
        v.layer.shadowRadius  = 20
        v.layer.shadowOpacity = 1
        v.layer.shadowOffset  = .zero
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "e_nagar_seva_logo"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let appNameLabel: UILabel = {
        let l = UILabel()
        l.text = "e-Nagarsewa"
        l.font = UIFont(name: "Poppins-Bold", size: 30) ?? .boldSystemFont(ofSize: 30)
        l.textColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)  // #E67514
        l.textAlignment = .center
        l.numberOfLines = 1
        // letter-spacing ~1
        l.attributedText = NSAttributedString(
            string: "e-Nagarsewa",
            attributes: [
                .kern: 1.0,
                .font: UIFont(name: "Poppins-Bold", size: 30) ?? UIFont.boldSystemFont(ofSize: 30),
                .foregroundColor: UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1),
            ]
        )
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let taglineLabel: UILabel = {
        let l = UILabel()
        l.text = "Smart Urban Services at Your Fingertips"
        l.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        l.textColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 0.7)  // orange 70%
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)  // orange
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let versionLabel: UILabel = {
        let l = UILabel()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        l.text = "Version \(version)"
        l.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        l.textColor = UIColor(red: 0.741, green: 0.741, blue: 0.741, alpha: 1)  // grey.shade300
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Content group to animate together
    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateContent()
        activityIndicator.startAnimating()
        viewModel.runStartupChecks()
    }

    // MARK: - Force update (matches Flutter's non-dismissible update bottom sheet)

    private func presentUpdateSheet(_ info: AppUpdateService.UpdateInfo) {
        let sheet = UpdateSheetViewController(updateInfo: info)
        present(sheet, animated: true)
    }

    // MARK: - Layout

    private func setupUI() {
        // Assemble logoContainer
        logoContainer.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),
            logoImageView.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: logoContainer.centerYAnchor),
            logoContainer.widthAnchor.constraint(equalToConstant: 148),
            logoContainer.heightAnchor.constraint(equalToConstant: 148),
        ])

        // Content stack (logo + name + tagline)
        let centerStack = UIStackView(arrangedSubviews: [logoContainer, appNameLabel, taglineLabel])
        centerStack.axis = .vertical
        centerStack.alignment = .center
        centerStack.setCustomSpacing(28, after: logoContainer)
        centerStack.setCustomSpacing(8, after: appNameLabel)
        centerStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(centerStack)
        view.addSubview(activityIndicator)
        view.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            // Center stack — positioned slightly above mid
            centerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            // Spinner below center (matches Flutter Spacer flex:2 gap)
            activityIndicator.topAnchor.constraint(equalTo: centerStack.bottomAnchor, constant: 48),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Version pinned to bottom safe area
            versionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            versionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        // Start invisible for animation
        contentView.alpha = 0
        [centerStack, activityIndicator, versionLabel].forEach { $0.alpha = 0 }
        view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }

    // MARK: - Fade + scale animation (matches Flutter: 1200ms easeIn + easeOutBack)

    private func animateContent() {
        UIView.animate(
            withDuration: 1.2,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            self.view.transform = .identity
            self.view.subviews.forEach { $0.alpha = 1 }
        }
    }
}

// MARK: - SplashViewModel

@MainActor
final class SplashViewModel: ObservableObject {

    private let security      = DeviceSecurityService.shared
    private let integrity     = IntegrityService.shared
    private let storage       = UserDefaultsService.shared
    private let updateService = AppUpdateService.shared

    let onSecurityFailed:            () -> Void
    let onNoConnection:              () -> Void
    let onAuthRequired:              () -> Void
    /// Logged-in and property already verified → go to Dashboard
    let onAuthenticatedWithProperty: () -> Void
    /// Logged-in but property not verified → go to SearchProperty
    let onAuthenticatedNoProperty:   () -> Void

    /// Fired when the App Store has a newer published version. Set by SplashViewController
    /// (not passed through AppCoordinator, since it presents a sheet over splash itself rather
    /// than navigating anywhere) — matches Flutter's `_showUpdateSheet()`, which also blocks the
    /// startup flow in place instead of routing elsewhere.
    var onUpdateRequired: ((AppUpdateService.UpdateInfo) -> Void)?

    init(onSecurityFailed:            @escaping () -> Void,
         onNoConnection:              @escaping () -> Void,
         onAuthRequired:              @escaping () -> Void,
         onAuthenticatedWithProperty: @escaping () -> Void,
         onAuthenticatedNoProperty:   @escaping () -> Void) {
        self.onSecurityFailed            = onSecurityFailed
        self.onNoConnection              = onNoConnection
        self.onAuthRequired              = onAuthRequired
        self.onAuthenticatedWithProperty = onAuthenticatedWithProperty
        self.onAuthenticatedNoProperty   = onAuthenticatedNoProperty
    }

    func runStartupChecks() {
        Task {
            // Minimum 3-second splash (matches Flutter Future.delayed 3s)
            async let minWait: Void = Task.sleep(nanoseconds: 3_000_000_000)

            // Mandatory App Store update check — mirrors Flutter's _checkForUpdate() +
            // _showUpdateSheet(). A required update blocks the flow entirely: Dart never falls
            // through to the checks below once the sheet is shown (the splash coroutine returns
            // after the sheet closes), so we return here too rather than firing any callback.
            if let updateInfo = await updateService.checkForUpdate() {
                _ = try? await minWait
                onUpdateRequired?(updateInfo)
                return
            }

            // Security gate — jailbreak / tamper
            if security.isJailbroken || security.isTamperingDetected {
                _ = try? await minWait
                onSecurityFailed()
                return
            }

            // App integrity (App Attest)
            _ = try? await integrity.getIntegrityToken()

            _ = try? await minWait

            // Route by auth + property state
            if AuthManager.shared.isAuthenticated {
                if storage.isPropertyVerified {
                    onAuthenticatedWithProperty()
                } else {
                    onAuthenticatedNoProperty()
                }
            } else {
                onAuthRequired()
            }
        }
    }
}
