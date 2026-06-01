import UIKit

final class GrievanceCoordinator: Coordinator {

    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        showApplyGrievance()
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

    func showGrievanceStatusDetails(_ data: GrievanceStatusData) {
        let vm = GrievanceStatusDetailsViewModel(statusData: data)
        let vc = GrievanceStatusDetailsViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showTrackGrievance() {
        let vm = TrackGrievanceViewModel(coordinator: self)
        let vc = TrackGrievanceViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func grievanceSubmitted() {
        navigationController.popViewController(animated: true)
    }
}
