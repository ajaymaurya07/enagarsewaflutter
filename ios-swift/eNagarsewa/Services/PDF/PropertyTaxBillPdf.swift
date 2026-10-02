import UIKit
import WebKit

/// Port of lib/utils/property_tax_bill_pdf.dart — the "सम्पति कर बिल" print-out in the
/// e-NagarSewa portal layout. The bill is built as HTML and printed to PDF through WebKit
/// (the same route Flutter takes via `Printing.convertHtml`), which shapes Devanagari correctly.
enum PropertyTaxBillPdf {

    /// 0.8 cm page margin (Flutter passes it in the page format on iOS).
    private static let margin: CGFloat = 0.8 * 28.3465

    @MainActor
    static func buildBytes(propertyId: String, bill: BillDetails?, owner: OwnerDetails?, property: PropertyInfo?,
                           currReceipts: [ReceiptDetailsItem], arv: String?, ulbName: String?, ulbType: String?) async -> Data {
        let entity = await DatabaseService.shared.getPropertyById(propertyId)
        let isKrutidev = UlbLanguageHelper.isKrutidevValue(entity?.ulbLang)
        let html = buildHtml(propertyId: propertyId, bill: bill, owner: owner, property: property,
                             currReceipts: currReceipts, arv: arv, ulbName: ulbName, ulbType: ulbType,
                             isKrutidev: isKrutidev)
        if let data = await HTMLPDFRenderer.render(html: html, margin: margin) {
            return data
        }
        return fallbackDocument(propertyId: propertyId, bill: bill, owner: owner, property: property, isKrutidev: isKrutidev)
    }

    // MARK: - HTML

