import UIKit

/// Owns the window's single navigation stack — the role of Flutter's root `Navigator`
/// (`ApiService.navigatorKey`). Screens push each other directly; the router only handles
/// whole-stack replacements (splash → login/search/dashboard, logout, session expiry).
@MainActor
final class AppRouter {

    static let shared = AppRouter()
    private init() {}

    private(set) var navigation = AppNavigationController()
    private weak var window: UIWindow?

    func start(in window: UIWindow) {
        self.window = window
        navigation.setNavigationBarHidden(true, animated: false)
        navigation.setViewControllers([SplashViewController()], animated: false)
        window.rootViewController = navigation
        window.makeKeyAndVisible()

        SessionManager.shared.onSessionExpired = { [weak self] in
            self?.replaceStack(with: OtpLoginViewController())
        }
    }

    /// `Navigator.pushReplacement` / `pushAndRemoveUntil(..., (_) => false)`.
    func replaceStack(with vc: UIViewController, animated: Bool = true) {
        // Dismiss any sheet/dialog still on screen before swapping the stack.
        if navigation.presentedViewController != nil {
            navigation.dismiss(animated: false)
        }
        navigation.setViewControllers([vc], animated: animated)
    }

    func showOtpLogin() { replaceStack(with: OtpLoginViewController()) }
    func showSearchProperty() { replaceStack(with: SearchPropertyViewController()) }
    func showDashboard() { replaceStack(with: DashboardViewController()) }

    /// Top-most controller, used by flows (e.g. the OTP gate) that need to present UI
    /// without a reference to the calling screen — Flutter's `navigatorKey.currentContext`.
    var topViewController: UIViewController {
        navigation.topPresented
    }
}
