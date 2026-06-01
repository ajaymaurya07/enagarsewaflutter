import UIKit

final class AuthCoordinator: Coordinator {

    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    private let onAuthenticated: () -> Void

    init(navigationController: UINavigationController, onAuthenticated: @escaping () -> Void) {
        self.navigationController = navigationController
        self.onAuthenticated = onAuthenticated
    }

    func start() {
        showLogin()
    }

    // MARK: - Navigation

    func showLogin() {
        let vm = LoginViewModel(
            onLoginSuccess: { [weak self] in self?.onAuthenticated() },
            onSignUp:       { [weak self] in self?.showSignUp() },
            onForgotPass:   { [weak self] in self?.showForgotPassword() }
        )
        let vc = LoginViewController(viewModel: vm)
        navigationController.setViewControllers([vc], animated: true)
    }

    func showSignUp() {
        let vm = SignUpViewModel(
            onSignUpSuccess: { [weak self] in self?.showLogin() }
        )
        let vc = SignUpViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showForgotPassword() {
        let vm = ForgotPasswordViewModel(
            onSuccess: { [weak self] in
                self?.navigationController.popViewController(animated: true)
            }
        )
        let vc = ForgotPasswordViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }
}