    static func buildHtml(propertyId: String, bill: BillDetails?, owner: OwnerDetails?, property: PropertyInfo?,
                          currReceipts: [ReceiptDetailsItem], arv: String?, ulbName: String?, ulbType: String?,
                          isKrutidev: Bool) -> String {
        let finYear = text(bill?.finYear)
        let receipts = currReceipts.filter(hasReceiptNo)
        let columns = taxColumns(bill, receipts)
        let grandTotal = columns.reduce(0) { $0 + $1.payableValue }

        let fontFace = isKrutidev
            ? "@font-face { font-family:'KrutiDev010'; src:url(data:font/truetype;charset=utf-8;base64,\(krutidevBase64)) format('truetype'); }"
            : ""
        let languageClass = isKrutidev ? " class=\"kd\"" : ""
        func nameLine(_ label: String, _ value: String?) -> String {
            "<div>\(label) &ndash; <span\(languageClass)>\(esc(text(value)))</span></div>"
        }
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy HH:mm"
        let printedOn = f.string(from: Date())
        let deposits = depositsSectionHtml(receipts, finYear: finYear)

        return """
        <!DOCTYPE html>
        <html lang="hi">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(fontFace)
        * { box-sizing: border-box; }
        @page { size: A4; margin: 8mm; }
        body {
          margin: 0;
          color: #000;
          font-size: 10.5px;
          font-family: 'Noto Sans Devanagari', 'Devanagari Sangam MN', 'Kohinoor Devanagari', 'Mangal', sans-serif;
        }
        table { width: 100%; border-collapse: collapse; }
        .topnote {
          border: 1px solid #e3c363; background: #fffdf4; color: #c0392b;
          padding: 6px 10px; text-align: center; font-weight: bold;
          font-size: 9.5px; line-height: 1.6;
        }
        .head td { padding: 10px 0 2px 0; font-size: 10.5px; line-height: 1.9; vertical-align: top; }
        .head .ulb { text-align: center; font-size: 17px; font-weight: bold; vertical-align: middle; }
        .title { text-align: center; font-size: 15px; font-weight: bold; margin: 8px 0 6px; }
        .grid { border: 1px solid #808080; }
        .grid + .grid, .grid.join { margin-top: -1px; }
        .grid td { border: 1px solid #808080; padding: 4px 6px; vertical-align: middle; }
        .band td { background: #e6e6e6; text-align: center; font-weight: bold; font-size: 11.5px; padding: 5px; }
        .chead td { background: #e6e6e6; text-align: center; font-weight: bold; }
        .lbl { width: 22%; }
        .val { font-weight: bold; }
        .addr { line-height: 1.9; padding: 5px 6px !important; }
        .n { text-align: right; width: 8%; }
        .sn { text-align: left; width: 4%; }
        .fh { width: 19.2%; }
        .rest td { white-space: nowrap; font-size: 9.5px; padding: 4px 4px; }
        .total td {
          background: #fffdf4; text-align: center; font-weight: bold; font-size: 11px; padding: 5px;
        }
        .kd { font-family: 'KrutiDev010'; font-size: 14px; }
        .empty { text-align: center; font-style: italic; padding: 10px 6px; }
        </style>
        </head>
        <body>

        <div class="topnote">
          In case of any discrepancy in the data, Citizen has to contact related NAGAR NIGAM /
          NAGAR PALIKA PARISHAD / NAGAR PANCHAYAT. NIC (National Informatics Centre) is not
          responsible for the data on the website.
        </div>

        <table class="head">
          <tr>
            <td style="width:33%">
              बिल संख्या&nbsp;&nbsp;<b>\(esc(text(bill?.billNo)))</b><br>
              बिल दिनांक&nbsp;&nbsp;<b>\(esc(text(bill?.billDate)))</b><br>
              प्रिन्ट दिनांक&nbsp;&nbsp;<b>\(printedOn)</b>
            </td>
            <td class="ulb" style="width:34%">\(esc(ulbHeading(ulbType, ulbName ?? property?.ulbName)))</td>
            <td style="width:33%"></td>
          </tr>
        </table>

        <div class="title">सम्पति कर बिल</div>

        \(deposits)

        <table class="grid join">
          <tr class="band"><td colspan="4">गृह संबंधी विवरण</td></tr>
          <tr>
            <td class="lbl">नयी 17-डिजिट प्रापर्टी आईडी0</td>
            <td class="val">\(esc(propertyId))</td>
            <td class="lbl">पुरानी प्रापर्टी आईडी0</td>
            <td class="val">\(esc(text(property?.oldPropertyId)))</td>
          </tr>
          <tr>
            <td class="lbl">पुरानी आईडी0</td>
            <td class="val">\(esc(text(property?.existingPropertyId)))</td>
            <td class="lbl">वित्तीय वर्ष</td>
            <td class="val">\(esc(finYear))</td>
          </tr>
          <tr>
            <td class="lbl">जोन</td>
            <td class="val">\(esc(text(property?.zoneName)))</td>
            <td class="lbl">वार्ड</td>
            <td class="val">\(esc(text(property?.wardName)))</td>
          </tr>
          <tr>
            <td class="lbl">मोहल्ला/चक</td>
            <td class="val" colspan="3">\(esc(text(property?.mohallaName)))</td>
          </tr>
          <tr>
            <td class="lbl">नाम पता</td>
            <td class="val addr" colspan="3">
              \(nameLine("नाम", owner?.ownerName))
              \(nameLine("पिता / पति का नाम", owner?.fatherName))
              <div>गृह संख्या &ndash; \(esc(text(property?.houseNo)))</div>
              \(nameLine("पता", property?.address))
              <div>मो &ndash; \(esc(maskMobile(owner?.mobileNo)))</div>
            </td>
          </tr>
          <tr>
            <td class="lbl">AV/ARV</td>
            <td class="val">\(esc(amount(arv)))</td>
            <td class="lbl">Date of Assessment</td>
            <td class="val">\(esc(text(property?.dateOfAssessment)))</td>
          </tr>
          <tr>
            <td class="lbl">Property Type</td>
            <td class="val" colspan="3">\(esc(text(property?.propertyType ?? property?.propertyUseAs)))</td>
          </tr>
        </table>

        \(financialGridHtml(columns, grandTotal: grandTotal))

        \(deposits)

        </body>
        </html>
        """
    }

    private static func financialGridHtml(_ columns: [TaxColumn], grandTotal: Double) -> String {
        func amountRow(_ serial: Int, _ label: String, _ pick: (TaxColumn) -> String) -> String {
            let cells = columns.map { "<td>\(esc(label))</td><td class=\"n\">\(esc(pick($0)))</td>" }.joined()
            return "  <tr><td class=\"sn\">\(serial)</td>\(cells)</tr>"
        }
        let headings = columns.map { "<td class=\"fh\" colspan=\"2\">\(esc($0.title))</td>" }.joined()
        let remaining = columns.map { "<td>भुगतान हेतु शेष राशि</td><td class=\"n\">\(esc($0.remaining))</td>" }.joined()
        return """
        <table class="grid join">
          <tr class="band"><td colspan="11">वित्तीय विवरण</td></tr>
          <tr class="chead"><td class="sn">क्रं0सं0</td>\(headings)</tr>
        \(amountRow(1, "वार्षिक मांग", { $0.annualDemand }))
        \(amountRow(2, "बकाया", { $0.arrear }))
        \(amountRow(3, "ब्याज", { $0.interest }))
        \(amountRow(4, "मासिक ब्याज", { $0.monthlyInterest }))
        \(amountRow(5, "कुल मांग", { $0.totalDemand }))
        \(amountRow(6, "छूट", { $0.discount }))
        \(amountRow(7, "अग्रिम जमा", { $0.advance }))
        \(amountRow(8, "देय धनराशि", { $0.payable }))
          <tr class="total">
            <td colspan="11">सम्पूर्ण देय धनराशि योग (Grand Total) : \(esc(grouped(grandTotal)))</td>
          </tr>
          <tr class="rest"><td class="sn"></td>\(remaining)</tr>
        </table>
        """
    }

