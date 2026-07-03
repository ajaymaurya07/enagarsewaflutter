import Foundation
import UIKit

/// Full parity port of `lib/transaction_details_screen.dart`'s data/PDF logic. The receipt-card
/// layout itself lives in `TransactionDetailsViewController` (matches the codebase's convention
/// of building UI in the view layer); this type owns the derived display strings and PDF export.
@MainActor
final class TransactionDetailsViewModel: ObservableObject {

    @Published var isBusy: Bool = false

    let transaction: TransactionData

    init(transaction: TransactionData) {
        self.transaction = transaction
    }

    // MARK: - Derived display strings (mirror Flutter's _buildReceiptCard / _ulbLabel)

    var isSuccess: Bool { (transaction.transactionStatus ?? "").uppercased() == "SUCCESS" }

    var ulbLabel: String {
        var parts: [String] = []
        if let name = transaction.ulbName, !name.isEmpty { parts.append(name) }
        if let type = transaction.ulbType, !type.isEmpty { parts.append(type) }
        return parts.isEmpty ? "" : ", \(parts.joined(separator: " "))"
    }

    var headerTitle: String { "Property Tax Property ID. [ \(transaction.propertyId ?? "N/A") ]" }

    var statusMessage: String {
        let status = (transaction.transactionStatus ?? "").uppercased()
        let pid = transaction.propertyId ?? "N/A"
        return isSuccess
            ? "Payment for Property Tax Successful for Property ID. [ \(pid) ]\(ulbLabel)"
            : "Payment \(status.isEmpty ? "UNKNOWN" : status) for Property ID. [ \(pid) ]\(ulbLabel)"
    }

    /// Matches Flutter's receipt table row order exactly.
    var receiptRows: [(label: String, value: String)] {
        [
            ("Transaction Number", transaction.txnId ?? "null"),
            ("Property ID", transaction.propertyId ?? "null"),
            ("Transaction Date", transaction.dateTime ?? "null"),
            ("User Code", transaction.userCode ?? "null"),
            ("Owner Name", transaction.ownerName ?? "null"),
            ("Father/Husband Name", transaction.fatherName ?? "null"),
            ("Address", transaction.address ?? "null"),
            ("Fees(Rs.)", transaction.paymentAmount ?? "null"),
            ("Mobile Number", transaction.mobileNo ?? "null"),
            ("Receipt No", transaction.receiptNo ?? "null"),
        ]
    }

    // MARK: - PDF export (replaces Flutter's pdf + printing packages)

    func buildPdfData() -> Data {
        PaymentReceiptPDFBuilder.buildTransactionReceipt(transaction)
    }

    /// Writes the receipt PDF to a temp file for `UIActivityViewController`/print. Returns nil on
    /// write failure (surfaced by the caller as a snackbar, matching Flutter's catch blocks).
    func writePdfToTempFile() -> URL? {
        let data = buildPdfData()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipt_\(transaction.txnId ?? "payment").pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
