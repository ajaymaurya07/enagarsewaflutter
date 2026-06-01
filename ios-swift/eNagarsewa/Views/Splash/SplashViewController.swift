import UIKit
import Combine

/// Entry point after launch. Runs security checks then routes to auth or main.
final class SplashViewController: UIViewController {

    private let viewModel: SplashViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: SplashViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "e_nagar_seva_logo"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let appNameLabel: UILabel = {
        let l = UILabel()
        l.text = "e-Nagarsewa"
        l.font = .boldSystemFont(ofSize: 28)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let taglineLabel: UILabel = {
        let l = UILabel()
        l.text = "Property Tax & Grievance Management"
        l.font = .systemFont(ofSize: 14)
        l.textColor = UIColor.white.withAlphaComponent(0.8)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.color = .white
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activityIndicator.startAnimating()
        viewModel.runStartupChecks()
    }

    // MARK: - Layout

    private func setupUI() {
        view.backgroundColor = .appPrimary
        [logoImageView, appNameLabel, taglineLabel, activityIndicator].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),

            appNameLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            appNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            taglineLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 8),
            taglineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            taglineLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            activityIndicator.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
}

// MARK: - SplashViewModel

@MainActor
final class SplashViewModel: ObservableObject {

    private let security  = DeviceSecurityService.shared
    private let auth      = AuthManager.shared
    private let integrity = IntegrityService.shared

    let onSecurityFailed: () -> Void
    let onNoConnection:   () -> Void
    let onAuthRequired:   () -> Void
    let onAuthenticated:  () -> Void

    init(onSecurityFailed: @escaping () -> Void,
         onNoConnection:   @escaping () -> Void,
         onAuthRequired:   @escaping () -> Void,
         onAuthenticated:  @escaping () -> Void) {
        self.onSecurityFailed = onSecurityFailed
        self.onNoConnection   = onNoConnection
        self.onAuthRequired   = onAuthRequired
        self.onAuthenticated  = onAuthenticated
    }

    func runStartupChecks() {
        Task {
            // Security gate
            if security.isJailbroken || security.isTamperingDetected {
                onSecurityFailed(); return
            }

            // Pre-fetch integrity token non-blocking (best effort)
            _ = try? await integrity.getIntegrityToken()

            // Route by auth state
            if auth.isAuthenticated {
                onAuthenticated()
            } else {
                onAuthRequired()
            }
        }
    }
}