    private static func depositsSectionHtml(_ receipts: [ReceiptDetailsItem], finYear: String) -> String {
        let band = "<tr class=\"band\"><td colspan=\"10\">वित्तीय वर्ष \(esc(finYear)) में पूर्व जमा धनराशि के विवरण</td></tr>"
        if receipts.isEmpty {
            let message = "No Payment Transaction Done Through https://e-nagarsewaup.gov.in in the Financial Year "
            return "<table class=\"grid join\">\n  \(band)\n  <tr><td class=\"empty\" colspan=\"10\">\(message)\(esc(finYear))</td></tr>\n</table>"
        }
        let rows = receipts.map { r -> String in
            let total = sum([r.propertyTaxPaidAmount, r.waterTaxPaidAmount, r.waterChargePaidAmount,
                             r.sewerTaxPaidAmount, r.otherTaxPaidAmount])
            return "  <tr>"
                + "<td style=\"text-align:center\">\(esc(bookNo(r.bookNo)))</td>"
                + "<td style=\"text-align:center\">\(esc(text(r.receiptNo)))</td>"
                + "<td style=\"text-align:center\">\(esc(text(r.receiptDate)))</td>"
                + "<td style=\"text-align:center\">\(esc(text(r.paymentMode)))</td>"
                + "<td class=\"n\">\(esc(amount(r.propertyTaxPaidAmount)))</td>"
                + "<td class=\"n\">\(esc(amount(r.waterTaxPaidAmount)))</td>"
                + "<td class=\"n\">\(esc(amount(r.waterChargePaidAmount)))</td>"
                + "<td class=\"n\">\(esc(amount(r.sewerTaxPaidAmount)))</td>"
                + "<td class=\"n\">\(esc(amount(r.otherTaxPaidAmount)))</td>"
                + "<td class=\"n val\">\(esc(grouped(total)))</td>"
                + "</tr>"
        }.joined(separator: "\n")
        return """
        <table class="grid join">
          \(band)
          <tr class="chead">
            <td>बुक संख्या</td><td>रसीद सं.</td><td>जमा की तारीख और समय</td><td>भुगतान मोड</td>
            <td>गृहकर जमा</td><td>जलकर जमा</td><td>जल शुल्क जमा</td><td>सीवरेजकर जमा</td>
            <td>अन्यकर जमा</td><td>कुल जमा</td>
          </tr>
        \(rows)
        </table>
        """
    }

    // MARK: - Tax data

    private struct TaxColumn {
        let title: String
        let annualDemand, arrear, interest, monthlyInterest, totalDemand, discount, advance, payable: String
        let payableValue: Double
        let depositedValue: Double

        init(title: String, annualDemand: String?, arrear: String?, interest: String?, monthlyInterest: String?,
             totalDemand: String?, discount: String?, advance: String?, payable: String?, deposited: Double) {
            self.title = title
            self.annualDemand = PropertyTaxBillPdf.amount(annualDemand)
            self.arrear = PropertyTaxBillPdf.amount(arrear)
            self.interest = PropertyTaxBillPdf.amount(interest)
            self.monthlyInterest = PropertyTaxBillPdf.amount(monthlyInterest)
            self.totalDemand = PropertyTaxBillPdf.amount(totalDemand)
            self.discount = PropertyTaxBillPdf.amount(discount)
            self.advance = PropertyTaxBillPdf.amount(advance)
            self.payable = PropertyTaxBillPdf.amount(payable)
            self.payableValue = PropertyTaxBillPdf.number(payable)
            self.depositedValue = deposited
        }

        var remaining: String { String(format: "%.2f", max(0, payableValue - depositedValue)) }
    }

