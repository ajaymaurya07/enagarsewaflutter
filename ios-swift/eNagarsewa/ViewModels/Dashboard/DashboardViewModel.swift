import Foundation
import UIKit
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var selectedProperty: PropertyEntity?
    @Published var userType: String = ""
    @Published var displayName: String = "User"
    @Published var isLoadingPaymentStatus: Bool = false
    @Published var propertyDetails: PropertyDetailsData?
    @Published var paymentStatus: String = ""
    @Published var billDate: String = ""
    @Published var paymentDate: String = ""

    weak var coordinator: MainCoordinator?
    private let appState = AppState.shared
    private let defaults = UserDefaultsService.shared
    private let api = APIService.shared

    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
    }

    func onViewAppear() {
        loadUserInfo()
        appState.restoreLastProperty { [weak self] entity in
            self?.selectedProperty = entity
            if entity != nil { self?.loadPropertyDetails() }
        }
    }

    private func loadUserInfo() {
        let type = defaults.userType ?? ""
        userType = type
        let name = type.lowercased() == "admin" ? "Admin" : type
        displayName = name.isEmpty ? "User" : name
    }

    func loadPropertyDetails() {
        Task {
            guard let property = selectedProperty else { return }
            isLoadingPaymentStatus = true
            do {
                let r = try await api.fetchPropertyDetails(
                    PropertyDetailsRequest(propertyId: property.propertyId, ulbId: property.ulbId)
                )
                if r.success { propertyDetails = r.data; calculatePaymentStatus() }
            } catch {}
            isLoadingPaymentStatus = false
        }
    }

    private func calculatePaymentStatus() {
        guard let details = propertyDetails else { return }
        let bd = details.billDetails?.billDate ?? ""
        let pd = (details.currReceiptDetails?.isEmpty == false)
            ? (details.currReceiptDetails?.first?.paymentDate ?? "") : ""
        billDate = bd
        paymentDate = pd

        if !pd.isEmpty && pd != "-" { paymentStatus = "Payment Done"; return }
        guard !bd.isEmpty else { return }
        guard let billDt = parseDate(bd) else { return }
        let today = Date()
        if billDt < today { paymentStatus = "Overdue" }
        else if Calendar.current.isDateInToday(billDt) { paymentStatus = "Due Today" }
        else { paymentStatus = "Upcoming" }
    }

    private func parseDate(_ s: String) -> Date? {
        let parts = s.split(separator: "-").map(String.init)
        guard parts.count == 3,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else { return nil }
        var c = DateComponents(); c.day = day; c.month = month; c.year = year
        return Calendar.current.date(from: c)
    }

    func paymentStatusColor() -> UIColor {
        switch paymentStatus {
        case "Overdue":      return .systemRed
        case "Due Today":    return UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        case "Upcoming":     return .systemBlue
        case "Payment Done": return .systemGreen
        default:             return .systemGray
        }
    }

    func paymentStatusMessage() -> String {
        switch paymentStatus {
        case "Payment Done": return "Payment received successfully. Your account is up to date."
        case "Overdue":      return "Your payment is overdue. Please clear dues to avoid penalties."
        case "Due Today":    return "Your payment is due today. Complete payment to stay updated."
        case "Upcoming":     return "Your payment is upcoming. You can pay early for convenience."
        default:             return "We are checking your latest payment details."
        }
    }

    // MARK: - Navigation

    func didTapPropertyTax()        { coordinator?.showPropertyTaxList() }
    func didTapTrackGrievance()     { coordinator?.showTrackGrievance() }
    func didTapSearchProperty()     { coordinator?.showSearchProperty() }
    func didTapTransactionHistory() { coordinator?.showTransactionHistory() }
    func didTapAccount()            { coordinator?.showAccount() }
    func didTapApplyGrievance()     { coordinator?.showApplyGrievance(property: selectedProperty) }
    func didTapGrievanceStatus()    { coordinator?.showGrievanceStatus() }
    func didTapArvChangeHistory()   { coordinator?.showArvChangeHistory() }
}
