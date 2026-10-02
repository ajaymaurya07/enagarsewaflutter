import UIKit

/// Port of lib/payment_history_screen.dart ("Receipt Details" for one property).
final class PaymentHistoryViewController: BaseViewController {

    override var screenBackground: UIColor { .appFieldFill }

    private let propertyId: String
    private let currReceipts: [ReceiptDetailsItem]
    private let prevReceipts: [ReceiptDetailsItem]
    private let owner: OwnerDetails?
    private let property: PropertyInfo?
    private var ulbName: String?
    private var ulbType: String?
    private var isKrutidev = false
    private let stateView = UIView()

    init(propertyId: String, currReceipts: [ReceiptDetailsItem], prevReceipts: [ReceiptDetailsItem],
         owner: OwnerDetails?, property: PropertyInfo?) {
        self.propertyId = propertyId
        self.currReceipts = currReceipts
        self.prevReceipts = prevReceipts
        self.owner = owner
        self.property = property
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: nil, titleColor: .appTextDark, centerTitle: false)
        let title = UIStackView.v(0, [
            UILabel("Receipt Details", font: .poppins(18, .bold), color: .appTextDark),
            UILabel("PID: \(propertyId)", font: .poppins(12, .medium), color: .grey600),
        ])
        navigationItem.leftBarButtonItems?.append(UIBarButtonItem(customView: title))
        let line = divider(color: .grey200)
        view.addSubview(line)
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            line.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), spacing: 14, below: line)
        view.addSubview(stateView)
        stateView.backgroundColor = screenBackground
        stateView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stateView.topAnchor.constraint(equalTo: line.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        Task { await loadUlbInfo() }
    }

    private func showState(_ content: UIView?) {
        stateView.subviews.forEach { $0.removeFromSuperview() }
        stateView.isHidden = content == nil
        guard let content else { return }
        stateView.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.centerYAnchor.constraint(equalTo: stateView.centerYAnchor),
            content.leadingAnchor.constraint(equalTo: stateView.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: stateView.trailingAnchor, constant: -24),
        ])
    }

    private func loadUlbInfo() async {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .appPrimary
        spinner.startAnimating()
        showState(centered(spinner))
        let entity = await DatabaseService.shared.getPropertyById(propertyId)
        isKrutidev = UlbLanguageHelper.isKrutidevValue(entity?.ulbLang)
        guard let ulbId = entity?.ulbId, !ulbId.isEmpty else {
            showError("ULB details not found for this property.")
            return
        }
        do {
            guard let match = try await APIService.shared.getUlbData().first(where: { $0.ulbId == ulbId }) else {
                showError("ULB details not found for this property.")
                return
            }
            ulbName = match.ulbName
            ulbType = match.ulbType
            render()
        } catch {
            showError(APIError.userMessage(error, fallback: "Unable to load ULB details. Please try again."))
        }
    }

    private func showError(_ message: String) {
        let retry = PrimaryButton("Retry", height: 40, radius: 20, fontSize: 14, weight: .medium)
        retry.contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        retry.onEvent { [weak self] in Task { await self?.loadUlbInfo() } }
        let stack = UIStackView.v(0, alignment: .center, [
            UIImageView(symbol: "exclamationmark.circle", size: 56, color: .mRed),
            UILabel(message, font: .poppins(14), color: .black87, lines: 0, alignment: .center),
            retry,
        ])
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[0])
        stack.setCustomSpacing(24, after: stack.arrangedSubviews[1])
        showState(stack)
    }

    private static func hasValidBillNo(_ r: ReceiptDetailsItem) -> Bool {
        guard let b = r.billNo?.trimmingCharacters(in: .whitespaces) else { return false }
        return !b.isEmpty && b != "-"
    }

    private func render() {
        showState(nil)
        contentStack.removeAllArranged()
        let curr = currReceipts.filter(Self.hasValidBillNo)
        let all = curr + prevReceipts.filter(Self.hasValidBillNo)
        if all.isEmpty {
            let empty = UIStackView.v(12, alignment: .center, [
                UIImageView(symbol: "doc.text", size: 56, color: .grey400),
                UILabel("No current receipt details found", font: .poppins(15), color: .grey600),
            ])
            contentStack.add(empty.padded(UIEdgeInsets(top: 60, left: 0, bottom: 60, right: 0)))
            return
        }
        for (i, receipt) in all.enumerated() {
            contentStack.add(card(receipt, isCurrent: i < curr.count))
        }
    }

    // MARK: - Card

    private func rows(_ r: ReceiptDetailsItem, isCurrent: Bool, forPdf: Bool) -> [(String, String, Bool, Bool)] {
        var rows: [(String, String, Bool, Bool)] = []   // label, value, languageSensitive, isAmount
        func add(_ label: String, _ value: String?, language: Bool = false, amount: Bool = false) {
            guard let value, !value.isEmpty, value != "null" else { return }
            if forPdf && value == "-" { return }
            rows.append((label, amount ? "₹ \(value)" : value, language, amount))
        }
        if isCurrent, let owner {
            add("Owner Name", owner.ownerName, language: true)
            add("Father/Husband Name", owner.fatherName, language: true)
        }
        if isCurrent {
            add("ULB Name", ulbName)
            add("ULB Type", ulbType)
        }
        if isCurrent, let property {
            add("Zone", property.zoneName)
            add("Ward", property.wardName)
            add("Mohalla", property.mohallaName)
            add("House Number", property.houseNo)
            add("Address", property.address, language: true)
        }
        add("Bill Number", r.billNo)
        add("Receipt No", r.receiptNo)
        add("Receipt Date", r.receiptDate)
        add("Payment Mode", r.paymentMode)
        add("Property Tax Paid", r.propertyTaxPaidAmount, amount: true)
        add("Water Tax Paid", r.waterTaxPaidAmount, amount: true)
        add("Sewer Tax Paid", r.sewerTaxPaidAmount, amount: true)
        add("Other Tax Paid", r.otherTaxPaidAmount, amount: true)
        add("Water Charge Paid", r.waterChargePaidAmount, amount: true)
        return rows
    }

    private func card(_ r: ReceiptDetailsItem, isCurrent: Bool) -> UIView {
        let card = CardView(radius: 16, padding: .zero, shadowOpacity: 0.04, shadowBlur: 12, shadowY: 4)
        let inner = UIStackView.v(0, [])
        let clip = UIView()
        clip.layer.cornerRadius = 16
        clip.clipsToBounds = true
        clip.addSubview(inner)
        inner.pinToEdges(of: clip)
        card.stack.add(clip)

        let tint = isCurrent ? UIColor.mGreen700 : .mOrange800
        let header = UIStackView.h(8, [
            UIImageView(symbol: "doc.plaintext", size: 16, color: tint),
            UILabel(isCurrent ? "Current Year" : "Previous Year", font: .poppins(13, .semibold), color: tint),
            FlexSpacer(),
            UILabel(r.receiptDate ?? "", font: .poppins(12, .medium), color: isCurrent ? .mGreen600 : .mOrange700),
        ]).padded(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        header.backgroundColor = isCurrent ? UIColor(argb: 0xFFE8F5E9) : UIColor(argb: 0xFFFFF3E0)
        inner.add(header)

        let body = UIStackView.v(0, [])
        for (label, value, language, amount) in rows(r, isCurrent: isCurrent, forPdf: false) {
            let l = UILabel(label, font: .poppins(13, .medium), color: .grey600, lines: 0)
            let krutidev = language && isKrutidev
            let v = UILabel(value, font: UlbLanguageHelper.font(13, .semibold, krutidev: krutidev),
                            color: amount && !krutidev ? UIColor(argb: 0xFF0E3B90) : .appTextMid, lines: 0, alignment: .right)
            let row = UIStackView.h(0, alignment: .top, [l, v])
            row.distribution = .fillEqually
            body.add(row.padded(UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)))
        }
        inner.add(body.padded(16))

        let navy = UIColor(argb: 0xFF0E3B90)
        let download = actionItem("arrow.down.to.line", "Download", navy) { [weak self] in self?.download(r, isCurrent: isCurrent) }
        let share = actionItem("square.and.arrow.up", "Share", .appPrimary) { [weak self] in self?.share(r, isCurrent: isCurrent) }
        let sep = UIView()
        sep.backgroundColor = .grey200
        sep.setSize(width: 1, height: 40)
        let actions = UIStackView.h(0, alignment: .center, [download, sep, share])
        download.widthAnchor.constraint(equalTo: share.widthAnchor).isActive = true
        inner.add(divider(color: .grey200), actions)
        return card
    }

    private func actionItem(_ icon: String, _ title: String, _ color: UIColor, action: @escaping () -> Void) -> UIView {
        let v = UIView()
        let row = UIStackView.h(6, [UIImageView(symbol: icon, size: 16, color: color),
                                    UILabel(title, font: .poppins(13, .semibold), color: color)])
        v.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            row.topAnchor.constraint(equalTo: v.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -14),
        ])
        v.onTap(action)
        return v
    }

    // MARK: - PDF

    private func buildPdf(_ r: ReceiptDetailsItem, isCurrent: Bool) -> Data {
        let pdf = PDFComposer()
        pdf.box("Property Tax Property ID. [ \(propertyId) ]", font: .boldSystemFont(ofSize: 14), padding: 10,
                background: PdfColors.grey200, border: .init(bottom: (PdfColors.green, 2)))
        pdf.box(isCurrent ? "Current Year Receipt for Property ID. [ \(propertyId) ]"
                          : "Previous Year Receipt for Property ID. [ \(propertyId) ]",
                font: .systemFont(ofSize: 11), color: PdfColors.green, padding: 8)
        pdf.line(color: PdfColors.green, thickness: 2)
        let cells = rows(r, isCurrent: isCurrent, forPdf: true).map { row -> [PDFComposer.Cell] in
            [PDFComposer.Cell(row.0, font: .systemFont(ofSize: 11), background: PdfColors.grey100),
             PDFComposer.Cell(row.1, font: row.2 && isKrutidev ? .krutidev(11) : .boldSystemFont(ofSize: 11))]
        }
        pdf.table(cells, flex: [2, 3], borderColor: PdfColors.grey300)
        pdf.boxLines([
            PDFComposer.attributed("This is Computer Generated Receipt. It does not require a signature.",
                                   font: .systemFont(ofSize: 10), alignment: .center),
            PDFComposer.attributed("This receipt is printed through EODB, eNagarSewa portal GoUP.",
                                   font: .italicSystemFont(ofSize: 10), alignment: .center),
        ], spacing: 4, padding: 12, background: PdfColors.grey200, border: .init(top: (PdfColors.green, 2)))
        return pdf.render()
    }

    private func download(_ r: ReceiptDetailsItem, isCurrent: Bool) {
        DocumentActions.print(buildPdf(r, isCurrent: isCurrent),
                              jobName: "receipt_\(r.receiptNo ?? r.billNo ?? "payment").pdf")
    }

    private func share(_ r: ReceiptDetailsItem, isCurrent: Bool) {
        DocumentActions.share(buildPdf(r, isCurrent: isCurrent), fileName: "receipt_\(r.receiptNo ?? "payment").pdf",
                              text: "Payment Receipt - Property ID: \(propertyId)", from: self)
    }
}