    private static func taxColumns(_ b: BillDetails?, _ receipts: [ReceiptDetailsItem]) -> [TaxColumn] {
        func paid(_ pick: (ReceiptDetailsItem) -> String?) -> Double { sum(receipts.map(pick)) }
        return [
            TaxColumn(title: "गृहकर", annualDemand: b?.houseCurrentTax, arrear: b?.houseTaxArrear,
                      interest: b?.houseTaxInterest, monthlyInterest: b?.houseTaxMonthlyInterest,
                      totalDemand: b?.houseTaxNetAmount, discount: b?.houseTaxDiscount, advance: b?.houseTaxAdvance,
                      payable: b?.houseTaxPayable, deposited: paid { $0.propertyTaxPaidAmount }),
            TaxColumn(title: "जलकर", annualDemand: b?.waterCurrentTax, arrear: b?.waterTaxArrear,
                      interest: b?.waterTaxInterest, monthlyInterest: b?.waterTaxMonthlyInterest,
                      totalDemand: b?.waterTaxNetAmount, discount: b?.waterTaxDiscount, advance: b?.waterTaxAdvance,
                      payable: b?.waterTaxPayable, deposited: paid { $0.waterTaxPaidAmount }),
            TaxColumn(title: "जल शुल्क", annualDemand: b?.waterChargeCurrent, arrear: b?.waterChargeArrear,
                      interest: b?.waterChargeInterest, monthlyInterest: b?.waterChargeMonthlyInterest,
                      totalDemand: b?.waterChargeNetAmount, discount: b?.waterChargeDiscount,
                      advance: b?.waterChargeAdvance, payable: b?.waterChargePayable,
                      deposited: paid { $0.waterChargePaidAmount }),
            TaxColumn(title: "सीवरेजकर", annualDemand: b?.sewerCurrentTax, arrear: b?.sewerTaxArrear,
                      interest: b?.sewerTaxInterest, monthlyInterest: b?.sewerTaxMonthlyInterest,
                      totalDemand: b?.sewerTaxNetAmount, discount: b?.sewerTaxDiscount, advance: b?.sewerTaxAdvance,
                      payable: b?.sewerTaxPayable, deposited: paid { $0.sewerTaxPaidAmount }),
            TaxColumn(title: "अन्यकर", annualDemand: b?.otherCurrentTax, arrear: b?.otherTaxArrear,
                      interest: b?.otherTaxInterest, monthlyInterest: b?.otherTaxMonthlyInterest,
                      totalDemand: b?.othertaxNetAmount, discount: b?.otherTaxDiscount, advance: b?.otherTaxAdvance,
                      payable: b?.otherTaxPayable, deposited: paid { $0.otherTaxPaidAmount }),
        ]
    }

    // MARK: - Helpers

    private static var krutidevBase64: String = {
        guard let url = Bundle.main.url(forResource: "Kruti Dev 010 Regular", withExtension: "ttf"),
              let data = try? Data(contentsOf: url) else { return "" }
        return data.base64EncodedString()
    }()

    private static let ulbTypeInHindi: [String: String] = [
        "nagar nigam": "नगर निगम", "nn": "नगर निगम",
        "nagar palika parishad": "नगर पालिका परिषद", "npp": "नगर पालिका परिषद",
        "nagar panchayat": "नगर पंचायत", "np": "नगर पंचायत",
    ]

    private static func ulbHeading(_ ulbType: String?, _ ulbName: String?) -> String {
        let name = text(ulbName)
        let raw = ulbType?.trimmingCharacters(in: .whitespaces) ?? ""
        let type = ulbTypeInHindi[raw.lowercased()] ?? raw
        if type.isEmpty { return name }
        if name == "-" { return type }
        return "\(type), \(name)"
    }

    private static func hasReceiptNo(_ r: ReceiptDetailsItem) -> Bool {
        guard let n = r.receiptNo?.trimmingCharacters(in: .whitespaces) else { return false }
        return !n.isEmpty && n != "-" && n != "null"
    }

    static func text(_ value: String?) -> String {
        guard let t = value?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, t != "null" else { return "-" }
        return t
    }

