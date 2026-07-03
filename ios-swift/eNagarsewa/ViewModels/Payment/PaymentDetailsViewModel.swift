import Foundation
import UIKit

/// Full parity port of `lib/payment_details_screen.dart`.
/// Owns: fresh property-details fetch, OTP gate, PayU/SBI transaction creation,
/// PayU verify-after-checkout, and the printable tax-summary PDF.
@MainActor
final class PaymentDetailsViewModel: ObservableObject {

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    /// Full details for this property — starts as a stub built from the `billDetails`
    /// handed in by the coordinator, then replaced once the fresh fetch (matching Flutter's
    /// `_fetchDetails`) completes. This lets the UI render instantly instead of blocking on
    /// a network round trip the caller has often already made.
    @Published var details: PropertyDetailsData

    let property: PropertyEntity
    weak var coordinator: PaymentCoordinator?

    private let api       = APIService.shared
    private let integrity = IntegrityService.shared
    private let keychain  = KeychainService.shared

    init(property: PropertyEntity, billDetails: BillDetails, coordinator: PaymentCoordinator) {
        self.property = property
        self.coordinator = coordinator
        self.details = PropertyDetailsData(
            billDetails: billDetails, ownerDetails: nil, propertyDetailsInfo: nil,
            currReceiptDetails: nil, prevReceiptDetails: nil
        )
    }

    // MARK: - Derived data

    var bill: BillDetails?      { details.billDetails }
    var owner: OwnerDetails?    { details.ownerDetails }
    var propInfo: PropertyInfo? { details.propertyDetailsInfo }

    var ownerMobile: String { owner?.mobileNo ?? property.phoneNumber }

    var netPayableAmount: String { bill?.netPayble ?? "0" }

    var totalAdvancePay: String {
        let values = [bill?.houseTaxAdvance, bill?.waterTaxAdvance, bill?.sewerTaxAdvance,
                      bill?.otherTaxAdvance, bill?.waterChargeAdvance]
        let sum = values.compactMap { Double($0 ?? "0") }.reduce(0, +)
        return String(format: "%.2f", sum)
    }

    // MARK: - Fetch (mirrors Flutter's _fetchDetails)

