import UIKit

/// Port of lib/payment_details_screen.dart.
final class PaymentDetailsViewController: BaseViewController {

    override var hidesNavigationBar: Bool { true }
    override var screenBackground: UIColor { .grey100 }

    private let propertyId: String
    private var details: PropertyDetailsData?
    private var isKrutidev = false
    private var ulbName: String?
    private var ulbType: String?
    private var showPropertyDetails = false

    private let body = UIView()
    private var payButton: UIView?
    private var printButton: UIView?
    private var grievanceButton: UIView?
    private var receiptsButton: UIView?

    init(propertyId: String) {
        self.propertyId = propertyId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let back = iconButton("chevron.backward", color: .appPrimary, size: 18) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        let titles = UIStackView.v(0, [
            UILabel("Payment Details", font: .poppins(18, .bold), color: .appTextDark),
            UILabel("PID: \(propertyId)", font: .poppins(12, .medium), color: .grey600),
        ])
        let help = iconButton("questionmark.circle", color: .appPrimary) { [weak self] in self?.handleTourTap() }
        let header = UIStackView.h(4, [back, titles, FlexSpacer(), help])
        view.addSubview(header)
        header.translatesAutoresizingMaskIntoConstraints = false
        body.backgroundColor = .white
        view.addSubview(body)
        body.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            body.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            body.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16), below: header)
        scrollView.backgroundColor = .white

        Task { await fetchDetails() }
        Task {
            isKrutidev = UlbLanguageHelper.isKrutidevValue(await DatabaseService.shared.getPropertyById(propertyId)?.ulbLang)
            if details != nil { render() }
        }
        Task { await loadUlbInfo() }
    }

    // MARK: - Loading

    private var isBusy = false {
        didSet { setLoading(isBusy) }
    }

    private func loadUlbInfo() async {
        guard let ulbId = await DatabaseService.shared.getPropertyById(propertyId)?.ulbId, !ulbId.isEmpty,
              let match = try? await APIService.shared.getUlbData().first(where: { $0.ulbId == ulbId }) else { return }
        ulbName = match.ulbName
        ulbType = match.ulbType
    }

    private func fetchDetails() async {
        isBusy = true
        do {
            let response = try await APIService.shared.getPropertyDetails(propertyId: propertyId)
            if response.success == true, let data = response.data {
                await cacheBillInfo(data)
                details = data
                isBusy = false
                render()
                TourGuide.autoStartIfFirstVisit(.paymentDetails) { startTour() }
            } else {
                isBusy = false
                showError(response.message ?? "Failed to load details")
            }
        } catch {
            isBusy = false
            showError(APIError.userMessage(error, fallback: "Unable to load payment details right now. Please try again."))
        }
    }

    /// Caches bill date + net payable for the dashboard card and refreshes stale owner data.
    private func cacheBillInfo(_ data: PropertyDetailsData) async {
        let db = DatabaseService.shared
        await db.updatePropertyBillInfo(propertyId: propertyId, billDate: data.billDetails?.billDate,
                                        netPayable: data.billDetails?.netPayble)
        guard let existing = await db.getPropertyById(propertyId) else { return }
        func changed(_ fresh: String?, _ old: String?) -> String? {
            guard let f = fresh?.trimmingCharacters(in: .whitespacesAndNewlines), Self.hasValue(f), f != old else { return nil }
            return f
        }
        let owner = changed(data.ownerDetails?.ownerName, existing.ownerName)
        let father = changed(data.ownerDetails?.fatherName, existing.fatherName)
        let address = changed(data.propertyDetailsInfo?.address, existing.address)
        let arv = changed(data.propertyDetailsInfo?.arv, existing.arvValue)
        guard owner != nil || father != nil || address != nil || arv != nil else { return }
        await db.updatePropertyDetailsInfo(propertyId: propertyId, ownerName: owner, fatherName: father,
                                           address: address, arvValue: arv)
    }

    private static func hasValue(_ v: String?) -> Bool {
        guard let t = v?.trimmingCharacters(in: .whitespaces) else { return false }
        return !t.isEmpty && t != "null" && t != "-"
    }

    private static func number(_ v: String?) -> Double { Double(v?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0 }

    private func showError(_ message: String) {
        contentStack.removeAllArranged()
        let retry = PrimaryButton("Retry", height: 40, radius: 20, fontSize: 14, weight: .medium)
        retry.contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        retry.onEvent { [weak self] in Task { await self?.fetchDetails() } }
        let stack = UIStackView.v(0, alignment: .center, [
            UIImageView(symbol: "exclamationmark.circle", size: 56, color: .mRed),
            UILabel(message, font: .poppins(14), color: .black87, lines: 0, alignment: .center),
            retry,
        ])
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[0])
        stack.setCustomSpacing(24, after: stack.arrangedSubviews[1])
        contentStack.add(stack.padded(UIEdgeInsets(top: 120, left: 8, bottom: 0, right: 8)))
    }

    // MARK: - Content

    private func render() {
        guard let details else { return }
        contentStack.removeAllArranged()
        let bill = details.billDetails

        // 1. Tax summary
        let summary = CardView(radius: 20, padding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
                               shadowOpacity: 0.04, shadowBlur: 20, shadowY: 10)
        summary.stack.add(UIStackView.h(12, [
            iconTile("list.bullet.rectangle.portrait", size: 36, iconSize: 18, radius: 8),
            UILabel("Tax Summary", font: .poppins(17, .bold), color: .appTextDark),
        ]))
        summary.stack.addSpacer(18)
        let s = summary.stack
        s.add(summaryRow("Bill Date", bill?.billDate))
        s.add(summaryRow("Bill Number", bill?.billNo))
        s.add(summaryRow("Financial Year", bill?.finYear))
        let arvRow = summaryRow("Total Arv", "0.0")
        s.add(arvRow)
        Task {
            let arv = await DatabaseService.shared.getPropertyById(propertyId)?.arvValue ?? "0.0"
            (arvRow.viewWithTag(77) as? UILabel)?.text = arv
        }
        s.add(divider(color: UIColor.Scheme.outlineVariant, thickness: 0.8).padded(UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)))
        s.add(summaryRow("House Tax Net Amount", bill?.houseTaxNetAmount))
        s.add(summaryRow("Water Tax Net Amount", bill?.waterTaxNetAmount))
        s.add(summaryRow("Sewer Tax Net Amount", bill?.sewerTaxNetAmount))
        s.add(summaryRow("Other Tax Net Amount", bill?.othertaxNetAmount))
        s.add(summaryRow("Water Charge Net Amount", bill?.waterChargeNetAmount))
        s.add(summaryRow("Net Demand", bill?.netDemand))
        let advance = [bill?.houseTaxAdvance, bill?.waterTaxAdvance, bill?.sewerTaxAdvance, bill?.otherTaxAdvance,
                       bill?.waterChargeAdvance].reduce(0.0) { $0 + (Double($1 ?? "0") ?? 0) }
        s.add(summaryRow("Total Advance Tax Pay", String(format: "%.2f", advance)))
        s.addSpacer(20)
        let net = UIStackView.h(8, [
            UILabel("Net Payable", font: .poppins(16, .bold), color: .appPrimary), FlexSpacer(),
            UILabel("₹ \(bill?.netPayble ?? "0.0")", font: .poppins(20, .extraBold), color: .appPrimary),
        ]).padded(16)
        net.backgroundColor = .appPrimaryLight
        net.layer.cornerRadius = 12
        net.addBorder(color: .appPrimaryBorder)
        s.add(net)
        contentStack.add(summary)
        contentStack.addSpacer(20)

        // 2. Actions
        let pay = gradientButton("Pay Your Tax Online") { [weak self] in self?.handlePayTax() }
        payButton = pay
        contentStack.add(pay)
        contentStack.addSpacer(12)
        let print = secondaryButton("Print Property", icon: "printer") { [weak self] in self?.printProperty() }
        let receipts = secondaryButton("Receipt Details", icon: "creditcard") { [weak self] in self?.showPaymentHistory() }
        let grievance = secondaryButton("Apply Grievance", icon: "text.bubble") { [weak self] in
            guard let self else { return }
            self.push(ApplyGrievanceViewController(preselectedPropertyId: self.propertyId,
                                                   preselectedCategoryName: ApplyGrievanceViewController.propertyTaxCategoryName,
                                                   preselectedSubCategoryName: ApplyGrievanceViewController.assessmentSubCategoryName))
        }
        printButton = print
        receiptsButton = receipts
        grievanceButton = grievance
        let row1 = UIStackView.h(12, alignment: .fill, [print, receipts])
        row1.distribution = .fillEqually
        contentStack.add(row1)
        contentStack.addSpacer(12)
        contentStack.add(grievance)
        contentStack.addSpacer(20)

        // 3. Property details (collapsible)
        let card = CardView(radius: 20, padding: .zero, shadowOpacity: 0.04, shadowBlur: 20, shadowY: 10)
        let headerRow = UIStackView.h(8, [
            UILabel("Property Details", font: .poppins(16, .bold), color: .appTextDark), FlexSpacer(),
            UIImageView(symbol: showPropertyDetails ? "chevron.up" : "chevron.down", size: 14, color: .appPrimary, weight: .semibold),
        ]).padded(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        headerRow.onTap { [weak self] in
            guard let self else { return }
            self.showPropertyDetails.toggle()
            self.render()
        }
        card.stack.add(headerRow)
        if showPropertyDetails {
            let prop = details.propertyDetailsInfo, owner = details.ownerDetails
            let rows = UIStackView.v(0, [divider(), UIView().setSize(height: 12)])
            rows.add(summaryRow("Property/House Id", propertyId))
            rows.add(summaryRow("Zone Name", prop?.zoneName))
            rows.add(summaryRow("Ward Name", prop?.wardName))
            rows.add(summaryRow("Mohalla Name", prop?.mohallaName))
            rows.add(summaryRow("House No.", prop?.houseNo))
            rows.add(summaryRow("Property Address", prop?.address, language: true))
            rows.add(summaryRow("Owner/Occupier Name", owner?.ownerName, language: true))
            rows.add(summaryRow("Owner Mobile Number", owner?.mobileNo))
            rows.add(summaryRow("Owner Father Name", owner?.fatherName, language: true))
            card.stack.add(rows.padded(UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)))
        }
        contentStack.add(card)
    }

    private func summaryRow(_ label: String, _ value: String?, language: Bool = false) -> UIView {
        let l = UILabel(label, font: .poppins(13, .medium), color: .grey600, lines: 0)
        let v = UILabel(value ?? "N/A", font: UlbLanguageHelper.font(13, .semibold, krutidev: language && isKrutidev),
                        color: .appTextMid, lines: 0, alignment: .right)
        v.tag = 77
        let row = UIStackView.h(8, alignment: .top, [l, v])
        l.widthAnchor.constraint(equalTo: v.widthAnchor, multiplier: 0.75).isActive = true
        return row.padded(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0))
    }

    private func gradientButton(_ title: String, action: @escaping () -> Void) -> UIView {
        let container = GradientView(colors: [.appPrimary, UIColor(argb: 0xFFF0852D)])
        container.layer.cornerRadius = 16
        container.layer.shadowColor = UIColor.appPrimary.cgColor
        container.layer.shadowOpacity = 0.3
        container.layer.shadowRadius = 6
        container.layer.shadowOffset = CGSize(width: 0, height: 6)
        container.setSize(height: 56)
        let label = UILabel(title, font: .poppins(16, .bold), color: .white)
        container.addSubview(label)
        label.center(in: container)
        container.onTap(action)
        return container
    }

    private func secondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> UIView {
        let b = PrimaryButton(title, height: 50, radius: 10, fontSize: 12, weight: .semibold, icon: icon)
        b.setImage(.symbol(icon, size: 14, weight: .semibold), for: .normal)
        b.titleLabel?.lineBreakMode = .byTruncatingTail
        b.onEvent(.touchUpInside, action)
        return b
    }

    // MARK: - Pay flow

    private func handlePayTax() {
        guard !TourCoachMarkView.isActive else { return }
        let netPayable = Double(details?.billDetails?.netPayble ?? "0") ?? 0
        guard netPayable > 0 else {
            AppDialog.show(on: self, icon: "info.circle", title: "Nothing to Pay",
                           message: "You cannot proceed with payment. Net Payable amount is ₹0.",
                           actions: [.init(title: "OK")])
            return
        }
        guard let mobile = details?.ownerDetails?.mobileNo, !mobile.isEmpty else {
            snack("Mobile number not available for OTP")
            return
        }
        isBusy = true
        Task {
            do {
                let res = try await APIService.shared.sendOtp(mobileNo: mobile, propertyId: propertyId)
                isBusy = false
                if res.success == true {
                    let masked = res.maskedMobile ?? "XXXXXX" + (mobile.count > 4 ? String(mobile.suffix(4)) : mobile)
                    let sheet = PaymentOtpSheet(mobileNo: mobile, maskedNumber: masked) { [weak self] in
                        self?.showAmountSelection()
                    }
                    present(sheet, animated: true)
                } else {
                    snack(res.message ?? "Failed to send OTP")
                }
            } catch {
                isBusy = false
                snack(APIError.userMessage(error, fallback: "Unable to send OTP right now. Please try again."))
            }
        }
    }

    private func showAmountSelection() {
        let full = details?.billDetails?.netPayble ?? "0"
        let sheet = AmountSelectionSheet(fullAmount: full) { [weak self] amount in
            self?.showGatewaySelection(amount)
        }
        present(sheet, animated: true)
    }

    private func showGatewaySelection(_ amount: String) {
        let sheet = GatewaySelectionSheet(amount: amount) { [weak self] in
            self?.handlePayuTransaction()
        }
        present(sheet, animated: true)
    }

    private func buildTransactionRequest() async -> InitiateTransactionRequest {
        let entity = await DatabaseService.shared.getPropertyById(propertyId)
        let bill = details?.billDetails, owner = details?.ownerDetails
        let now = Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return InitiateTransactionRequest(
            mobileTransactionId: "MOBTXN\(Int64(now.timeIntervalSince1970 * 1000))",
            mobileTransactionTimestamp: f.string(from: now),
            billNo: bill?.billNo ?? "", propertyId: propertyId, ulbId: entity?.ulbId ?? "0",
            financialYear: bill?.finYear ?? "", ownerName: owner?.ownerName ?? "",
            fatherName: owner?.fatherName ?? "", mobileNo: owner?.mobileNo ?? "",
            propertyTax: bill?.houseTaxNetAmount ?? "0", waterTax: bill?.waterTaxNetAmount ?? "0",
            sewerTax: bill?.sewerTaxNetAmount ?? "0", otherTax: bill?.othertaxNetAmount ?? "0",
            waterCharge: bill?.waterChargeNetAmount ?? "0", netDemand: bill?.netDemand ?? "0",
            netPayable: bill?.netPayble ?? "0", totalArv: entity?.arvValue ?? "0.0",
            userId: entity?.userId ?? "0", emailId: StorageService.emailId ?? "")
    }

    private func handlePayuTransaction() {
        isBusy = true
        Task {
            do {
                let request = await buildTransactionRequest()
                let response = try await APIService.shared.initiateTransaction(request)
                isBusy = false
                guard response.status == true else {
                    snack(response.message ?? "Transaction failed")
                    return
                }
                StorageService.savePayuMobileTransactionId(request.mobileTransactionId)
                startPayuFlow(response.data)
            } catch {
                isBusy = false
                snack(APIError.userMessage(error, fallback: "Unable to create transaction right now. Please try again."))
            }
        }
    }

    private func startPayuFlow(_ txn: PayUTransaction?) {
        guard let txn else { return }
        do {
            try PayUCheckoutBridge.open(transaction: txn, from: self) { [weak self] outcome in
                self?.verifyPayment(cancelled: outcome == .cancelled)
            }
        } catch {
            snack(APIError.userMessage(error, fallback: "Unable to start PayU payment right now. Please try again."))
        }
    }

    /// Dart `_PayuDelegate._verify`: never trusts the SDK status — always cross-verifies with the server.
    private func verifyPayment(cancelled: Bool) {
        let unableMessage = cancelled
            ? "Payment Cancelled. Verification could not be completed. Please check your Bill Receipt to confirm the status."
            : "Payment verification could not be completed. Please check your Bill Receipt to confirm the status."
        let dialog = VerifyingPaymentDialog()
        topPresented.present(dialog, animated: true)
        Task {
            var result: PaymentResultViewController
            if let txnId = StorageService.payuMobileTransactionId, !txnId.isEmpty,
               let res = try? await APIService.shared.getTransactionDetails(mobileTransactionId: txnId),
               res.status == true, let data = res.data {
                StorageService.clearPayuMobileTransactionId()
                result = Self.result(from: data)
            } else {
                result = PaymentResultViewController(status: .pending, message: unableMessage)
            }
            dialog.dismiss(animated: true) { [weak self] in
                guard let self, let nav = self.navigationController else { return }
                var stack = nav.viewControllers
                if let i = stack.lastIndex(of: self) { stack.remove(at: i) }
                stack.append(result)
                nav.setViewControllers(stack, animated: true)
            }
        }
    }

    private static func result(from d: PayUTransactionDetails) -> PaymentResultViewController {
        let status: PaymentStatus
        switch d.paymentStatus?.uppercased() ?? "" {
        case "SUCCESS": status = .success
        case "FAILED": status = .failure
        default: status = .pending
        }
        var details: [(String, String)] = []
        func add(_ k: String, _ v: String?) { if let v, !v.isEmpty { details.append((k, v)) } }
        func addAmt(_ k: String, _ v: String?) {
            if let v, !v.isEmpty, v != "0.00", v != "0" { details.append((k, "₹ \(v)")) }
        }
        add("Bill No", d.billNo)
        add("Property ID", d.propertyId)
        add("Financial Year", d.financialYear)
        add("Payment Mode", d.paymentMode)
        add("Owner Name", d.ownerName)
        add("Mobile", d.mobileNo)
        addAmt("Property Tax", d.propertyTaxPaid)
        addAmt("Water Tax", d.waterTaxPaid)
        addAmt("Sewer Tax", d.sewerTaxPaid)
        addAmt("Other Tax", d.otherTaxPaid)
        addAmt("Water Charge", d.waterChargePaid)
        return PaymentResultViewController(status: status, txnId: d.txnid, amount: d.netPayable, details: details)
    }

    // MARK: - Other actions

    private func showPaymentHistory() {
        guard !TourCoachMarkView.isActive else { return }
        push(PaymentHistoryViewController(propertyId: propertyId, currReceipts: details?.currReceiptDetails ?? [],
                                          prevReceipts: details?.prevReceiptDetails ?? [],
                                          owner: details?.ownerDetails, property: details?.propertyDetailsInfo))
    }

    /// Fills a missing ARV from propertysearch before printing so the bill doesn't show 0.00.
    private func cacheArvIfMissing(_ property: PropertyEntity?) async -> PropertyEntity? {
        guard let property, let ulbId = property.ulbId, !ulbId.isEmpty else { return property }
        if Self.hasValue(property.arvValue), Self.number(property.arvValue) > 0 { return property }
        guard let results = try? await APIService.shared.searchProperty(ulbId: ulbId, searchType: "PROPERTY",
                                                                        propertyId: propertyId),
              let match = results.first(where: { $0.propertyId == propertyId }) ?? results.first else { return property }
        await DatabaseService.shared.updatePropertySearchInfo(propertyId: propertyId, oldPropertyId: nil,
                                                              arvValue: match.totalArv.map(JSON.dartDoubleString))
        return await DatabaseService.shared.getPropertyById(propertyId) ?? property
    }

    private func printProperty() {
        guard !TourCoachMarkView.isActive else { return }
        Task {
            if ulbName == nil { await loadUlbInfo() }
            let property = await cacheArvIfMissing(await DatabaseService.shared.getPropertyById(propertyId))
            let data = await PropertyTaxBillPdf.buildBytes(
                propertyId: propertyId, bill: details?.billDetails, owner: details?.ownerDetails,
                property: details?.propertyDetailsInfo, currReceipts: details?.currReceiptDetails ?? [],
                arv: property?.arvValue, ulbName: ulbName, ulbType: ulbType)
            DocumentActions.print(data, jobName: "property_tax_bill_\(propertyId).pdf")
        }
    }

    // MARK: - Tour

    private func handleTourTap() {
        if isBusy { snack("Tour will be available after payment details are loaded."); return }
        if details == nil { snack("Payment details are not available right now."); return }
        startTour()
    }

    private func startTour() {
        guard !TourCoachMarkView.isActive, let payButton, let printButton, let grievanceButton, let receiptsButton else { return }
        TourCoachMarkView.present(steps: [
            TourStep(target: payButton, icon: "indianrupeesign.circle", title: "Pay Your Tax Online",
                     description: "Tap here to start the tax payment flow. An OTP will be sent to the registered mobile number before payment continues to the gateway.",
                     shape: .roundedRect(radius: 16), edge: .top),
            TourStep(target: printButton, icon: "printer", title: "Print Property",
                     description: "Tap here to print or download the current property tax details for this property.",
                     shape: .roundedRect(radius: 16), edge: .top),
            TourStep(target: grievanceButton, icon: "text.bubble", title: "Add Grievance",
                     description: "Use this button to raise a grievance related to payment or this property directly from the current screen.",
                     shape: .roundedRect(radius: 16), edge: .top),
            TourStep(target: receiptsButton, icon: "creditcard", title: "receipt details",
                     description: "Tap here to view receipt details and payment records for this property.",
                     shape: .roundedRect(radius: 16), edge: .top),
        ], scrollContainer: scrollView)
    }
}

