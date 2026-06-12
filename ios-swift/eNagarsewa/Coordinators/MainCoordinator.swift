import UIKit

/// Main app flow after authentication. Owns Dashboard and sub-coordinators.
final class MainCoordinator: Coordinator {

    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        showDashboard()
    }

    // MARK: - Dashboard

    func showDashboard() {
        let vm = DashboardViewModel(coordinator: self)
        let vc = DashboardViewController(viewModel: vm)
        navigationController.setViewControllers([vc], animated: true)
    }

    // MARK: - Property flow

    func showSearchProperty() {
        let coordinator = PropertyCoordinator(
            navigationController: navigationController,
            onPropertySelected: { [weak self] in self?.showDashboard() }
        )
        addChild(coordinator)
    }

    func showPropertyTaxList() {
        let vm = PropertyTaxViewModel()
        vm.onNavigateToPaymentDetails = { [weak self] property in
            self?.showPaymentDetails(for: property)
        }
        let vc = PropertyTaxViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showPaymentDetails(for property: PropertyEntity) {
        let vm = PropertyTaxDetailViewModel(property: property)
        vm.onShowPaymentHistory = { [weak self] in self?.showPaymentHistory() }
        vm.onPayTax = { [weak self, weak vm] in
            guard let self, let vm, let bill = vm.propertyDetails?.billDetails else { return }
            self.showPaymentFlow(for: property, billDetails: bill)
        }
        let vc = PropertyBillDetailsViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Payment flow

    func showPaymentFlow(for property: PropertyEntity, billDetails: BillDetails) {
        let coordinator = PaymentCoordinator(
            navigationController: navigationController,
            property: property,
            billDetails: billDetails
        )
        addChild(coordinator)
    }

    func showPaymentHistory() {
        let vm = PaymentHistoryViewModel()
        let vc = PaymentHistoryViewController(viewModel: vm, coordinator: self)
        navigationController.pushViewController(vc, animated: true)
    }

    func showTransactionHistory() {
        let vm = TransactionHistoryViewModel()
        let vc = TransactionHistoryViewController(viewModel: vm, coordinator: self)
        navigationController.pushViewController(vc, animated: true)
    }

    func showTransactionDetails(_ transaction: TransactionData) {
        let vm = TransactionDetailsViewModel(transaction: transaction)
        let vc = TransactionDetailsViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Grievance flow

    func showGrievanceFlow() {
        let coordinator = GrievanceCoordinator(navigationController: navigationController)
        addChild(coordinator)
    }

    func showApplyGrievance(property: PropertyEntity? = nil) {
        let vm = ApplyGrievanceViewModel(property: property)
        let vc = ApplyGrievanceViewController(viewModel: vm, coordinator: self)
        navigationController.pushViewController(vc, animated: true)
    }

    func showGrievanceStatus() {
        let vm = GrievanceStatusViewModel(coordinator: self)
        let vc = GrievanceStatusViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showGrievanceStatusDetails(_ grievance: GrievanceStatusData) {
        let vm = GrievanceStatusDetailsViewModel(statusData: grievance)
        let vc = GrievanceStatusDetailsViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showTrackGrievance() {
        let vm = TrackGrievanceViewModel(coordinator: self)
        let vc = TrackGrievanceViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Account

    func showAccount() {
        let vm = AccountViewModel(onLogout: { [weak self] in self?.handleLogout() })
        let vc = AccountViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Logout

    private func handleLogout() {
        Task { @MainActor in
            await AuthManager.shared.logout()
            guard let window = navigationController.view.window else { return }
            let appCoordinator = AppCoordinator(window: window)
            appCoordinator.start()
        }
    }
}
