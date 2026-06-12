import Foundation
import Combine

// MARK: - PropertyTaxViewModel  (list of saved properties from DB)

@MainActor
final class PropertyTaxViewModel: ObservableObject {

    @Published var properties: [PropertyEntity] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var onNavigateToPaymentDetails: ((PropertyEntity) -> Void)?

    init() {}

    func loadProperties() {
        isLoading = true
        DatabaseService.shared.fetchAll { [weak self] entities in
            self?.properties = entities
            self?.isLoading = false
        }
    }

    func didSelectProperty(_ property: PropertyEntity) {
        onNavigateToPaymentDetails?(property)
    }
}

// MARK: - PropertyTaxDetailViewModel  (bill details for a single property)

@MainActor
final class PropertyTaxDetailViewModel: ObservableObject {

    @Published var propertyDetails: PropertyDetailsData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let property: PropertyEntity
    weak var coordinator: PropertyCoordinator?
    private let api = APIService.shared

    var onShowPaymentHistory: (() -> Void)?
    var onPayTax: (() -> Void)?

    var ownerMobile: String { propertyDetails?.ownerDetails?.mobileNo ?? "" }

    init(property: PropertyEntity, coordinator: PropertyCoordinator? = nil) {
        self.property = property
        self.coordinator = coordinator
    }

    func onViewAppear() {
        Task { await loadDetails() }
    }

    private func loadDetails() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let r = try await api.fetchPropertyDetails(
                PropertyDetailsRequest(propertyId: property.propertyId, ulbId: property.ulbId)
            )
            propertyDetails = r.data
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
        }
    }

    func sendPaymentOtp() async throws {
        let res = try await api.sendOtp(phoneNumber: ownerMobile, propertyId: property.propertyId)
        if !res.success {
            throw NSError(domain: "OTP", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: res.message])
        }
    }

    func verifyPaymentOtp(_ otp: String) async throws {
        let res = try await api.verifyOtp(VerifyOtpRequest(phoneNumber: ownerMobile, otp: otp))
        if !res.success {
            throw NSError(domain: "OTP", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: res.message])
        }
    }

    func didTapPaymentHistory() {
        onShowPaymentHistory?()
    }

    func didTapSelfAssessment() {
        coordinator?.showTaxAssessment(property: property)
    }
}
