import Foundation
import Combine

/// Matches Flutter's ArvChangeHistoryScreen state machine:
/// load properties -> (auto OTP if 1, else pick) -> verify OTP -> fetch + display history.
@MainActor
final class ArvChangeHistoryViewModel: ObservableObject {

    @Published var isLoadingInit: Bool = false
    @Published var needsPropertySelect: Bool = false
    @Published var isOtpVerified: Bool = false
    @Published var isLoadingHistory: Bool = false

    @Published var properties: [PropertyEntity] = []
    @Published var selectedProperty: PropertyEntity?
    @Published var historyItems: [ArvChangeHistoryItem] = []
    @Published var sortNewestFirst: Bool = true

    @Published var initError: String?
    @Published var historyError: String?
    @Published var otpSheetError: String?
    @Published var isVerifyingOtp: Bool = false
    @Published var maskedMobile: String = ""

    private let api = APIService.shared
    private let db = DatabaseService.shared

    var displayItems: [ArvChangeHistoryItem] {
        sortNewestFirst ? historyItems : historyItems.reversed()
    }

    var currentItemDate: String? { historyItems.first?.arvChangeDate }

    // MARK: - Flow

    func loadProperties() {
        isLoadingInit = true
        initError = nil
        needsPropertySelect = false
        isOtpVerified = false
        historyItems = []
        historyError = nil

        db.fetchAll { [weak self] entities in
            guard let self else { return }
            if entities.isEmpty {
                self.isLoadingInit = false
                self.initError = "No property found. Please select a property first."
                return
            }
            self.properties = entities
            if entities.count == 1 {
                self.isLoadingInit = false
                self.sendOtp(for: entities[0])
            } else {
                self.isLoadingInit = false
                self.needsPropertySelect = true
            }
        }
    }

    func sendOtp(for property: PropertyEntity) {
        selectedProperty = property
        needsPropertySelect = false
        isLoadingInit = true
        initError = nil

        Task {
            do {
                let res = try await api.sendOtp(phoneNumber: property.phoneNumber, propertyId: property.propertyId)
                isLoadingInit = false
                if res.success {
                    let phone = property.phoneNumber
                    maskedMobile = "XXXXXX" + (phone.count > 4 ? String(phone.suffix(4)) : phone)
                    otpSheetError = nil
                } else {
                    initError = res.message.isEmpty ? "Failed to send OTP" : res.message
                }
            } catch {
                isLoadingInit = false
                initError = (error as? NetworkError)?.errorDescription ?? "Unable to send OTP. Please try again."
            }
        }
    }

    func verifyOtp(_ otp: String, completion: @escaping (Bool) -> Void) {
        guard let property = selectedProperty else { completion(false); return }
        isVerifyingOtp = true
        otpSheetError = nil

        Task {
            do {
                let res = try await api.verifyOtp(VerifyOtpRequest(phoneNumber: property.phoneNumber, otp: otp))
                isVerifyingOtp = false
                if res.success {
                    isOtpVerified = true
                    completion(true)
                    fetchArvHistory(propertyId: property.propertyId)
                } else {
                    otpSheetError = res.message.isEmpty ? "Invalid OTP" : res.message
                    completion(false)
                }
            } catch {
                isVerifyingOtp = false
                otpSheetError = (error as? NetworkError)?.errorDescription ?? "Unable to verify OTP. Please try again."
                completion(false)
            }
        }
    }

    func fetchArvHistory(propertyId: String) {
        isLoadingHistory = true
        historyError = nil
        historyItems = []

        Task {
            do {
                let res = try await api.getArvChangeHistory(propertyId: propertyId)
                isLoadingHistory = false
                if res.success == true {
                    historyItems = res.data ?? []
                } else {
                    historyError = res.message ?? "Failed to fetch ARV history"
                }
            } catch {
                isLoadingHistory = false
                historyError = (error as? NetworkError)?.errorDescription ?? "Unable to load ARV history. Please try again."
            }
        }
    }

    func retryHistory() {
        guard let property = selectedProperty else { return }
        fetchArvHistory(propertyId: property.propertyId)
    }

    func toggleSort() {
        sortNewestFirst.toggle()
    }
}