    func fetchDetails() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.fetchPropertyDetails(
                PropertyDetailsRequest(propertyId: property.propertyId, ulbId: property.ulbId)
            )
            if response.success, let data = response.data {
                details = data
            }
            // On success == false we simply keep showing the stub built from the
            // coordinator-supplied billDetails rather than blocking the whole screen.
        } catch {
            // Non-fatal — the stub data (from the coordinator) still renders.
            errorMessage = nil
        }
    }

    // MARK: - OTP gate (mirrors Flutter's _handlePayTax / _showOtpAndPaymentDialog)

    enum PaymentDetailsError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
    }

    /// Sends the OTP and returns a masked-mobile string for display. Throws with a user-facing message on failure.
    func sendOtp() async throws -> String {
        guard !ownerMobile.isEmpty else {
            throw PaymentDetailsError.message("Mobile number not available for OTP")
        }
        let res = try await api.sendOtp(phoneNumber: ownerMobile, propertyId: property.propertyId)
        guard res.success else {
            throw PaymentDetailsError.message(res.message.isEmpty ? "Failed to send OTP" : res.message)
        }
        if let masked = res.maskedMobile, !masked.isEmpty { return masked }
        let last4 = ownerMobile.count > 4 ? String(ownerMobile.suffix(4)) : ownerMobile
        return "XXXXXX\(last4)"
    }

    func verifyOtp(_ otp: String) async throws {
        let res = try await api.verifyOtp(VerifyOtpRequest(phoneNumber: ownerMobile, otp: otp))
        guard res.success else {
            throw PaymentDetailsError.message(res.message.isEmpty ? "Invalid OTP" : res.message)
        }
    }

    // MARK: - Transaction creation (mirrors Flutter's _buildTransactionRequest / _handlePayuTransaction)

    private func buildTransactionRequest(amount: String) -> InitiateTransactionRequest {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let mobileId = "MOBTXN\(Int(Date().timeIntervalSince1970 * 1000))"

        return InitiateTransactionRequest(
            mobileTransactionId: mobileId,
            mobileTransactionTimestamp: timestamp,
            billNo: bill?.billNo ?? "",
            propertyId: property.propertyId,
            ulbId: property.ulbId,
            financialYear: bill?.finYear ?? "",
            ownerName: owner?.ownerName ?? property.ownerName,
            fatherName: owner?.fatherName ?? property.fatherName,
            mobileNo: ownerMobile,
            propertyTax: bill?.houseTaxNetAmount ?? "0",
            waterTax: bill?.waterTaxNetAmount ?? "0",
            sewerTax: bill?.sewerTaxNetAmount ?? "0",
            otherTax: bill?.othertaxNetAmount ?? "0",
            waterCharge: bill?.waterChargeNetAmount ?? "0",
            netDemand: bill?.netDemand ?? "0",
            netPayable: amount,
            totalArv: property.arvValue,
            userId: property.userId,
            emailId: UserDefaultsService.shared.emailId ?? ""
        )
    }

    /// Creates the PayU transaction server-side and stashes the mobile txn id for later
    /// cross-verification. Throws with a user-facing message on failure.
    func createPayUTransaction(amount: String) async throws -> PayUTransaction {
        let request = buildTransactionRequest(amount: amount)
        _ = try await integrity.getIntegrityToken() // ensures a fresh token is cached before the header is attached
        let response = try await api.createTransaction(request)
        guard response.success, let txn = response.data else {
            throw PaymentDetailsError.message(response.message ?? "Transaction failed")
        }
        keychain.savePayuTxnId(request.mobileTransactionId)
        return txn
    }

    /// Creates the SBI transaction server-side. SBI isn't offered in Flutter's current UI
    /// (its picker card is commented out pending backend readiness — see
    /// `_showPaymentMethodSelection` in payment_details_screen.dart) but the WebView-based
    /// checkout (`SBIPaymentViewController`) is already fully wired, so it's exposed here as
    /// the one payment path that works end-to-end without a third-party SDK.
    func createSBITransaction(amount: String) async throws -> SbiTransactionData {
        let request = buildTransactionRequest(amount: amount)
        _ = try await integrity.getIntegrityToken()
        let response = try await api.createSbiTransaction(request)
        guard response.success, let data = response.data else {
            throw PaymentDetailsError.message(response.message ?? "Transaction failed")
        }
        if let txnid = data.txnid { keychain.saveSbiTxnId(txnid) }
        return data
    }

    // MARK: - PayU hash round trip (mirrors Flutter's _PayuDelegate.generateHash)
    // Wired up so it's ready the moment a real PayU iOS SDK is dropped in — the SDK asks the
    // host app to sign a `hashName`/`hashString` pair via the backend before continuing checkout.

    func generateHash(hashName: String, hashString: String) async -> String? {
        do {
            let res = try await api.generateHash(hashName: hashName, hashString: hashString)
            return (res.status ? res.data : nil)
        } catch {
            return nil
        }
    }

    // MARK: - PayU verify-and-resolve (mirrors Flutter's _PayuDelegate._verify / _navigateFromVerify)

    struct VerifiedPaymentResult {
        let status: PaymentStatus
        let txnId: String
        let amount: String?
        let details: [String: String]
    }

    /// Cross-verifies the outcome of a PayU checkout attempt against the server, regardless of
    /// what the (stubbed) SDK reported — matching Flutter's behaviour of never trusting the SDK
    /// callback alone. Always returns a result; falls back to `.pending` with an
    /// "unable to verify" message when the mobile txn id is missing or the lookup fails.
    func verifyPayUPayment(unableToVerifyMessage: String) async -> VerifiedPaymentResult {
        guard let mobileTxnId = keychain.payuTxnId, !mobileTxnId.isEmpty else {
            return VerifiedPaymentResult(status: .pending, txnId: "", amount: nil,
                                         details: ["message": unableToVerifyMessage])
        }
        do {
            let response = try await api.getTransactionDetails(mobileTransactionId: mobileTxnId)
            guard response.status, let data = response.data else {
                return VerifiedPaymentResult(status: .pending, txnId: mobileTxnId, amount: nil,
                                             details: ["message": unableToVerifyMessage])
            }
            keychain.clearPayuTxnId()

            let statusStr = (data.paymentStatus ?? "").uppercased()
            let status: PaymentStatus
            switch statusStr {
            case "SUCCESS": status = .success
            case "FAILED":  status = .failure
            default:        status = .pending
            }

            var out: [String: String] = [:]
            func add(_ key: String, _ value: String?) { if let value, !value.isEmpty { out[key] = value } }
            func addAmount(_ key: String, _ value: String?) {
                if let value, !value.isEmpty, value != "0.00", value != "0" { out[key] = "₹ \(value)" }
            }
            add("Bill No", data.billNo)
            add("Property ID", data.propertyId)
            add("Financial Year", data.financialYear)
            add("Payment Mode", data.paymentMode)
            add("Owner Name", data.ownerName)
            add("Mobile", data.mobileNo)
            addAmount("Property Tax", data.propertyTaxPaid)
            addAmount("Water Tax", data.waterTaxPaid)
            addAmount("Sewer Tax", data.sewerTaxPaid)
            addAmount("Other Tax", data.otherTaxPaid)
            addAmount("Water Charge", data.waterChargePaid)

            return VerifiedPaymentResult(status: status, txnId: data.txnid ?? mobileTxnId,
                                         amount: data.netPayable, details: out)
        } catch {
            return VerifiedPaymentResult(status: .pending, txnId: mobileTxnId, amount: nil,
                                         details: ["message": unableToVerifyMessage])
        }
    }

    // MARK: - Receipt PDF (mirrors Flutter's _printProperty)

    func buildReceiptPdfData() -> Data {
        PaymentReceiptPDFBuilder.buildPropertyTaxSummary(
            propertyId: property.propertyId, bill: bill, prop: propInfo, owner: owner,
            fallbackOwnerName: property.ownerName, fallbackMobile: property.phoneNumber,
            fallbackFatherName: property.fatherName, totalAdvancePay: totalAdvancePay
        )
    }
}