    private static func esc(_ v: String) -> String {
        v.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func number(_ v: String?) -> Double { Double(v?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0 }
    static func amount(_ v: String?) -> String { String(format: "%.2f", number(v)) }
    private static func sum(_ values: [String?]) -> Double { values.reduce(0) { $0 + number($1) } }

    private static func grouped(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    private static func bookNo(_ v: String?) -> String { text(v) == "-" ? "" : text(v) }

    static func maskMobile(_ mobile: String?) -> String { PropertySelectionViewController.maskMobile(mobile) }

    // MARK: - Fallback (plain label/value sheet)

    private static func fallbackDocument(propertyId: String, bill: BillDetails?, owner: OwnerDetails?,
                                         property: PropertyInfo?, isKrutidev: Bool) -> Data {
        let pdf = PDFComposer(margin: 32)
        let bold = UIFont.boldSystemFont(ofSize: 12)
        func row(_ l: String, _ v: String, language: Bool = false) -> [PDFComposer.Cell] {
            [PDFComposer.Cell(l, color: PdfColors.grey700, padding: 3),
             PDFComposer.Cell(v, font: language && isKrutidev ? .krutidev(12) : bold, padding: 3)]
        }
        pdf.box("Property Tax Bill", font: .boldSystemFont(ofSize: 22), padding: 0)
        pdf.spacer(4)
        pdf.box("Property ID: \(propertyId)", font: .systemFont(ofSize: 12), color: PdfColors.grey700, padding: 0)
        pdf.spacer(16)
        pdf.line(color: .black, thickness: 1.5)
        pdf.spacer(10)
        pdf.box("Property Information", font: .boldSystemFont(ofSize: 15), alignment: .left, padding: 0)
        pdf.table([row("Zone Name", text(property?.zoneName)), row("Ward Name", text(property?.wardName)),
                   row("Mohalla Name", text(property?.mohallaName)), row("House No.", text(property?.houseNo)),
                   row("Address", text(property?.address), language: true)], flex: [3, 4], borderColor: .clear)
        pdf.spacer(12)
        pdf.box("Owner Information", font: .boldSystemFont(ofSize: 15), alignment: .left, padding: 0)
        pdf.table([row("Owner Name", text(owner?.ownerName), language: true),
                   row("Father Name", text(owner?.fatherName), language: true),
                   row("Mobile No.", maskMobile(owner?.mobileNo))], flex: [3, 4], borderColor: .clear)
        pdf.spacer(12)
        pdf.box("Tax Summary", font: .boldSystemFont(ofSize: 15), alignment: .left, padding: 0)
        pdf.table([row("Bill Date", text(bill?.billDate)), row("Bill Number", text(bill?.billNo)),
                   row("Financial Year", text(bill?.finYear)),
                   row("House Tax Payable", "Rs. \(amount(bill?.houseTaxPayable))"),
                   row("Water Tax Payable", "Rs. \(amount(bill?.waterTaxPayable))"),
                   row("Water Charge Payable", "Rs. \(amount(bill?.waterChargePayable))"),
                   row("Sewer Tax Payable", "Rs. \(amount(bill?.sewerTaxPayable))"),
                   row("Other Tax Payable", "Rs. \(amount(bill?.otherTaxPayable))")], flex: [3, 4], borderColor: .clear)
        pdf.spacer(14)
        pdf.table([[PDFComposer.Cell("Grand Total", font: .boldSystemFont(ofSize: 15), padding: 12),
                    PDFComposer.Cell("Rs. \(amount(bill?.netPayble))", font: .boldSystemFont(ofSize: 15),
                                     alignment: .right, padding: 12)]], flex: [1, 1], borderColor: .black, borderWidth: 1.5)
        return pdf.render()
    }
}

/// Renders an HTML string to A4 PDF pages via an off-screen `WKWebView`.
@MainActor
final class HTMLPDFRenderer: NSObject, WKNavigationDelegate {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Data?, Never>?
    private let margin: CGFloat
    private static var active: Set<HTMLPDFRenderer> = []

    private init(margin: CGFloat) { self.margin = margin }

    static func render(html: String, margin: CGFloat) async -> Data? {
        let renderer = HTMLPDFRenderer(margin: margin)
        active.insert(renderer)
        defer { active.remove(renderer) }
        return await withCheckedContinuation { c in
            renderer.continuation = c
            let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842))
            web.navigationDelegate = renderer
            renderer.webView = web
            web.loadHTMLString(html, baseURL: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: pageRect.insetBy(dx: margin, dy: margin)), forKey: "printableRect")
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, pageRect, nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        for page in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        finish(renderer.numberOfPages > 0 ? data as Data : nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(nil) }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(nil)
    }

    private func finish(_ data: Data?) {
        continuation?.resume(returning: data)
        continuation = nil
        webView = nil
    }
}
