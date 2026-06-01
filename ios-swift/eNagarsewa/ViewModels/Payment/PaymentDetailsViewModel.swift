import Foundation

@MainActor
final class PaymentDetailsViewModel: ObservableObject {

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let property: PropertyEntity
    let billDetails: BillDetails
    weak var coordinator: PaymentCoordinator?

    private let api      = APIService.shared
    private let integrity = IntegrityService.shared
    private let keychain  = KeychainService.shared

    init(property: PropertyEntity, billDetails: BillDetails, coordinator: PaymentCoordinator) {
        self.property    = property
        self.billDetails = billDetails
        self.coordinator = coordinator
    }

    // MARK: - PayU payment

    func initiatePayUPayment(email: String, phone: String) {
        isLoading = true; errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let token = try await integrity.getIntegrityToken()
                let response = try await api.createTransaction(CreateTransactionRequest(
                    propertyId: property.propertyId,
                    billNo: billDetails.billNo ?? "",
                    amount: billDetails.netPayable ?? "0",
                    emailId: email,
                    phoneNo: phone,
                    ownerName: property.ownerName,
                    ulbId: property.ulbId,
                    integrityToken: token
                ))
                guard response.success, let txn = response.data else {
                    errorMessage = response.message; return
                }
                keychain.savePayuTxnId(txn.txnid)
                // Launch PayU SDK — pass txn to the PayU iOS SDK
                launchPayUSDK(transaction: txn)
            } catch { errorMessage = message(error) }
        }
    }

    // MARK: - SBI payment

    func initiateSBIPayment(email: String, phone: String) {
        isLoading = true; errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let token = try await integrity.getIntegrityToken()
                let response = try await api.createSbiTransaction(CreateSbiTransactionRequest(
                    propertyId: property.propertyId,
                    billNo: billDetails.billNo ?? "",
                    amount: billDetails.netPayable ?? "0",
                    emailId: email,
                    phoneNo: phone,
                    ownerName: property.ownerName,
                    ulbId: property.ulbId,
                    integrityToken: token
                ))
                guard response.success, let data = response.data else {
                    errorMessage = response.message; return
                }
                if let txnid = data.txnid { keychain.saveSbiTxnId(txnid) }
                coordinator?.showSbiPayment(data: data)
            } catch { errorMessage = message(error) }
        }
    }

    // MARK: - PayU SDK launch (placeholder — integrate actual PayU iOS SDK)

    private func launchPayUSDK(transaction: PayUTransaction) {
        // TODO: Initialize PayUbiz iOS SDK with transaction params
        // PayUbiz.open(withParams: ...) { [weak self] result in ... }
        // On success:  coordinator?.showPaymentResult(status: .success, txnId: txn.txnid, gateway: .payU)
        // On failure:  coordinator?.showPaymentResult(status: .failure, txnId: txn.txnid, gateway: .payU)
    }

    private func message(_ e: Error) -> String {
        (e as? NetworkError)?.errorDescription ?? e.localizedDescription
    }
}
