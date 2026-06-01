import Foundation

@MainActor
final class PropertyTaxViewModel: ObservableObject {

    @Published var propertyDetails: PropertyDetailsData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let property: PropertyEntity
    weak var coordinator: PropertyCoordinator?
    private let api = APIService.shared

    init(property: PropertyEntity, coordinator: PropertyCoordinator) {
        self.property = property
        self.coordinator = coordinator
    }

    func onViewAppear() {
        Task { await loadDetails() }
    }

    func loadDetails() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let r = try await api.fetchPropertyDetails(
                PropertyDetailsRequest(propertyId: property.propertyId, ulbId: property.ulbId)
            )
            propertyDetails = r.data
        } catch { errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription }
    }

    func didTapSelfAssessment() {
        coordinator?.showTaxAssessment(property: property)
    }
}
