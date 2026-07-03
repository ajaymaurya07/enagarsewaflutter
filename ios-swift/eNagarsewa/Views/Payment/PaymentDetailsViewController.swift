import UIKit
import Combine

/// Full parity port of `lib/payment_details_screen.dart`: tax summary, OTP-gated "Pay Your Tax
/// Online" (OTP sheet → amount sheet → payment-method sheet → PayU/SBI checkout → verify →
/// result), Print Property (PDF share), Payment History, Apply Grievance, and an expandable
/// Property Details card.
final class PaymentDetailsViewController: UIViewController {

    private let viewModel: PaymentDetailsViewModel
    private var cancellables = Set<AnyCancellable>()
    private var propertyDetailsExpanded = false

    init(viewModel: PaymentDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI refs

    private var navBarView = UIView()
    private let scrollView = UIScrollView()
    private let mainStack  = UIStackView()
    private let spinner    = UIActivityIndicatorView(style: .large)
    private weak var propDetailsContent: UIView?
    private weak var propChevron: UIImageView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1)
        setupNavBar()
        setupLayout()
        bindViewModel()
        populateContent(details: viewModel.details)
        Task { await viewModel.fetchDetails() }
    }

    // MARK: - Nav bar (matches Flutter's custom AppBar row)

    private func setupNavBar() {
        let bar = UIView()
        bar.backgroundColor = UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1)
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        navBarView = bar

        let backBtn = UIButton(type: .system)
        backBtn.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        backBtn.tintColor = .appPrimary
        backBtn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        let titleL = UILabel()
        titleL.text = "Payment Details"
        titleL.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        titleL.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)

        let pidL = UILabel()
        pidL.text = "PID: \(viewModel.property.propertyId)"
        pidL.font = UIFont(name: "Poppins-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        pidL.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)

        let titleStack = UIStackView(arrangedSubviews: [titleL, pidL])
        titleStack.axis = .vertical; titleStack.spacing = 0
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        // Help button is a visual placeholder only — the coach-mark tour system is a separate
        // workstream and intentionally not wired up here.
        let helpBtn = UIButton(type: .system)
        helpBtn.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        helpBtn.tintColor = .appPrimary
        helpBtn.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(backBtn); bar.addSubview(titleStack); bar.addSubview(helpBtn)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 60),
            backBtn.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
            backBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: 36),
            backBtn.heightAnchor.constraint(equalToConstant: 36),
            titleStack.leadingAnchor.constraint(equalTo: backBtn.trailingAnchor, constant: 4),
            titleStack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            helpBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            helpBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            helpBtn.widthAnchor.constraint(equalToConstant: 40),
            helpBtn.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    // MARK: - Base layout

    private func setupLayout() {
        spinner.color = .appPrimary
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        scrollView.backgroundColor = .white
        view.addSubview(scrollView)

        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(wrapper)

        mainStack.axis = .vertical; mainStack.spacing = 0
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(mainStack)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: navBarView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            wrapper.topAnchor.constraint(equalTo: scrollView.topAnchor),
            wrapper.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            wrapper.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            wrapper.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            wrapper.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -32),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            loading ? self?.spinner.startAnimating() : self?.spinner.stopAnimating()
            self?.scrollView.isUserInteractionEnabled = !loading
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            guard let msg, let self else { return }
            ENSSnackbar.show(in: self.view, message: msg, isError: true)
        }.store(in: &cancellables)

        viewModel.$details.receive(on: DispatchQueue.main).sink { [weak self] details in
            self?.populateContent(details: details)
        }.store(in: &cancellables)
    }

    // MARK: - Content

    private func populateContent(details: PropertyDetailsData) {
        let wasExpanded = propertyDetailsExpanded
        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let bill  = details.billDetails
        let prop  = details.propertyDetailsInfo
        let owner = details.ownerDetails

        let taxCard = buildTaxSummaryCard(bill: bill, arvValue: viewModel.property.arvValue,
                                          advanceTotal: viewModel.totalAdvancePay)
        mainStack.addArrangedSubview(taxCard)
        mainStack.setCustomSpacing(20, after: taxCard)

        let payBtn = buildPayButton()
        mainStack.addArrangedSubview(payBtn)
        mainStack.setCustomSpacing(12, after: payBtn)

        let secRow = buildSecondaryButtonsRow()
        mainStack.addArrangedSubview(secRow)
        mainStack.setCustomSpacing(12, after: secRow)

        let grievanceBtn = buildApplyGrievanceButton()
        mainStack.addArrangedSubview(grievanceBtn)
        mainStack.setCustomSpacing(20, after: grievanceBtn)

        let detailsCard = buildPropertyDetailsCard(prop: prop, owner: owner)
        mainStack.addArrangedSubview(detailsCard)

        propertyDetailsExpanded = false
        if wasExpanded { togglePropertyDetails() }
    }

    // MARK: - Tax Summary Card

    private func buildTaxSummaryCard(bill: BillDetails?, arvValue: String, advanceTotal: String) -> UIView {
        let card = UIView.cardContainer()

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor(red: 1, green: 0.957, blue: 0.898, alpha: 1)
        iconBg.layer.cornerRadius = 8
        iconBg.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 36).isActive = true
        let iconImg = UIImageView(image: UIImage(systemName: "doc.text.fill"))
        iconImg.tintColor = .appPrimary; iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconImg)
        NSLayoutConstraint.activate([
            iconImg.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconImg.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconImg.widthAnchor.constraint(equalToConstant: 20),
            iconImg.heightAnchor.constraint(equalToConstant: 20),
        ])

        let titleL = UILabel()
        titleL.text = "Tax Summary"
        titleL.font = UIFont(name: "Poppins-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        titleL.textColor = .appCardText

        let headerRow = UIStackView(arrangedSubviews: [iconBg, titleL])
        headerRow.axis = .horizontal; headerRow.spacing = 12; headerRow.alignment = .center

        let infoStack = UIStackView()
        infoStack.axis = .vertical; infoStack.spacing = 0
        for (k, v) in [("Bill Date", bill?.billDate), ("Bill Number", bill?.billNo),
                       ("Financial Year", bill?.finYear),
                       ("Total Arv", arvValue.isEmpty ? nil : arvValue)] {
            infoStack.addArrangedSubview(makeSummaryRow(k, v ?? "N/A"))
        }

        let div = UIView()
        div.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        div.heightAnchor.constraint(equalToConstant: 0.8).isActive = true

        let taxStack = UIStackView()
        taxStack.axis = .vertical; taxStack.spacing = 0
        for (k, v) in [("House Tax Net Amount",    bill?.houseTaxNetAmount),
                       ("Water Tax Net Amount",     bill?.waterTaxNetAmount),
                       ("Sewer Tax Net Amount",     bill?.sewerTaxNetAmount),
                       ("Other Tax Net Amount",     bill?.othertaxNetAmount),
                       ("Water Charge Net Amount",  bill?.waterChargeNetAmount),
                       ("Net Demand",               bill?.netDemand),
                       ("Total Advance Tax Pay",    advanceTotal)] {
            taxStack.addArrangedSubview(makeSummaryRow(k, v ?? "N/A"))
        }

        let netBox = buildNetPayableBox(bill?.netPayble ?? "0.0")

        let inner = UIStackView(arrangedSubviews: [headerRow, infoStack, div, taxStack, netBox])
        inner.axis = .vertical; inner.spacing = 0
        inner.setCustomSpacing(24, after: headerRow)
        inner.setCustomSpacing(12, after: infoStack)
        inner.setCustomSpacing(12, after: div)
        inner.setCustomSpacing(20, after: taxStack)
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }

    private func makeSummaryRow(_ label: String, _ value: String) -> UIView {
        let keyL = UILabel()
        keyL.text = label
        keyL.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        keyL.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        keyL.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let valL = UILabel()
        valL.text = value
        valL.font = UIFont(name: "Poppins-SemiBold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold)
        valL.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
        valL.textAlignment = .right
        valL.numberOfLines = 0
        valL.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [keyL, valL])
        row.axis = .horizontal; row.distribution = .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false

        let wrap = UIView()
        wrap.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 6),
            row.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -6),
        ])
        return wrap
    }

    private func buildNetPayableBox(_ amount: String) -> UIView {
        let box = UIView()
        box.backgroundColor = UIColor(red: 1, green: 0.957, blue: 0.898, alpha: 1)
        box.layer.cornerRadius = 12
        box.layer.borderWidth = 1
        box.layer.borderColor = UIColor(red: 1, green: 0.878, blue: 0.698, alpha: 1).cgColor

        let labelL = UILabel()
        labelL.text = "Net Payable"
        labelL.font = UIFont(name: "Poppins-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        labelL.textColor = .appPrimary

        let amtL = UILabel()
        amtL.text = "₹ \(amount)"
        amtL.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        amtL.textColor = .appPrimary

        let row = UIStackView(arrangedSubviews: [labelL, amtL])
        row.axis = .horizontal; row.distribution = .equalSpacing; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
            row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16),
        ])
        return box
    }

    // MARK: - Action buttons

    private func buildPayButton() -> UIView {
        let btn = UIButton.primaryButton(title: "Pay Your Tax Online")
        btn.layer.cornerRadius = 16
        btn.heightAnchor.constraint(equalToConstant: 56).isActive = true
        btn.addTarget(self, action: #selector(payTapped), for: .touchUpInside)
        btn.addShadow(opacity: 0.28, radius: 12, offset: CGSize(width: 0, height: 6))
        return btn
    }

    private func buildSecondaryButtonsRow() -> UIView {
        let printBtn   = makeSecondaryButton("Print Property",  icon: "printer",    action: #selector(printTapped))
        let historyBtn = makeSecondaryButton("Payment History", icon: "creditcard", action: #selector(historyTapped))
        let row = UIStackView(arrangedSubviews: [printBtn, historyBtn])
        row.axis = .horizontal; row.spacing = 12; row.distribution = .fillEqually
        return row
    }

    private func buildApplyGrievanceButton() -> UIView {
        makeSecondaryButton("Apply Grievance", icon: "text.bubble", action: #selector(grievanceTapped))
    }

    private func makeSecondaryButton(_ title: String, icon: String, action: Selector) -> UIView {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = .appPrimary
        btn.layer.cornerRadius = 10
        btn.clipsToBounds = true
        btn.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let imgView = UIImageView(image: UIImage(systemName: icon))
        imgView.tintColor = .white; imgView.contentMode = .scaleAspectFit
        imgView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        imgView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont(name: "Poppins-SemiBold", size: 12) ?? .systemFont(ofSize: 12, weight: .semibold)
        lbl.textColor = .white; lbl.textAlignment = .center; lbl.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [imgView, lbl])
        stack.axis = .horizontal; stack.spacing = 6; stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
        ])
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - Property Details card (expandable)

    private func buildPropertyDetailsCard(prop: PropertyInfo?, owner: OwnerDetails?) -> UIView {
        let card = UIView.cardContainer()

        let headerL = UILabel()
        headerL.text = "Property Details"
        headerL.font = UIFont(name: "Poppins-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        headerL.textColor = .appCardText

        let chevronImg = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevronImg.tintColor = .appPrimary; chevronImg.contentMode = .scaleAspectFit
        chevronImg.widthAnchor.constraint(equalToConstant: 20).isActive = true
        propChevron = chevronImg

        let headerRow = UIStackView(arrangedSubviews: [headerL, chevronImg])
        headerRow.axis = .horizontal; headerRow.alignment = .center
        headerRow.isLayoutMarginsRelativeArrangement = true
        headerRow.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        headerRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(togglePropertyDetails)))
        headerRow.isUserInteractionEnabled = true

        let content = UIView()
        content.isHidden = true
        propDetailsContent = content

        let divider = UIView()
        divider.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        divider.translatesAutoresizingMaskIntoConstraints = false

        let rows = UIStackView()
        rows.axis = .vertical; rows.spacing = 12
        rows.translatesAutoresizingMaskIntoConstraints = false

        for (k, v) in [("Property/House Id",     viewModel.property.propertyId),
                       ("Zone Name",             prop?.zoneName ?? "N/A"),
                       ("Ward Name",             prop?.wardName ?? "N/A"),
                       ("Mohalla Name",          prop?.mohallaName ?? "N/A"),
                       ("House No.",             prop?.houseNo ?? "N/A"),
                       ("Property Address",      prop?.address ?? "N/A"),
                       ("Owner/Occupier Name",   owner?.ownerName ?? viewModel.property.ownerName),
                       ("Owner Mobile Number",   owner?.mobileNo ?? viewModel.property.phoneNumber),
                       ("Owner Father Name",     owner?.fatherName ?? viewModel.property.fatherName)] {
            rows.addArrangedSubview(makePropDetailRow(k, v))
        }

        content.addSubview(divider)
        content.addSubview(rows)
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: content.topAnchor),
            divider.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            rows.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),
            rows.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            rows.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            rows.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])

        let cardInner = UIStackView(arrangedSubviews: [headerRow, content])
        cardInner.axis = .vertical
        cardInner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardInner)
        NSLayoutConstraint.activate([
            cardInner.topAnchor.constraint(equalTo: card.topAnchor),
            cardInner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cardInner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cardInner.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    private func makePropDetailRow(_ label: String, _ value: String) -> UIView {
        let keyL = UILabel()
        keyL.text = label
        keyL.font = UIFont(name: "Poppins-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        keyL.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        keyL.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let valL = UILabel()
        valL.text = value
        valL.font = UIFont(name: "Poppins-SemiBold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold)
        valL.textColor = .appCardText; valL.textAlignment = .right; valL.numberOfLines = 0
        valL.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [keyL, valL])
        row.axis = .horizontal; row.distribution = .equalSpacing; row.alignment = .top
        return row
    }

    // MARK: - Simple actions

    @objc private func backTapped()    { navigationController?.popViewController(animated: true) }
    @objc private func historyTapped() { viewModel.coordinator?.showPaymentHistory() }
    @objc private func grievanceTapped() { viewModel.coordinator?.showApplyGrievance() }

    @objc private func togglePropertyDetails() {
        propertyDetailsExpanded.toggle()
        propDetailsContent?.isHidden = !propertyDetailsExpanded
        propChevron?.image = UIImage(systemName: propertyDetailsExpanded ? "chevron.up" : "chevron.down")
    }

    // MARK: - Print Property (mirrors Flutter's _printProperty)

    @objc private func printTapped() {
        let data = viewModel.buildReceiptPdfData()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("property_\(viewModel.property.propertyId).pdf")
        do {
            try data.write(to: url)
        } catch {
            ENSSnackbar.show(in: view, message: "Unable to prepare the PDF right now. Please try again.", isError: true)
            return
        }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        present(activityVC, animated: true)
    }

    // MARK: - Pay Tax flow: OTP → amount → method → checkout → verify → result

    @objc private func payTapped() {
        guard !viewModel.ownerMobile.isEmpty else {
            ENSSnackbar.show(in: view, message: "Mobile number not available for OTP", isError: true)
            return
        }
        Task { await sendOtpAndShowSheet() }
    }

    @MainActor
    private func sendOtpAndShowSheet() async {
        spinner.startAnimating()
        scrollView.isUserInteractionEnabled = false
        defer {
            spinner.stopAnimating()
            scrollView.isUserInteractionEnabled = true
        }
        do {
            let masked = try await viewModel.sendOtp()
            showOtpSheet(maskedNumber: masked)
        } catch {
            ENSSnackbar.show(in: view, message: message(for: error), isError: true)
        }
    }

    private func showOtpSheet(maskedNumber: String) {
        let sheet = PaymentOtpSheetViewController(maskedNumber: maskedNumber)
        sheet.onVerify = { [weak self, weak sheet] otp in
            guard let self else { return }
            sheet?.setVerifying(true)
            Task { @MainActor [weak self, weak sheet] in
                guard let self else { return }
                do {
                    try await self.viewModel.verifyOtp(otp)
                    sheet?.dismiss(animated: true) { [weak self] in self?.showAmountSheet() }
                } catch {
                    sheet?.setVerifying(false)
                    sheet?.showError(self.message(for: error))
                }
            }
        }
        presentAsSheet(sheet)
    }

    private func showAmountSheet() {
        let sheet = PaymentAmountSheetViewController(fullAmount: viewModel.netPayableAmount)
        sheet.onProceed = { [weak self] amount in
            self?.showPaymentMethodSheet(amount: amount)
        }
        presentAsSheet(sheet)
    }

    private func showPaymentMethodSheet(amount: String) {
        let sheet = PaymentMethodSheetViewController(amount: amount)
        sheet.onSelectPayU = { [weak self] amount in Task { @MainActor in await self?.startPayUFlow(amount: amount) } }
        sheet.onSelectSBI  = { [weak self] amount in Task { @MainActor in await self?.startSBIFlow(amount: amount) } }
        presentAsSheet(sheet)
    }

    private func presentAsSheet(_ sheet: UIViewController) {
        sheet.modalPresentationStyle = .pageSheet
        sheet.isModalInPresentation = true
        if let s = sheet.sheetPresentationController {
            s.detents = [.medium(), .large()]
            s.prefersGrabberVisible = true
            s.preferredCornerRadius = 24
        }
        present(sheet, animated: true)
    }

    // MARK: - PayU

    @MainActor
    private func startPayUFlow(amount: String) async {
        spinner.startAnimating()
        defer { spinner.stopAnimating() }
        do {
            let txn = try await viewModel.createPayUTransaction(amount: amount)
            PayUCheckoutBridge.openCheckout(
                transaction: txn,
                from: self,
                generateHash: { [weak self] name, str in
                    await self?.viewModel.generateHash(hashName: name, hashString: str)
                },
                completion: { [weak self] outcome in
                    Task { @MainActor in await self?.handlePayUOutcome(outcome) }
                }
            )
        } catch {
            ENSSnackbar.show(in: view, message: message(for: error), isError: true)
        }
    }

    @MainActor
    private func handlePayUOutcome(_ outcome: PayUCheckoutBridge.Outcome) async {
        switch outcome {
        case .unavailable:
            // Mirrors Flutter's catch-block when `payu.openCheckoutScreen` itself throws —
            // no payment attempt actually happened, so there's nothing to verify.
            showAlert(message: "Unable to start PayU payment right now. Please try again.")
        case .success, .failure, .cancelled:
            let unableToVerifyMessage = outcome == .cancelled
                ? "Payment Cancelled. Verification could not be completed. Please check your Payment History to confirm the status."
                : "Payment verification could not be completed. Please check your Payment History to confirm the status."
            let overlay = showLoadingOverlay(message: "Verifying Payment…")
            let result = await viewModel.verifyPayUPayment(unableToVerifyMessage: unableToVerifyMessage)
            overlay.dismiss(animated: true) { [weak self] in
                self?.viewModel.coordinator?.showPaymentResult(
                    status: result.status, txnId: result.txnId, gateway: .payU
                )
            }
        }
    }

    // MARK: - SBI
    // Not exposed in Flutter's current UI (its picker card is commented out — see
    // `_showPaymentMethodSelection`), but the WebView checkout is fully wired here, so it's the
    // payment path that actually works end-to-end without a third-party SDK.

    @MainActor
    private func startSBIFlow(amount: String) async {
        spinner.startAnimating()
        defer { spinner.stopAnimating() }
        do {
            let data = try await viewModel.createSBITransaction(amount: amount)
            viewModel.coordinator?.showSbiPayment(data: data)
        } catch {
            ENSSnackbar.show(in: view, message: message(for: error), isError: true)
        }
    }

    private func message(for error: Error) -> String {
        if let e = error as? PaymentDetailsViewModel.PaymentDetailsError, case .message(let m) = e { return m }
        return (error as? NetworkError)?.errorDescription
            ?? "Something went wrong. Please try again."
    }
}
