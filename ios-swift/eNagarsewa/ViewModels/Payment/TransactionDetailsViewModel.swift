import Foundation
import PDFKit
import UIKit

@MainActor
final class TransactionDetailsViewModel: ObservableObject {

    @Published var isGeneratingPdf: Bool = false

    let transaction: TransactionData

    init(transaction: TransactionData) {
        self.transaction = transaction
    }

    // MARK: - PDF generation (replaces Flutter's pdf + printing packages)

    func generateAndSharePdf(from viewController: UIViewController) {
        isGeneratingPdf = true
        Task {
            defer { isGeneratingPdf = false }
            let pdfData = buildPDF()
            let url = savePDF(data: pdfData)
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            viewController.present(activityVC, animated: true)
        }
    }

    private func buildPDF() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let title = "Payment Receipt"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20)
            ]
            title.draw(at: CGPoint(x: 40, y: 40), withAttributes: attrs)

            let body = """
            Transaction ID: \(transaction.txnId ?? "-")
            Bill No:        \(transaction.billNo ?? "-")
            Property ID:    \(transaction.propertyId ?? "-")
            Amount:         ₹\(transaction.paymentAmount ?? "-")
            Date:           \(transaction.dateTime ?? "-")
            Mode:           \(transaction.paymentMode ?? "-")
            Status:         \(transaction.transactionStatus ?? "-")
            """
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14)]
            body.draw(at: CGPoint(x: 40, y: 80), withAttributes: bodyAttrs)
        }
    }

    private func savePDF(data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipt_\(transaction.txnId ?? "unknown").pdf")
        try? data.write(to: url)
        return url
    }
}
