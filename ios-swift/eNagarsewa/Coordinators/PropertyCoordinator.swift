import UIKit

final class PropertyCoordinator: Coordinator {

    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    private let onPropertySelected: () -> Void

    init(navigationController: UINavigationController, onPropertySelected: @escaping () -> Void) {
        self.navigationController = navigationController
        self.onPropertySelected = onPropertySelected
    }

    func start() {
        showSearchProperty()
    }

    func showSearchProperty() {
        let vm = SearchPropertyViewModel(coordinator: self)
        let vc = SearchPropertyViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showPropertySelection(results: [PropertyData]) {
        let vm = PropertySelectionViewModel(properties: results, coordinator: self)
        let vc = PropertySelectionViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showPropertyTax(property: PropertyEntity) {
        let vm = PropertyTaxDetailViewModel(property: property, coordinator: self)
        vm.onShowPaymentHistory = { [weak self] in
            let histVm = PaymentHistoryViewModel()
            let histVc = PaymentHistoryViewController(viewModel: histVm, coordinator: nil)
            self?.navigationController.pushViewController(histVc, animated: true)
        }
        vm.onPayTax = { [weak self, weak vm] in
            guard let self, let vm, let bill = vm.propertyDetails?.billDetails else { return }
            let payCoord = PaymentCoordinator(
                navigationController: self.navigationController,
                property: property,
                billDetails: bill
            )
            self.addChild(payCoord)
            payCoord.start()
        }
        let vc = PropertyBillDetailsViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showTaxAssessment(property: PropertyEntity) {
        let vm = TaxAssessmentViewModel(property: property)
        let vc = TaxAssessmentViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func propertySelected() {
        // Pop back to dashboard and signal completion
        navigationController.popToRootViewController(animated: true)
        onPropertySelected()
    }
}
