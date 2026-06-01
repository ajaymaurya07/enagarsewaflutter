import UIKit

/// Root coordinator — owns the window and decides which flow to start.
final class AppCoordinator: Coordinator {

    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    private let window: UIWindow
    private let auth = AuthManager.shared
    private let security = DeviceSecurityService.shared

    init(window: UIWindow) {
        self.window = window
        navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    func start() {
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        showSplash()
    }

    // MARK: - Entry points

    func showSplash() {
        let vm = SplashViewModel(onSecurityFailed: { [weak self] in
            self?.showJailbroken()
        }, onNoConnection: { [weak self] in
            self?.showNoConnection()
        }, onAuthRequired: { [weak self] in
            self?.showAuth()
        }, onAuthenticated: { [weak self] in
            self?.showMain()
        })
        let vc = SplashViewController(viewModel: vm)
        navigationController.setViewControllers([vc], animated: false)
    }

    func showAuth() {
        let coordinator = AuthCoordinator(
            navigationController: navigationController,
            onAuthenticated: { [weak self] in self?.showMain() }
        )
        addChild(coordinator)
    }

    func showMain() {
        childCoordinators.removeAll()
        let coordinator = MainCoordinator(navigationController: navigationController)
        addChild(coordinator)
    }

    func showJailbroken() {
        let vc = JailbrokenViewController()
        navigationController.setViewControllers([vc], animated: true)
    }

    func showNoConnection() {
        let vc = NoConnectionViewController(onRetry: { [weak self] in
            self?.showSplash()
        })
        navigationController.setViewControllers([vc], animated: true)
    }
}
