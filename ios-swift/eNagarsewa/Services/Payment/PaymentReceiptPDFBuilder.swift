import UIKit

/// Generates the printable PDFs used by Payment Details ("Print Property" — mirrors Flutter's
/// `_printProperty` in payment_details_screen.dart) and Transaction Details ("Share/Download
/// Receipt" — mirrors `_buildPdf` in transaction_details_screen.dart).
///
/// Uses `UIGraphicsPDFRenderer` (no third-party pdf/printing package needed on iOS) and a simple
/// vertical text-cursor layout — deliberately not a general-purpose table engine, just enough to
/// reproduce the two receipts Flutter renders.
enum PaymentReceiptPDFBuilder {

    private static let pageWidth: CGFloat = 595   // A4 @ 72dpi
    private static let pageHeight: CGFloat = 842
    private static let margin: CGFloat = 32

    // MARK: - Payment Details → "Print Property" (tax summary + property + owner info)

    static func buildPropertyTaxSummary(
        propertyId: String,
        bill: BillDetails?,
        prop: PropertyInfo?,
        owner: OwnerDetails?,
        fallbackOwnerName: String,
        fallbackMobile: String,
        fallbackFatherName: String,
        totalAdvancePay: String
    ) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var cursor = Cursor(y: margin)

            cursor.drawCentered("Property Tax Details", font: .boldSystemFont(ofSize: 20))
            cursor.y += 4
            cursor.drawCentered("Property ID: \(propertyId)", font: .systemFont(ofSize: 12), color: .darkGray)
            cursor.y += 12
            cursor.drawDivider()
            cursor.y += 10

            cursor.drawSectionHeader("Property Information")
            cursor.drawRow("Zone Name", prop?.zoneName ?? "N/A")
            cursor.drawRow("Ward Name", prop?.wardName ?? "N/A")
            cursor.drawRow("Mohalla Name", prop?.mohallaName ?? "N/A")
            cursor.drawRow("House No.", prop?.houseNo ?? "N/A")
            cursor.drawRow("Address", prop?.address ?? "N/A")
            cursor.y += 8
            cursor.drawDivider()
            cursor.y += 10

            cursor.drawSectionHeader("Owner Information")
            cursor.drawRow("Owner Name", owner?.ownerName ?? fallbackOwnerName)
            cursor.drawRow("Father Name", owner?.fatherName ?? fallbackFatherName)
            cursor.drawRow("Mobile No.", owner?.mobileNo ?? fallbackMobile)
            cursor.y += 8
            cursor.drawDivider()
            cursor.y += 10

            cursor.drawSectionHeader("Tax Summary")
            cursor.drawRow("Bill Date", bill?.billDate ?? "N/A")
            cursor.drawRow("Bill Number", bill?.billNo ?? "N/A")
            cursor.drawRow("Financial Year", bill?.finYear ?? "N/A")
            cursor.drawRow("House Tax Net Amount", "Rs. \(bill?.houseTaxNetAmount ?? "0")")
            cursor.drawRow("Water Tax Net Amount", "Rs. \(bill?.waterTaxNetAmount ?? "0")")
            cursor.drawRow("Sewer Tax Net Amount", "Rs. \(bill?.sewerTaxNetAmount ?? "0")")
            cursor.drawRow("Other Tax Net Amount", "Rs. \(bill?.othertaxNetAmount ?? "0")")
            cursor.drawRow("Water Charge Net Amount", "Rs. \(bill?.waterChargeNetAmount ?? "0")")
            cursor.drawRow("Net Demand", "Rs. \(bill?.netDemand ?? "0")")
            cursor.drawRow("Total Advance Tax Pay", "Rs. \(totalAdvancePay)")
            cursor.y += 10

