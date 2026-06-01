import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var selectedProperty: PropertyEntity?
    @Published var isLoading: Bool = false

    weak var coordinator: MainCoordinator?
    private let appState = AppState.shared
    private let defaults = UserDefaultsService.shared

    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
    }

    func onViewAppear() {
        appState.restoreLastProperty { [weak self] entity in
            self?.selectedProperty = entity
        }
    }

    // MARK: - Navigation actions (mirrors Flutter's dashboard tap handlers)

    func didTapSearchProperty()     { coordinator?.showSearchProperty() }
    func didTapPaymentHistory()     { coordinator?.showPaymentHistory() }
    func didTapTransactionHistory() { coordinator?.showTransactionHistory() }
    func didTapGrievanceStatus()    { coordinator?.showGrievanceStatus() }
    func didTapTrackGrievance()     { coordinator?.showTrackGrievance() }
    func didTapApplyGrievance()     { coordinator?.showApplyGrievance(property: selectedProperty) }
    func didTapAccount()            { coordinator?.showAccount() }

    func didTapPayTax() {
        guard let property = selectedProperty else {
            coordinator?.showSearchProperty(); return
        }
        // Property details fetched in PropertyTaxViewModel
        let coordinator = PropertyCoordinator(
            navigationController: coordinator!.navigationController,
            onPropertySelected: {}
        )
        coordinator.showPropertyTax(property: property)
    }
}