/// Horizontal gradient background (`LinearGradient(centerLeft → centerRight)`).
final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    init(colors: [UIColor]) {
        super.init(frame: .zero)
        let g = layer as! CAGradientLayer
        g.colors = colors.map(\.cgColor)
        g.startPoint = CGPoint(x: 0, y: 0.5)
        g.endPoint = CGPoint(x: 1, y: 0.5)
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Sheets used by the pay flow

/// "Verification Required" OTP sheet shown before payment.
private final class PaymentOtpSheet: BottomSheetController {
    private let mobileNo: String
    private let maskedNumber: String
    private let onVerified: () -> Void
    private let errorBox = UIView()
    private let errorLabel = UILabel(nil, font: .poppins(12), color: .mRed700, lines: 0)
    private let verifyButton = PrimaryButton("Verify & Proceed")
    private let otpField: ENSTextField = {
        var c = ENSTextField.Config()
        c.placeholder = "------"
        c.icon = "number.square"
        c.keyboard = .numberPad
        c.maxLength = 6
        c.digitsOnly = true
        return ENSTextField(c)
    }()

    init(mobileNo: String, maskedNumber: String, onVerified: @escaping () -> Void) {
        self.mobileNo = mobileNo
        self.maskedNumber = maskedNumber
        self.onVerified = onVerified
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func buildContent() {
        contentStack.addSpacer(8)
        contentStack.add(UILabel("Verification Required", font: .poppins(20, .bold), color: .appTextDark))
        contentStack.addSpacer(4)
        contentStack.add(UILabel("Enter the OTP sent to \(maskedNumber) to proceed with payment.", font: .poppins(13),
                                 color: .grey500, lines: 0))
        contentStack.addSpacer(16)
        errorBox.backgroundColor = .mRed50
        errorBox.layer.cornerRadius = 10
        errorBox.addBorder(color: UIColor(argb: 0xFFEF9A9A))
        let row = UIStackView.h(8, [UIImageView(symbol: "exclamationmark.circle", size: 16, color: .mRed600), errorLabel])
        errorBox.addSubview(row)
        row.pinToEdges(of: errorBox, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        errorBox.isHidden = true
        contentStack.add(errorBox)
        contentStack.add(fieldLabel("Enter OTP", color: .grey700))
        contentStack.addSpacer(8)
        contentStack.add(otpField)
        contentStack.addSpacer(24)
        contentStack.add(verifyButton)
        contentStack.addSpacer(12)
        let cancel = textButton("Cancel", color: .grey600, size: 14, weight: .regular) { [weak self] in self?.close() }
        contentStack.add(cancel)
        verifyButton.onEvent { [weak self] in self?.verify() }
    }

    private func setError(_ message: String?) {
        errorLabel.text = message
        errorBox.isHidden = message == nil
        contentStack.setCustomSpacing(message == nil ? 0 : 16, after: errorBox)
    }

    private func verify() {
        let otp = otpField.trimmedText
        if otp.isEmpty { setError("Please enter OTP"); return }
        if otp.count < 4 { setError("Please enter valid OTP"); return }
        verifyButton.isLoading = true
        setError(nil)
        Task {
            do {
                let res = try await APIService.shared.verifyOtp(mobileNo: mobileNo, otp: otp)
                if res.success == true {
                    close { [onVerified] in onVerified() }
                    return
                }
                setError(res.message ?? "Invalid OTP")
            } catch {
                setError(APIError.userMessage(error, fallback: "Unable to verify OTP right now. Please try again."))
            }
            verifyButton.isLoading = false
        }
    }
}

/// Confirms the full payable amount before choosing a payment gateway.
private final class AmountSelectionSheet: BottomSheetController {
    private let fullAmount: String
    private let onProceed: (String) -> Void

    init(fullAmount: String, onProceed: @escaping (String) -> Void) {
        self.fullAmount = fullAmount
        self.onProceed = onProceed
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func buildContent() {
        contentStack.addSpacer(8)
        contentStack.add(UILabel("Payment Amount", font: .poppins(20, .bold), color: .appTextDark))
        contentStack.addSpacer(4)
        contentStack.add(UILabel("Pay the complete due amount.", font: .poppins(13), color: .grey500, lines: 0))
        contentStack.addSpacer(20)
        let amountRow = UIStackView.h(12, [
            UIImageView(symbol: "checkmark.circle.fill", size: 20, color: .appPrimary),
            UIStackView.v(0, [
                UILabel("Full Payment", font: .poppins(14, .semibold), color: .black87),
                UILabel("Pay the complete due amount", font: .poppins(12), color: .grey500, lines: 0),
            ]),
            FlexSpacer(),
            UILabel("₹ \(fullAmount)", font: .poppins(16, .extraBold), color: .appPrimary),
        ])
        let amountCard = UIView()
        amountCard.backgroundColor = .appPrimaryLight
        amountCard.layer.cornerRadius = 12
        amountCard.layer.borderWidth = 2
        amountCard.layer.borderColor = UIColor.appPrimary.cgColor
        amountCard.addSubview(amountRow)
        amountRow.pinToEdges(of: amountCard, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        contentStack.add(amountCard)
        contentStack.addSpacer(24)
        let proceed = PrimaryButton("Proceed to Payment")
        proceed.onEvent { [weak self] in self?.proceed() }
        contentStack.add(proceed)
        contentStack.addSpacer(12)
        contentStack.add(textButton("Cancel", color: .grey600, size: 14, weight: .regular) { [weak self] in self?.close() })
    }

    private func proceed() {
        close { [onProceed, fullAmount] in onProceed(fullAmount) }
    }
}

/// "Select Payment Gateway" (PayU only — SBI is disabled in Flutter).
private final class GatewaySelectionSheet: BottomSheetController {
    private let amount: String
    private let onPayU: () -> Void

    init(amount: String, onPayU: @escaping () -> Void) {
        self.amount = amount
        self.onPayU = onPayU
        super.init()
        showsHandle = false
        cornerRadius = 20
        contentInsets = UIEdgeInsets(top: 20, left: 24, bottom: 24, right: 24)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func buildContent() {
        contentStack.add(UILabel("Select Payment Gateway", font: .poppins(18, .bold), color: .black87))
        contentStack.addSpacer(4)
        contentStack.add(UILabel("Paying: ₹\(amount)", font: .poppins(14, .semibold), color: .appPrimary))
        contentStack.addSpacer(20)
        let card = UIView()
        card.layer.cornerRadius = 12
        card.addBorder(color: .grey300)
        let row = UIStackView.h(16, [
            UIImageView(symbol: "creditcard", size: 26, color: .appPrimary),
            UIStackView.v(0, [UILabel("Pay with PayU", font: .poppins(15, .bold), color: .black87),
                              UILabel("Safe & Secure", font: .poppins(12), color: .grey500)]),
            FlexSpacer(),
            UIImageView(symbol: "chevron.forward", size: 14, color: .grey500),
        ])
        card.addSubview(row)
        row.pinToEdges(of: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        card.onTap { [weak self] in
            guard let self else { return }
            self.close { [onPayU = self.onPayU] in onPayU() }
        }
        contentStack.add(card)
    }
}

/// Non-dismissible "Verifying Payment…" dialog.
private final class VerifyingPaymentDialog: UIViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.54)
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 20
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .appPrimary
        spinner.startAnimating()
        let message = UILabel("Please wait while we confirm\nyour payment with the server.", font: .poppins(13),
                              color: .grey600, lines: 0, alignment: .center)
        message.setLineHeight(1.4)
        let stack = UIStackView.v(0, alignment: .center, [
            spinner, UILabel("Verifying Payment…", font: .poppins(16, .bold), color: .appTextDark), message,
        ])
        stack.setCustomSpacing(24, after: spinner)
        stack.setCustomSpacing(8, after: stack.arrangedSubviews[1])
        card.addSubview(stack)
        stack.pinToEdges(of: card, insets: UIEdgeInsets(top: 36, left: 28, bottom: 36, right: 28))
        view.addSubview(card)
        card.center(in: view)
        card.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -80).isActive = true
    }
}
