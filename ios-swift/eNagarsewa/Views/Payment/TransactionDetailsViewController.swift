import UIKit

/// Port of lib/transaction_details_screen.dart — receipt card with Share (PDF) and Download (print).
final class TransactionDetailsViewController: BaseViewController {

    override var screenBackground: UIColor { UIColor(argb: 0xFFF0F2F5) }

    private let txn: TransactionData
    private var isKrutidev = false
    private var shareButton: UIView!
    private var downloadButton: UIView!
    private let receiptContainer = UIView()

    init(transaction: TransactionData) {
        self.txn = transaction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var status: String { txn.transactionStatus?.uppercased() ?? "" }
    private var statusText: String { status.isEmpty ? "UNKNOWN" : status }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Receipt", background: screenBackground, titleColor: .black87,
                     rightItems: [helpItem { [weak self] in self?.startTour() }])
        if let back = navigationItem.leftBarButtonItems?.first {
            back.image = .symbol("xmark", size: 18, weight: .semibold)
        }

        let share = actionButton("Share Receipt", icon: "square.and.arrow.up", outlined: false) { [weak self] in self?.shareReceipt() }
        let download = actionButton("Download", icon: "arrow.down.circle", outlined: true) { [weak self] in self?.downloadReceipt() }
        shareButton = share
        downloadButton = download
        let buttons = UIStackView.h(16, alignment: .fill, [share, download])
        buttons.distribution = .fillEqually

        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 40, right: 16))
        contentStack.add(receiptContainer)
        contentStack.addSpacer(24)
        contentStack.add(buttons)
        renderReceipt()

        Task {
            isKrutidev = UlbLanguageHelper.isKrutidevValue(await resolveUlbLang())
            renderReceipt()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        TourGuide.autoStartIfFirstVisit(.transactionDetails) { startTour() }
    }

    // MARK: - Language (the transaction's own property, not the app-wide cache)

    private func resolveUlbLang() async -> String? {
        let propertyId = txn.propertyId ?? ""
        let property = propertyId.isEmpty ? nil : await DatabaseService.shared.getPropertyById(propertyId)
        if let lang = property?.ulbLang, !lang.trimmingCharacters(in: .whitespaces).isEmpty { return lang }
        return await fetchUlbLangFromApi(propertyId, ulbId: property?.ulbId ?? txn.ulbId, ulbName: txn.ulbName)
    }

    /// propertysearch lookup only for the language — nothing is saved.
    private func fetchUlbLangFromApi(_ propertyId: String, ulbId: String?, ulbName: String?) async -> String? {
        guard !propertyId.isEmpty else { return nil }
        var resolved = ulbId ?? ""
        if resolved.isEmpty, let name = ulbName?.trimmingCharacters(in: .whitespaces).lowercased(), !name.isEmpty {
            resolved = (try? await APIService.shared.getUlbData())?
                .first { ($0.ulbName?.trimmingCharacters(in: .whitespaces).lowercased() ?? "") == name }?.ulbId ?? ""
        }
        let results = (try? await APIService.shared.searchProperty(ulbId: resolved, searchType: "PROPERTY",
                                                                   propertyId: propertyId)) ?? []
        return results.first { $0.propertyId == propertyId }?.ulbLang
    }

    // MARK: - Receipt card

    private static func display(_ value: String?) -> String {
        guard let t = value?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, t.lowercased() != "null" else { return "-" }
        return t
    }

    private var ulbLabel: String {
        let parts = [txn.ulbName, txn.ulbType].compactMap { $0 }
        return parts.isEmpty ? "" : ", " + parts.joined(separator: " ")
    }

    private var statusMessage: String {
        let pid = txn.propertyId ?? "N/A"
        return status == "SUCCESS"
            ? "Payment for Property Tax Successful for Property ID. [ \(pid) ]\(ulbLabel)"
            : "Payment \(statusText) for Property ID. [ \(pid) ]\(ulbLabel)"
    }

    private var rows: [(label: String, value: String, language: Bool)] {
        [
            ("ULB Name", Self.display(txn.ulbName), false),
            ("ULB Type", Self.display(txn.ulbType), false),
            ("Financial Year", Self.display(txn.financialYear), false),
            ("Transaction Number", Self.display(txn.txnId), false),
            ("Bill No", Self.display(txn.billNo), false),
            ("Property ID", Self.display(txn.propertyId), false),
            ("Transaction Date", Self.display(txn.dateTime), false),
            ("Payment Status", statusText, false),
            ("Payment Mode", Self.display(txn.paymentMode), false),
            ("Bank Ref No", Self.display(txn.bankRefNo), false),
            ("User Code", Self.display(txn.userCode), false),
            ("Owner Name", Self.display(txn.ownerName), true),
            ("Father/Husband Name", Self.display(txn.fatherName), true),
            ("Address", Self.display(txn.address), true),
            ("Payment Amount(Rs.)", Self.display(txn.paymentAmount), false),
            ("Mobile Number", Self.display(txn.mobileNo), false),
            ("Receipt No", Self.display(txn.receiptNo), false),
        ]
    }

    private func renderReceipt() {
        receiptContainer.subviews.forEach { $0.removeFromSuperview() }
        let statusColor: UIColor
        switch status {
        case "SUCCESS": statusColor = UIColor(argb: 0xFF4CAF50)
        case "PENDING": statusColor = UIColor(argb: 0xFFE6A23C)
        case "FAILED":  statusColor = .mRed
        default:        statusColor = UIColor(argb: 0xFF64748B)
        }
        let green = UIColor(argb: 0xFF4CAF50)

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 8
        card.addShadow(opacity: 0.08, blur: 12, offsetY: 4)
        let stack = UIStackView.v(0, [])
        let inner = UIView()
        inner.layer.cornerRadius = 8
        inner.clipsToBounds = true
        inner.addSubview(stack)
        stack.pinToEdges(of: inner)
        card.addSubview(inner)
        inner.pinToEdges(of: card)

        let header = UILabel("Property Tax Property ID. [ \(txn.propertyId ?? "N/A") ]", font: .poppins(14, .bold),
                             color: .appTextDark, lines: 0, alignment: .center)
        let headerBox = header.padded(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        headerBox.backgroundColor = UIColor(argb: 0xFFF5F5F5)
        stack.add(headerBox, divider(color: green, thickness: 2))

        let pill = UIView()
        pill.backgroundColor = statusColor.withAlphaComponent(0.1)
        pill.layer.cornerRadius = 12
        pill.addBorder(color: statusColor)
        let pillLabel = UILabel(statusText, font: .poppins(12, .bold), color: statusColor)
        pill.addSubview(pillLabel)
        pillLabel.pinToEdges(of: pill, insets: UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12))
        let statusBox = UIStackView.v(6, alignment: .center, [
            pill, UILabel(statusMessage, font: .poppins(12, .medium), color: statusColor, lines: 0, alignment: .center),
        ]).padded(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
        statusBox.backgroundColor = UIColor(argb: 0xFFFAFAFA)
        stack.add(statusBox, divider(color: green, thickness: 1))

        for row in rows {
            stack.add(receiptRow(row.label, row.value, krutidev: row.language && isKrutidev))
        }

        let footer = UIStackView.v(4, [
            UILabel("This is Computer Generated Receipt. It does not require a signature.", font: .poppins(11),
                    color: .appTextLabel, lines: 0, alignment: .center),
            italicLabel("This receipt is printed through EODB, eNagarSewa portal GoUP."),
        ]).padded(UIEdgeInsets(top: 16, left: 20, bottom: 28, right: 20))
        footer.backgroundColor = UIColor(argb: 0xFFF5F5F5)
        stack.add(divider(color: green, thickness: 2), footer)

        receiptContainer.addSubview(card)
        card.pinToEdges(of: receiptContainer)
    }

    private func italicLabel(_ text: String) -> UILabel {
        let l = UILabel(text, font: .poppins(11), color: .appTextLabel, lines: 0, alignment: .center)
        let descriptor = UIFont.poppins(11).fontDescriptor.withSymbolicTraits(.traitItalic)
        l.font = descriptor.map { UIFont(descriptor: $0, size: 11) } ?? .italicSystemFont(ofSize: 11)
        return l
    }

    private func receiptRow(_ label: String, _ value: String, krutidev: Bool) -> UIView {
        let labelBox = UILabel(label, font: .poppins(12, .medium), color: .appTextMid, lines: 0)
            .padded(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        labelBox.backgroundColor = UIColor(argb: 0xFFFAFAFA)
        labelBox.setSize(width: 150)
        let valueBox = UILabel(value, font: UlbLanguageHelper.font(12, .semibold, krutidev: krutidev),
                               color: UIColor(argb: 0xFF222222), lines: 0)
            .padded(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        let sep = UIView()
        sep.backgroundColor = UIColor(argb: 0xFFE0E0E0)
        sep.setSize(width: 0.5)
        let row = UIStackView.h(0, alignment: .fill, [labelBox, sep, valueBox])
        return UIStackView.v(0, [row, divider(color: UIColor(argb: 0xFFE0E0E0), thickness: 0.5)])
    }

    private func actionButton(_ title: String, icon: String, outlined: Bool, action: @escaping () -> Void) -> UIView {
        let navy = UIColor(argb: 0xFF0E3B90)
        let b = PrimaryButton(title, color: outlined ? .white : navy, height: 54, radius: 16, fontSize: 14, icon: icon)
        if outlined {
            b.setTitleColor(navy, for: .normal)
            b.tintColor = navy
            b.layer.borderWidth = 1.5
            b.layer.borderColor = navy.cgColor
        } else {
            let wrapper = UIView()
            wrapper.addShadow(opacity: 0.2, blur: 8, offsetY: 4)
            wrapper.addSubview(b)
            b.pinToEdges(of: wrapper)
            b.onEvent(action)
            return wrapper
        }
        b.onEvent(action)
        return b
    }

    // MARK: - PDF

    private func buildPdf() async -> Data {
        let lang = await resolveUlbLang()
        let krutidev = UlbLanguageHelper.isKrutidevValue(lang)
        let regular = UIFont.systemFont(ofSize: 11)
        let bold = UIFont.boldSystemFont(ofSize: 11)
        let pdf = PDFComposer()
        let isSuccess = status == "SUCCESS"
        pdf.box("Property Tax Property ID. [ \(txn.propertyId ?? "N/A") ]", font: .boldSystemFont(ofSize: 14),
                padding: 10, background: PdfColors.grey200,
                border: .init(bottom: (PdfColors.green, 2)))
        pdf.box(statusMessage, font: regular, color: isSuccess ? PdfColors.green : PdfColors.red, padding: 8)
        pdf.line(color: PdfColors.green, thickness: 2)
        let pdfRows = rows.map { row -> [PDFComposer.Cell] in
            [PDFComposer.Cell(row.label == "Property ID" ? "Property ID." : row.label, font: regular, background: PdfColors.grey100),
             PDFComposer.Cell(row.value, font: row.language && krutidev ? .krutidev(11) : bold)]
        }
        pdf.table(pdfRows, flex: [2, 3], borderColor: PdfColors.grey300)
        let italic = UIFont.italicSystemFont(ofSize: 10)
        pdf.boxLines([
            PDFComposer.attributed("This is Computer Generated Receipt. It does not require a signature.",
                                   font: .systemFont(ofSize: 10), alignment: .center),
            PDFComposer.attributed("This receipt is printed through EODB, eNagarSewa portal GoUP.", font: italic, alignment: .center),
        ], spacing: 4, padding: 12, background: PdfColors.grey200, border: .init(top: (PdfColors.green, 2)))
        return pdf.render()
    }

    private func shareReceipt() {
        guard !TourCoachMarkView.isActive else { return }
        Task {
            let data = await buildPdf()
            DocumentActions.share(data, fileName: "receipt_\(txn.txnId ?? "payment").pdf",
                                  text: "Payment Receipt - Property ID: \(txn.propertyId ?? "")", from: self,
                                  sourceView: shareButton)
        }
    }

    private func downloadReceipt() {
        guard !TourCoachMarkView.isActive else { return }
        Task {
            let data = await buildPdf()
            DocumentActions.print(data, jobName: "receipt_\(txn.txnId ?? "").pdf")
        }
    }

    // MARK: - Tour

    private func startTour() {
        guard !TourCoachMarkView.isActive else { return }
        TourCoachMarkView.present(steps: [
            TourStep(target: shareButton, icon: "square.and.arrow.up", title: "Share Receipt",
                     description: "Use this button to share the current receipt as an image with other apps.",
                     shape: .roundedRect(radius: 16), edge: .top),
            TourStep(target: downloadButton, icon: "arrow.down.circle", title: "Download Receipt",
                     description: "Use this button to export or print the receipt as a PDF file.",
                     shape: .roundedRect(radius: 16), edge: .top),
        ], scrollContainer: scrollView)
    }
}
