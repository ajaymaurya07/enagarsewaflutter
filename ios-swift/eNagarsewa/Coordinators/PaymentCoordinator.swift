import UIKit

final class PaymentCoordinator: Coordinator {

    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    private let property: PropertyEntity
    private let billDetails: BillDetails

    init(navigationController: UINavigationController,
         property: PropertyEntity,
         billDetails: BillDetails) {
        self.navigationController = navigationController
        self.property    = property
        self.billDetails = billDetails
    }

    func start() {
        showPaymentDetails()
    }

    func showPaymentDetails() {
        let vm = PaymentDetailsViewModel(
            property: property,
            billDetails: billDetails,
            coordinator: self
        )
        let vc = PaymentDetailsViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showSbiPayment(data: SbiTransactionData) {
        let vc = SBIPaymentViewController(transactionData: data, coordinator: self)
        navigationController.pushViewController(vc, animated: true)
    }

    func showPaymentResult(status: PaymentStatus, txnId: String, gateway: PaymentGateway) {
        let vm = PaymentResultViewModel(status: status, txnId: txnId, gateway: gateway)
        let vc = PaymentResultViewController(viewModel: vm, coordinator: self)
        // Replace the payment flow so Back doesn't re-trigger payment
        var stack = navigationController.viewControllers
        if let idx = stack.lastIndex(where: { $0 is PaymentDetailsViewController }) {
            stack.removeSubrange(idx...)
        }
        stack.append(vc)
        navigationController.setViewControllers(stack, animated: true)
    }

    func showPaymentGrievance(txnId: String) {
        let vm = PaymentGrievanceViewModel(txnId: txnId)
        let vc = PaymentGrievanceViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    /// Matches Flutter's `ApplyGrievanceScreen(preselectedPropertyId: widget.propertyId)`
    /// pushed from the "Apply Grievance" button on Payment Details.
    func showApplyGrievance() {
        let vm = ApplyGrievanceViewModel(property: property)
        let vc = ApplyGrievanceViewController(viewModel: vm, coordinator: self)
        navigationController.pushViewController(vc, animated: true)
    }

    /// Matches Flutter's "Payment History" button on Payment Details. Flutter passes the
    /// already-fetched receipt lists for just this property; the equivalent screen here
    /// (`PaymentHistoryViewController`) instead fetches all of the user's transactions by email —
    /// an accepted approximation since that screen isn't part of this workstream.
    func showPaymentHistory() {
        let vm = PaymentHistoryViewModel()
        let vc = PaymentHistoryViewController(viewModel: vm, coordinator: nil)
        navigationController.pushViewController(vc, animated: true)
    }

    func dismiss() {
        // Pop back to dashboard
        if let dashboard = navigationController.viewControllers
            .first(where: { $0 is DashboardViewController }) {
            navigationController.popToViewController(dashboard, animated: true)
        } else {
            navigationController.popToRootViewController(animated: true)
        }
    }
}

extension PaymentCoordinator: GrievanceCoordinatorProtocol {
    /// After a grievance is filed from Payment Details, just pop back to the payment screen.
    func grievanceSubmitted() {
        navigationController.popViewController(animated: true)
    }
}