            cursor.drawBoxedRow("Net Payable", "Rs. \(bill?.netPayble ?? "0")")
        }
    }

    // MARK: - Transaction Details → Share/Download receipt

    static func buildTransactionReceipt(_ txn: TransactionData) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var cursor = Cursor(y: margin)

            let status = (txn.transactionStatus ?? "").uppercased()
            let isSuccess = status == "SUCCESS"

            cursor.drawCentered("Property Tax Property ID. [ \(txn.propertyId ?? "N/A") ]",
                                font: .boldSystemFont(ofSize: 14))
            cursor.y += 6

            var ulbParts: [String] = []
            if let n = txn.ulbName { ulbParts.append(n) }
            if let t = txn.ulbType { ulbParts.append(t) }
            let ulbLabel = ulbParts.isEmpty ? "" : ", \(ulbParts.joined(separator: " "))"
            let message = isSuccess
                ? "Payment for Property Tax Successful for Property ID. [ \(txn.propertyId ?? "N/A") ]\(ulbLabel)"
                : "Payment \(status.isEmpty ? "UNKNOWN" : status) for Property ID. [ \(txn.propertyId ?? "N/A") ]\(ulbLabel)"
            cursor.drawCentered(message, font: .systemFont(ofSize: 11),
                                color: isSuccess ? .systemGreen : .systemRed)
            cursor.y += 10
            cursor.drawDivider(color: .systemGreen, thickness: 2)
            cursor.y += 10

            cursor.drawRow("Transaction Number", txn.txnId ?? "null")
            cursor.drawRow("Property ID.", txn.propertyId ?? "null")
            cursor.drawRow("Transaction Date", txn.dateTime ?? "null")
            cursor.drawRow("User Code", txn.userCode ?? "null")
            cursor.drawRow("Owner Name", txn.ownerName ?? "null")
            cursor.drawRow("Father/Husband Name", txn.fatherName ?? "null")
            cursor.drawRow("Address", txn.address ?? "null")
            cursor.drawRow("Fees(Rs.)", txn.paymentAmount ?? "null")
            cursor.drawRow("Mobile Number", txn.mobileNo ?? "null")
            cursor.drawRow("Receipt No", txn.receiptNo ?? "null")

            cursor.y += 14
            cursor.drawDivider(color: .systemGreen, thickness: 2)
            cursor.y += 10
            cursor.drawCentered("This is Computer Generated Receipt. It does not require a signature.",
                                font: .systemFont(ofSize: 10))
            cursor.y += 4
            cursor.drawCentered("This receipt is printed through EODB, e-nagarsewa portal GoUP.",
                                font: .italicSystemFont(ofSize: 10))
        }
    }

    // MARK: - Drawing cursor

    private struct Cursor {
        var y: CGFloat
        let x: CGFloat = margin
        let width: CGFloat = pageWidth - margin * 2

        mutating func drawCentered(_ text: String, font: UIFont, color: UIColor = .black) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let size = (text as NSString).size(withAttributes: attrs)
            let originX = x + (width - size.width) / 2
            (text as NSString).draw(at: CGPoint(x: max(x, originX), y: y), withAttributes: attrs)
            y += size.height + 4
        }

        mutating func drawSectionHeader(_ text: String) {
            (text as NSString).draw(
                at: CGPoint(x: x, y: y),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 13)]
            )
            y += 20
        }

        mutating func drawRow(_ label: String, _ value: String) {
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkGray,
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor.black,
            ]
            let labelWidth = width * 0.42
            (label as NSString).draw(in: CGRect(x: x, y: y, width: labelWidth, height: 40), withAttributes: labelAttrs)
            (value as NSString).draw(in: CGRect(x: x + labelWidth + 8, y: y, width: width - labelWidth - 8, height: 40),
                                     withAttributes: valueAttrs)
            let labelHeight = (label as NSString).boundingRect(
                with: CGSize(width: labelWidth, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin, attributes: labelAttrs, context: nil
            ).height
            let valueHeight = (value as NSString).boundingRect(
                with: CGSize(width: width - labelWidth - 8, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin, attributes: valueAttrs, context: nil
            ).height
            y += max(labelHeight, valueHeight, 14) + 6
        }

        mutating func drawBoxedRow(_ label: String, _ value: String) {
            let boxRect = CGRect(x: x, y: y, width: width, height: 34)
            UIColor.black.withAlphaComponent(0.6).setStroke()
            UIBezierPath(roundedRect: boxRect, cornerRadius: 6).stroke()

            let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14)]
            (label as NSString).draw(at: CGPoint(x: x + 12, y: y + 9), withAttributes: labelAttrs)
            let valueSize = (value as NSString).size(withAttributes: labelAttrs)
            (value as NSString).draw(at: CGPoint(x: x + width - valueSize.width - 12, y: y + 9), withAttributes: labelAttrs)
            y += boxRect.height + 8
        }

        func drawDivider(color: UIColor = .darkGray, thickness: CGFloat = 1) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + width, y: y))
            path.lineWidth = thickness
            color.setStroke()
            path.stroke()
        }
    }
}
