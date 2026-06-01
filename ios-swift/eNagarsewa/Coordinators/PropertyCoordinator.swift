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
        let vm = PropertyTaxViewModel(property: property, coordinator: self)
        let vc = PropertyTaxViewController(viewModel: vm)
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
