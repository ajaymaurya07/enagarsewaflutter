import UIKit

/// Port of lib/utils/mutation_ui.dart.
enum MutationUI {
    static let background = UIColor.appFieldFill

    static func statusColor(_ status: String) -> UIColor {
        switch status.uppercased() {
        case "SUBMITTED": return UIColor(argb: 0xFF2563EB)
        case "APPROVED", "COMPLETED", "MUTATED": return UIColor(argb: 0xFF1E9E5A)
        case "REJECTED", "CANCELLED": return UIColor(argb: 0xFFD92D20)
        case "PENDING", "IN_PROGRESS", "UNDER_REVIEW": return .appPrimary
        default: return UIColor(argb: 0xFF667085)
        }
    }

    static func statusIcon(_ status: String) -> String {
        switch status.uppercased() {
        case "SUBMITTED": return "checkmark.seal"
        case "APPROVED", "COMPLETED", "MUTATED": return "checkmark.circle.fill"
        case "REJECTED", "CANCELLED": return "xmark.circle.fill"
        case "PENDING", "IN_PROGRESS", "UNDER_REVIEW": return "hourglass.bottomhalf.filled"
        default: return "info.circle"
        }
    }

    /// `IN_PROGRESS` → `In Progress`
    static func statusLabel(_ status: String) -> String {
        guard !status.trimmingCharacters(in: .whitespaces).isEmpty else { return "Unknown" }
        return status.components(separatedBy: CharacterSet(charactersIn: "_ \t"))
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    static func statusChip(_ status: String, compact: Bool = true) -> UIView {
        let color = statusColor(status)
        let row = UIStackView.h(5, [
            UIImageView(symbol: statusIcon(status), size: compact ? 12 : 14, color: color),
            UILabel(statusLabel(status), font: .poppins(compact ? 11 : 12.5, .semibold), color: color),
        ]).padded(UIEdgeInsets(top: compact ? 5 : 7, left: compact ? 10 : 12, bottom: compact ? 5 : 7, right: compact ? 10 : 12))
        row.backgroundColor = color.withAlphaComponent(0.12)
        row.layer.cornerRadius = 12
        row.setContentHuggingPriority(.required, for: .horizontal)
        row.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    /// `2026-07-30` / `2026-07-30 18:38:13` / `30-07-2026` → `30 Jul 2026`.
    static func formatDate(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "-" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "dd MMM yyyy"
        if t.first?.isNumber == true, t.count >= 10, t[t.index(t.startIndex, offsetBy: 4)] == "-",
           let d = DateParsing.iso8601(t) {
            return out.string(from: d)
        }
        if t.range(of: #"^\d{2}-\d{2}-\d{4}$"#, options: .regularExpression) != nil {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "dd-MM-yyyy"
            if let d = f.date(from: t) { return out.string(from: d) }
        }
        return t
    }

    /// `#,##,##0.##` in en_IN — `500000` → `5,00,000`.
    static func formatAmount(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespaces)
        guard let value = Double(t) else { return t.isEmpty ? "-" : t }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_IN")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? t
    }

    static func prettify(_ value: String) -> String {
        let t = value.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return "-" }
        return t.contains("_") ? statusLabel(t) : t
    }
}

/// Port of lib/mutation_screen.dart.
final class MutationViewController: BaseViewController {

    override var screenBackground: UIColor { MutationUI.background }

    private let ackField: ENSTextField = {
        var c = ENSTextField.Config()
        c.placeholder = "Acknowledgement Number"
        c.floatingLabel = true
        c.capitalization = .allCharacters
        c.deny = "[<>]"
        c.fill = .white
        c.borderColor = .grey300
        c.labelColor = .grey600
        c.textColor = .appTextDark
        return ENSTextField(c)
    }()
    private let trackButton = PrimaryButton("Track Application", height: 46, radius: 12, fontSize: 14, weight: .semibold,
                                            icon: "arrow.right")

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Mutation", titleColor: .appTextDark, backColor: .appPrimary, titleSize: 17, titleWeight: .semibold)
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16))

        // New application card (gradient)
        let gradient = GradientView(colors: [UIColor(argb: 0xFFF08B33), .appPrimary])
        (gradient.layer as? CAGradientLayer)?.startPoint = .zero
        (gradient.layer as? CAGradientLayer)?.endPoint = CGPoint(x: 1, y: 1)
        gradient.layer.cornerRadius = 16
        gradient.layer.shadowColor = UIColor.appPrimary.cgColor
        gradient.layer.shadowOpacity = 0.25
        gradient.layer.shadowRadius = 7
        gradient.layer.shadowOffset = CGSize(width: 0, height: 6)
        let apply = PrimaryButton("Apply Now", color: .white, height: 44, radius: 12, fontSize: 14.5, weight: .semibold,
                                  icon: "plus.circle")
        apply.setTitleColor(.appPrimary, for: .normal)
        apply.tintColor = .appPrimary
        apply.onEvent { [weak self] in self?.push(NewMutationViewController()) }
        let header = UIStackView.h(12, [
            iconTile("arrow.left.arrow.right", color: .white, background: UIColor.white.withAlphaComponent(0.2), size: 40,
                     iconSize: 20, radius: 10),
            UIStackView.v(2, [UILabel("New Mutation Application", font: .poppins(14.5, .bold), color: .white, lines: 0),
                              UILabel("Transfer property ownership in 4 simple steps", font: .poppins(12),
                                      color: UIColor.white.withAlphaComponent(0.9), lines: 0)]),
        ])
        let inner = UIStackView.v(14, [header, apply])
        gradient.addSubview(inner)
        inner.pinToEdges(of: gradient, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        contentStack.add(gradient)
        contentStack.addSpacer(24)

        // Track card
        let track = CardView(radius: 16, shadowOpacity: 0.05, shadowBlur: 12, shadowY: 4)
        track.stack.add(UIStackView.h(10, [iconTile("magnifyingglass", background: AssessmentUI.softPrimary, size: 34,
                                                    iconSize: 16, radius: 9),
                                           UILabel("Track Mutation Application", font: .poppins(14.5, .bold), color: .appTextDark, lines: 0)]))
        track.stack.addSpacer(6)
        track.stack.add(UILabel("Enter the acknowledgement number you received on submission to check its status.",
                                font: .poppins(12.5), color: .grey600, lines: 0))
        track.stack.addSpacer(14)
        track.stack.add(ackField)
        track.stack.addSpacer(14)
        track.stack.add(trackButton)
        contentStack.add(track)

        ackField.onSubmit = { [weak self] in self?.handleTrack() }
        trackButton.onEvent { [weak self] in self?.handleTrack() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        trackButton.isLoading = false
    }

    private func handleTrack() {
        let ack = ackField.trimmedText
        guard !ack.isEmpty else { snack("Please enter an Acknowledgement Number"); return }
        view.endEditing(true)
        trackButton.isLoading = true
        push(MutationApplicationDetailViewController(ackNo: ack))
    }
}

/// Port of lib/new_mutation_screen.dart — four-part mutation application.
final class NewMutationViewController: BaseViewController {

    override var screenBackground: UIColor { MutationUI.background }

    private static let totalSteps = 4
    private static let maxDocSize = 200 * 1024
    private static let salutations = ["S/o", "D/o", "W/o"]
    private static let occupiedByOptions = ["Self", "Other"]
    private static let flagJujOptions = ["Normal Mutation", "Jujbhag (against existing application)"]
    /// TODO: set back to false before release — mirrors Flutter's `_skipStepValidation`, which
    /// skips per-step validation (except the final submit step) for UI testing.
    private static let skipStepValidation = true

    private var step = 0
    private var savedProperties: [PropertyEntity] = []
    private var isLoadingSaved = true
    private var selectedProperty: PropertyEntity?
    private var isLoadingProperty = false
    private var propertyError: String?
    private var propertyData: MutationPropertyData?
    private var causeId: String?, idProofId: String?
    private var occupiedBy = "Self"
    private var salutation = "S/o"
    private var flagJuj = 0
    private var ulbId: String?
    private var isLoadingFees = false
    private var feesError: String?
    private var fees: MutationFees?
    private var docs: [String: PickedFile] = [:]
    private var isSubmitting = false

    private var progressBar: AssessmentProgressBar?
    private let progressHolder = UIView()
    private let backButton = OutlineButton("Back", color: .appPrimary, borderColor: .appPrimary, height: 48, fontSize: 15)
    private let continueButton = AssessmentUI.actionButton("Continue")

    private lazy var occupierName = field("Occupier Name", required: true)
    private lazy var occupierFather = field("Occupier Father's Name", required: true)
    private lazy var occupierMobile = field("Occupier Mobile", required: true, keyboard: .phonePad, max: 10, digits: true)
    private lazy var occupierTime = field("Occupancy Period")
    private lazy var newOwner = field("New Owner Name", required: true)
    private lazy var fatherName = field("Father/Husband Name", required: true)
    private lazy var mobile: ENSTextField = {
        let f = field("Mobile Number", keyboard: .phonePad, max: 10, digits: true)
        f.validator = { v in
            let t = v.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return "Please enter Mobile Number" }
            return t.range(of: #"^[6-9]\d{9}$"#, options: .regularExpression) == nil ? "Please enter a valid 10-digit mobile number" : nil
        }
        return f
    }()
    private lazy var altMobile = field("Alternate Mobile Number", keyboard: .phonePad, max: 10, digits: true)
    private lazy var email = field("Email ID", keyboard: .emailAddress)
    private lazy var commAddress = field("Communication Address", required: true)
    private lazy var pinCode = field("PIN Code", required: true, keyboard: .numberPad, max: 6, digits: true)
    private lazy var propertyCost: ENSTextField = {
        let f = field("Property Cost (₹)", keyboard: .decimalPad, decimals: true)
        f.validator = { v in
            let t = v.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return "Please enter Property Cost" }
            guard let p = Double(t), p > 0 else { return "Please enter a valid property cost" }
            return nil
        }
        f.onChange = { [weak self] _ in
            self?.fees = nil
            self?.feesError = nil
            self?.renderFeesArea()
        }
        return f
    }()
    private lazy var registryDate: ENSTextField = {
        let f = field("Registry Date", required: true)
        f.textField?.isUserInteractionEnabled = false
        f.onTap { [weak self] in self?.pickRegistryDate() }
        return f
    }()
    private let feesArea = UIStackView.v(0, [])
    private let calcButton = OutlineButton("Calculate Mutation Fees", color: .appPrimary, borderColor: .appPrimary,
                                           height: 48, fontSize: 14, icon: "function")

    private func field(_ label: String, required: Bool = false, keyboard: UIKeyboardType = .default, max: Int? = nil,
                       digits: Bool = false, decimals: Bool = false) -> ENSTextField {
        var c = ENSTextField.Config()
        c.placeholder = label
        c.floatingLabel = true
        c.keyboard = keyboard
        c.maxLength = max
        c.digitsOnly = digits
        if decimals { c.allow = "[\\d.]" } else if !digits { c.deny = "[<>]" }
        c.fill = .white
        c.borderColor = .grey300
        c.labelColor = .grey600
        c.textColor = .appTextDark
        let f = ENSTextField(c)
        if required {
            f.validator = { $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Please enter \(label)" : nil }
        }
        return f
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "New Mutation Application", titleColor: .appTextDark, backColor: .appPrimary, titleSize: 15,
                     titleWeight: .semibold)
        interceptsBack = false
        view.addSubview(progressHolder)
        progressHolder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressHolder.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressHolder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressHolder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let buttons = UIStackView.h(12, alignment: .fill, [backButton, continueButton])
        // Expanded flex 1:2 — below required so hiding Back on step 1 doesn't conflict.
        let flex = backButton.widthAnchor.constraint(equalTo: continueButton.widthAnchor, multiplier: 0.5)
        flex.priority = .defaultHigh
        flex.isActive = true
        let bar = UIView()
        bar.backgroundColor = screenBackground
        bar.addSubview(buttons)
        buttons.pinToEdges(of: bar, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        view.addSubview(bar)
        bar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
        installScrollStack(below: progressHolder, above: bar)

        backButton.onEvent { [weak self] in self?.handleBack() }
        continueButton.onEvent { [weak self] in self?.handleContinue() }
        calcButton.onEvent { [weak self] in self?.fetchFees() }

        ulbId = StorageService.ulbCache
        render()
        Task {
            savedProperties = await DatabaseService.shared.getAllProperties()
            isLoadingSaved = false
            if step == 0 { render() }
        }
    }

    /// Back steps backwards; on the first step it leaves (`canPop: _currentStep == 0`).
    override func handleBack() {
        guard !isSubmitting else { return }
        if step == 0 {
            navigationController?.popViewController(animated: true)
            return
        }
        view.endEditing(true)
        step -= 1
        render()
    }

    // MARK: - Rendering

    private func sectionTitle(_ t: String) -> UIView { UILabel(t, font: .poppins(16, .bold), color: .appTextDark, lines: 0) }
    private func hint(_ t: String) -> UIView { UILabel(t, font: .poppins(12), color: .grey600, lines: 0) }
    private func fieldLabel14(_ t: String) -> UIView { UILabel(t, font: .poppins(14, .semibold), color: .appTextDark, lines: 0) }

    private func render() {
        interceptsBack = step > 0 || isSubmitting
        progressHolder.subviews.forEach { $0.removeFromSuperview() }
        let bar = AssessmentProgressBar(step: step + 1, total: Self.totalSteps)
        progressHolder.addSubview(bar)
        bar.pinToEdges(of: progressHolder)

        backButton.isHidden = step == 0
        continueButton.setTitle(step == Self.totalSteps - 1 ? "Submit" : "Continue", for: .normal)

        let s = contentStack
        s.arrangedSubviews.forEach { s.removeArrangedSubview($0); $0.removeFromSuperview() }
        switch step {
        case 0: renderStep1()
        case 1: renderStep2()
        case 2: renderStep3()
        default: renderStep4()
        }
        scrollView.setContentOffset(.zero, animated: false)
    }

    private func renderStep1() {
        let s = contentStack
        s.add(sectionTitle("Property Details")); s.addSpacer(4)
        s.add(hint("Select Property ID first.")); s.addSpacer(14)
        if isLoadingSaved {
            let sp = UIActivityIndicatorView(style: .large)
            sp.color = .appPrimary
            sp.startAnimating()
            s.add(centered(sp).padded(UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)))
        } else {
            let f = AssessmentUI.selectField(savedProperties.isEmpty ? "No saved property found" : "Select Property ID")
            f.value = selectedProperty?.propertyId
            if savedProperties.isEmpty {
                f.box.backgroundColor = UIColor(argb: 0xFFF3F4F6)
            } else {
                f.onTap = { [weak self] in
                    guard let self, !self.isLoadingProperty else { return }
                    OptionPickerSheet.present(on: self, title: "Select Property", options: self.savedProperties.map(\.propertyId),
                                              selected: nil, searchable: true) { i in self.onPropertySelected(self.savedProperties[i]) }
                }
            }
            s.add(AssessmentUI.labeled("Property ID", f))
        }
        if isLoadingProperty {
            let sp = UIActivityIndicatorView(style: .large)
            sp.color = .appPrimary
            sp.startAnimating()
            s.addSpacer(16)
            s.add(centered(sp))
        }
        if let propertyError {
            s.addSpacer(10)
            s.add(UILabel(propertyError, font: .poppins(12.5), color: .mRed, lines: 0))
        }
        guard let data = propertyData else { return }
        s.addSpacer(18)
        let card = CardView(radius: 14, padding: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14),
                            shadowOpacity: 0.04, shadowBlur: 10, shadowY: 3, border: .grey200)
        let owner = UILabel(data.ownerName.isEmpty ? "Current Owner" : data.ownerName, font: .poppins(14, .bold), color: .appTextDark)
        owner.lineBreakMode = .byTruncatingTail
        card.stack.add(UIStackView.h(10, [iconTile("building.2", background: AssessmentUI.softPrimary, size: 33, iconSize: 16, radius: 9), owner]))
        card.stack.add(divider(color: .grey300, thickness: 0.5).padded(UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)))
        for (l, v) in [("Property ID", data.propertyId), ("Address", data.address),
                       ("Zone / Ward / Mohalla", "\(data.zoneName) / \(data.wardName) / \(data.mohallaName)"),
                       ("Current ARV", "₹\(MutationUI.formatAmount(data.arv))")] {
            card.stack.add(infoRow(l, v, labelWidth: 130, fontSize: 12.5, labelSize: 12, alignRight: false))
        }
        s.add(card)
        s.addSpacer(20)
        s.add(sectionTitle("Mutation Details")); s.addSpacer(4)
        s.add(hint("Choose the reason for mutation and the ID proof type.")); s.addSpacer(14)
        let causeField = AssessmentUI.selectField("Select Mutation Cause")
        causeField.value = causeId.flatMap { id in data.causeList.first { $0.key == id }?.value }
        causeField.onTap = { [weak self] in
            guard let self else { return }
            self.pickOption("Select Mutation Cause", data.causeList.map(\.value)) { i in
                self.causeId = data.causeList[i].key
                self.fees = nil
                self.feesError = nil
                causeField.value = data.causeList[i].value
            }
        }
        let idField = AssessmentUI.selectField("Select ID Proof Type")
        idField.value = idProofId.flatMap { id in data.idList.first { $0.key == id }?.value }
        idField.onTap = { [weak self] in
            guard let self else { return }
            self.pickOption("Select ID Proof Type", data.idList.map(\.value)) { i in
                self.idProofId = data.idList[i].key
                idField.value = data.idList[i].value
            }
        }
        let typeField = AssessmentUI.selectField("")
        typeField.value = Self.flagJujOptions[flagJuj]
        typeField.onTap = { [weak self] in
            self?.pickOption("Select Application Type", Self.flagJujOptions) { i in
                self?.flagJuj = i
                typeField.value = Self.flagJujOptions[i]
            }
        }
        s.add(AssessmentUI.labeled("Mutation Cause", causeField)); s.addSpacer(16)
        s.add(AssessmentUI.labeled("ID Proof Type", idField)); s.addSpacer(16)
        s.add(AssessmentUI.labeled("Application Type", typeField))
    }

    private func renderStep2() {
        let s = contentStack
        s.add(sectionTitle("Occupancy Details")); s.addSpacer(4)
        s.add(hint("Who currently occupies this property?")); s.addSpacer(14)
        s.add(fieldLabel14("Property Occupied By")); s.addSpacer(8)
        for option in Self.occupiedByOptions {
            let row = UIStackView.h(10, [
                UIImageView(symbol: occupiedBy == option ? "largecircle.fill.circle" : "circle", size: 20,
                            color: occupiedBy == option ? .appPrimary : .grey600),
                UILabel(option, font: .poppins(13), color: .appTextDark), FlexSpacer(),
            ]).padded(UIEdgeInsets(top: 6, left: 4, bottom: 6, right: 0))
            row.onTap { [weak self] in
                self?.occupiedBy = option
                self?.render()
            }
            s.add(row)
        }
        if occupiedBy == "Other" {
            for f in [occupierName, occupierFather, occupierMobile, occupierTime] { s.addSpacer(12); s.add(f) }
        }
        s.addSpacer(26)
        s.add(sectionTitle("New Owner Details")); s.addSpacer(4)
        s.add(hint("Details of the applicant/new owner.")); s.addSpacer(14)
        s.add(newOwner); s.addSpacer(12)
        let salutationField = AssessmentUI.selectField("")
        salutationField.value = salutation
        salutationField.setSize(width: 96)
        salutationField.onTap = { [weak self] in
            self?.pickOption("Select", Self.salutations) { i in
                self?.salutation = Self.salutations[i]
                salutationField.value = Self.salutations[i]
            }
        }
        s.add(UIStackView.h(12, alignment: .top, [salutationField, fatherName])); s.addSpacer(12)
        for f in [mobile, altMobile, email] { s.add(f); s.addSpacer(12) }
        s.addSpacer(14)
        s.add(sectionTitle("Communication Address")); s.addSpacer(4)
        s.add(hint("Where letters and notices should be delivered.")); s.addSpacer(14)
        s.add(commAddress); s.addSpacer(12)
        s.add(pinCode)
    }

    private func renderStep3() {
        let s = contentStack
        s.add(sectionTitle("Registry & Cost Details")); s.addSpacer(4)
        s.add(hint("Used to calculate the applicable mutation fees.")); s.addSpacer(14)
        s.add(propertyCost); s.addSpacer(12)
        s.add(registryDate); s.addSpacer(16)
        s.add(calcButton)
        s.add(feesArea)
        renderFeesArea()
    }

    private func renderFeesArea() {
        feesArea.arrangedSubviews.forEach { feesArea.removeArrangedSubview($0); $0.removeFromSuperview() }
        calcButton.isEnabled = !isLoadingFees
        calcButton.setTitle(isLoadingFees ? "Calculating..." : "Calculate Mutation Fees", for: .normal)
        if let feesError {
            feesArea.addSpacer(10)
            feesArea.add(UILabel(feesError, font: .poppins(12.5), color: .mRed, lines: 0))
        }
        guard let fees else { return }
        feesArea.addSpacer(16)
        let card = CardView(radius: 14, shadowOpacity: 0, border: .grey200)
        card.stack.add(UIStackView.h(8, [UIImageView(symbol: "list.bullet.rectangle.portrait", size: 16, color: .appPrimary),
                                         UILabel("Fee Breakdown", font: .poppins(14, .bold), color: .appTextDark)]))
        card.stack.addSpacer(10)
        func row(_ l: String, _ v: String, amount: Bool = true) {
            card.stack.add(UIStackView.h(8, [UILabel(l, font: .poppins(12.5), color: .grey700), FlexSpacer(),
                                             UILabel(amount ? "₹\(MutationUI.formatAmount(v))" : v, font: .poppins(12.5, .semibold),
                                                     color: .appTextDark, lines: 0, alignment: .right)])
                .padded(UIEdgeInsets(top: 3, left: 0, bottom: 3, right: 0)))
        }
        row("Mutation Fees", fees.mutationFees)
        row("Late Fees", fees.lateFees)
        row("Publication Fees", fees.publicationFees)
        row("Processing Fees", fees.processingFees)
        row("ULB Processing Fees", fees.ulbProcessingFees)
        if let rate = Double(fees.discountRate), rate > 0 { row("Discount Rate", "\(fees.discountRate)%", amount: false) }
        if let online = Double(fees.onlineDiscountAmount), online > 0 { row("Online Discount", fees.onlineDiscountAmount) }
        row("Evidence", fees.evidence, amount: false)
        card.stack.add(divider(color: .grey300, thickness: 0.5).padded(UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)))
        card.stack.add(UIStackView.h(8, [UILabel("Total Payable", font: .poppins(14, .bold), color: .appTextDark), FlexSpacer(),
                                         UILabel("₹\(MutationUI.formatAmount(fees.fees))", font: .poppins(16, .bold), color: .appPrimary)]))
        feesArea.add(card)
    }

    private func renderStep4() {
        let s = contentStack
        s.add(sectionTitle("Upload Documents")); s.addSpacer(4)
        s.add(hint("Documents must be PDF, up to 200 KB each. Occupier photo must be JPG.")); s.addSpacer(18)
        let items: [(String, String, [String], String)] = [
            ("idProofDoc", "ID Proof Document", ["pdf"], "No file chosen (PDF, max 200 KB)"),
            ("affidavitDoc", "Affidavit", ["pdf"], "No file chosen (PDF, max 200 KB)"),
            ("occupierPhotoDoc", "Occupier Photo", ["jpg", "jpeg"], "No file chosen (JPG, max 200 KB)"),
            ("registryFirstFront", "Registry - First Page (Front)", ["pdf"], "No file chosen (PDF, max 200 KB)"),
            ("registryFirstBack", "Registry - First Page (Back)", ["pdf"], "No file chosen (PDF, max 200 KB)"),
            ("registryLastFront", "Registry - Last Page (Front)", ["pdf"], "No file chosen (PDF, max 200 KB)"),
            ("registryLastBack", "Registry - Last Page (Back)", ["pdf"], "No file chosen (PDF, max 200 KB)"),
            ("additionalDoc", "Additional Document (optional)", ["pdf"], "No file chosen (PDF, max 200 KB)"),
        ]
        for (i, item) in items.enumerated() {
            s.add(fieldLabel14(item.1)); s.addSpacer(8)
            s.add(fileRow(key: item.0, extensions: item.2, hint: item.3))
            if i < items.count - 1 { s.addSpacer(18) }
        }
    }

    private func fileRow(key: String, extensions: [String], hint: String) -> UIView {
        let file = docs[key]
        let choose = OutlineButton(file == nil ? "Choose File" : "Replace", color: .appPrimary, borderColor: .appPrimary,
                                   height: 36, radius: 8, fontSize: 13)
        choose.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        choose.setContentHuggingPriority(.required, for: .horizontal)
        choose.onEvent { [weak self] in self?.pickDocument(key: key, extensions: extensions) }
        let name = UILabel(file?.filename ?? hint, font: .poppins(13), color: file == nil ? .grey600 : .appTextDark)
        name.lineBreakMode = .byTruncatingTail
        var views: [UIView] = [choose, name]
        if file != nil { views.append(UIImageView(symbol: "checkmark.circle.fill", size: 18, color: .mGreen)) }
        let row = UIStackView.h(12, views).padded(12)
        row.backgroundColor = .white
        row.layer.cornerRadius = 12
        row.addBorder(color: .grey300)
        return row
    }

    private func infoRow(_ label: String, _ value: String, labelWidth: CGFloat, fontSize: CGFloat, labelSize: CGFloat,
                         alignRight: Bool) -> UIView {
        let l = UILabel(label, font: .poppins(labelSize), color: .grey600, lines: 0)
        l.setSize(width: labelWidth)
        let v = UILabel(value.trimmingCharacters(in: .whitespaces).isEmpty ? "-" : value.trimmingCharacters(in: .whitespaces),
                        font: .poppins(fontSize, .semibold), color: .appTextDark, lines: 0, alignment: alignRight ? .right : .natural)
        return UIStackView.h(0, alignment: .top, [l, v]).padded(UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0))
    }

    private func pickOption(_ title: String, _ options: [String], _ onSelect: @escaping (Int) -> Void) {
        view.endEditing(true)
        OptionPickerSheet.present(on: self, title: title, options: options, selected: nil, searchable: true, onSelect: onSelect)
    }

    // MARK: - Step 1 lookup

    private func onPropertySelected(_ p: PropertyEntity) {
        view.endEditing(true)
        selectedProperty = p
        propertyData = nil
        causeId = nil
        idProofId = nil
        fees = nil
        feesError = nil
        isLoadingProperty = true
        propertyError = nil
        render()
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: p.propertyId, mobileNo: p.phoneNumber,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.getMutationPropertyData(propertyId: p.propertyId)
                }
                guard selectedProperty == p else { return }
                isLoadingProperty = false
                if response.success, let data = response.data {
                    propertyData = data
                    mobile.text = data.mobile == "0" ? "" : data.mobile
                } else {
                    propertyError = response.message.isEmpty ? "Property details not found for this Property ID." : response.message
                }
            } catch {
                guard selectedProperty == p else { return }
                isLoadingProperty = false
                propertyError = APIError.userMessage(error)
            }
            if step == 0 { render() }
        }
    }

    // MARK: - Step 3 fees

    private func pickRegistryDate() {
        view.endEditing(true)
        DatePickerSheet.present(on: self, initial: Date(),
                                minimum: Calendar.current.date(from: DateComponents(year: 1950, month: 1, day: 1)),
                                maximum: Date()) { [weak self] date in
            guard let self else { return }
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            self.registryDate.text = f.string(from: date)
            self.registryDate.setError(nil)
            self.fees = nil
            self.feesError = nil
            self.renderFeesArea()
        }
    }

    private func fetchFees() {
        guard ![propertyCost, registryDate].map({ $0.validate() }).contains(false) else { return }
        guard let ulbId, !ulbId.isEmpty else { snack("ULB not found. Please open Dashboard first."); return }
        guard let cause = causeId, let property = propertyData else { snack("Please select a Mutation Cause in Step 1"); return }
        view.endEditing(true)
        isLoadingFees = true
        feesError = nil
        fees = nil
        renderFeesArea()
        let cost = propertyCost.trimmedText, date = registryDate.trimmedText, mobileNo = mobile.trimmedText
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: property.propertyId, mobileNo: mobileNo,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.getMutationFees(ulbId: ulbId, propertyCost: cost, mutationCause: cause,
                                                                currentArv: property.arv, registryDate: date)
                }
                isLoadingFees = false
                if response.success, let data = response.data { fees = data } else {
                    feesError = response.message.isEmpty ? "Unable to calculate mutation fees." : response.message
                }
            } catch {
                isLoadingFees = false
                feesError = APIError.userMessage(error)
            }
            renderFeesArea()
        }
    }

    // MARK: - Step 4 documents

    private func pickDocument(key: String, extensions: [String]) {
        view.endEditing(true)
        Task {
            guard let file = await MediaPicker.pickDocument(from: self, extensions: extensions) else { return }
            if file.sizeInBytes > Self.maxDocSize {
                let kb = String(format: "%.1f", Double(file.sizeInBytes) / 1024)
                AppDialog.show(on: self, icon: "exclamationmark.circle", iconColor: .mRed, iconSize: 28, title: "File Too Large",
                               message: "Selected file size is \(kb)KB which exceeds the 200KB limit.\n\nPlease select a smaller file.",
                               actions: [.init(title: "OK")])
                return
            }
            docs[key] = file
            render()
        }
    }

    // MARK: - Navigation / validation

    private func handleContinue() {
        view.endEditing(true)
        let isLast = step == Self.totalSteps - 1
        if !(Self.skipStepValidation && !isLast) && !validateCurrentStep() { return }
        if !isLast {
            step += 1
            render()
            return
        }
        submit()
    }

    private func validateCurrentStep() -> Bool {
        switch step {
        case 0:
            if propertyData == nil { snack("Please select a Property ID first"); return false }
            if causeId == nil { snack("Please select the Mutation Cause"); return false }
            if idProofId == nil { snack("Please select an ID Proof Type"); return false }
            return true
        case 1:
            let fields = [newOwner, fatherName, mobile, altMobile, email, commAddress, pinCode] +
                (occupiedBy == "Other" ? [occupierName, occupierFather, occupierMobile, occupierTime] : [])
            guard !fields.map({ $0.validate() }).contains(false) else { return false }
            if occupiedBy == "Other",
               occupierName.trimmedText.isEmpty || occupierFather.trimmedText.isEmpty || occupierMobile.trimmedText.isEmpty {
                snack("Please enter the occupier details")
                return false
            }
            return true
        case 2:
            guard ![propertyCost, registryDate].map({ $0.validate() }).contains(false) else { return false }
            if isLoadingFees { snack("Please wait, calculating the applicable fees..."); return false }
            if fees == nil { snack(feesError ?? "Please calculate the mutation fees before continuing."); return false }
            return true
        default:
            if docs["idProofDoc"] == nil { snack("Please upload the ID Proof document"); return false }
            if docs["affidavitDoc"] == nil { snack("Please upload the Affidavit document"); return false }
            if docs["occupierPhotoDoc"] == nil { snack("Please upload the Occupier Photo"); return false }
            if ["registryFirstFront", "registryFirstBack", "registryLastFront", "registryLastBack"].contains(where: { docs[$0] == nil }) {
                snack("Please upload all four registry pages")
                return false
            }
            return true
        }
    }

    private func submit() {
        guard let property = propertyData else { return }
        isSubmitting = true
        continueButton.isLoading = true
        backButton.isEnabled = false
        interceptsBack = true
        let isSelf = occupiedBy == "Self"
        let data: [String: Any] = [
            "propertyId": property.propertyId, "ulbId": APIService.intOrString(ulbId ?? ""),
            "oldOwnerName": property.ownerName, "oldFatherHusbandName": property.fatherName,
            "oldAddress": property.address, "oldMobileNo": property.mobile, "zoneName": property.zoneName,
            "zoneId": APIService.intOrString(property.zoneId), "wardName": property.wardName,
            "wardId": APIService.intOrString(property.wardId), "mohallaName": property.mohallaName,
            "currentArv": APIService.numOrString(property.arv), "propertyOccupiedBy": occupiedBy,
            "occupierName": isSelf ? "" : occupierName.trimmedText,
            "occupierFatherName": isSelf ? "" : occupierFather.trimmedText,
            "occupierMobile": isSelf ? "" : occupierMobile.trimmedText,
            "occupierTime": isSelf ? "" : occupierTime.trimmedText,
            "propertyCost": APIService.numOrString(propertyCost.trimmedText), "registryDate": registryDate.trimmedText,
            "mutationCause": APIService.intOrString(causeId ?? ""), "idProofType": APIService.intOrString(idProofId ?? ""),
            "newOwnerName": newOwner.trimmedText, "fatherHusbandSalutation": salutation,
            "fatherHusbandName": fatherName.trimmedText, "mobileNo": mobile.trimmedText,
            "alternateMobileNo": altMobile.trimmedText, "emailId": email.trimmedText,
            "communicationAddress": commAddress.trimmedText, "pinCode": pinCode.trimmedText, "flagJuj": flagJuj,
        ]
        var files: [(field: String, file: UploadFile)] = []
        for key in ["idProofDoc", "affidavitDoc", "occupierPhotoDoc", "registryFirstFront", "registryFirstBack",
                    "registryLastFront", "registryLastBack", "additionalDoc"] {
            if let f = docs[key] { files.append((key, f.upload)) }
        }
        let mobileNo = mobile.trimmedText
        Task {
            var ackNo: String?
            var totalFees: Double?
            var errorMessage: String?
            do {
                let response = try await OtpGateService.guardCall(propertyId: property.propertyId, mobileNo: mobileNo,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.applyMutation(data: data, files: files)
                }
                if response.success {
                    ackNo = response.ackNo
                    totalFees = response.totalFees
                } else {
                    errorMessage = response.message.isEmpty
                        ? "Failed to submit the mutation application. Please try again." : response.message
                }
            } catch {
                errorMessage = APIError.userMessage(error)
            }
            isSubmitting = false
            continueButton.isLoading = false
            backButton.isEnabled = true
            interceptsBack = step > 0
            if let errorMessage { snack(errorMessage); return }
            var message = "Your property mutation application has been submitted."
            if let ackNo { message += "\n\nAcknowledgement No: \(ackNo)" }
            if let totalFees { message += "\nTotal Fees: ₹\(MutationUI.formatAmount(JSON.dartNumString(totalFees)))" }
            AppDialog.show(on: self, icon: "checkmark.circle.fill", iconColor: .mGreen, iconSize: 28, title: "Submitted",
                           message: message, actions: [.init(title: "OK") { [weak self] in
                               self?.navigationController?.popViewController(animated: true)
                           }], dismissible: false)
        }
    }
}

/// Port of lib/mutation_application_detail_screen.dart.
final class MutationApplicationDetailViewController: BaseViewController {

    override var screenBackground: UIColor { MutationUI.background }
    private let ackNo: String
    private let refresh = UIRefreshControl()

    init(ackNo: String) {
        self.ackNo = ackNo
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Mutation Application", titleColor: .appTextDark, backColor: .appPrimary, titleSize: 17,
                     titleWeight: .semibold)
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 28, right: 16))
        refresh.tintColor = .appPrimary
        refresh.addAction(UIAction { [weak self] _ in Task { await self?.fetch(showSpinner: false) } }, for: .valueChanged)
        scrollView.refreshControl = refresh
        Task { await fetch(showSpinner: true) }
    }

    private func fetch(showSpinner: Bool) async {
        if showSpinner { setLoading(true) }
        defer { refresh.endRefreshing(); setLoading(false) }
        do {
            let response = try await APIService.shared.getMutationApplicationDetail(ackNo: ackNo)
            if response.success, let d = response.data {
                render(d)
            } else {
                renderError(response.message.isEmpty ? "No mutation application found for this acknowledgement number." : response.message)
            }
        } catch {
            renderError(APIError.userMessage(error, fallback: "Unable to fetch application details. Please try again."))
        }
    }

    private func clear() {
        contentStack.arrangedSubviews.forEach { contentStack.removeArrangedSubview($0); $0.removeFromSuperview() }
    }

    private func renderError(_ message: String) {
        clear()
        contentStack.add(AssessmentUI.messageState(icon: "wifi.slash", title: "Something went wrong", subtitle: message) {
            [weak self] in Task { await self?.fetch(showSpinner: true) }
        }.padded(UIEdgeInsets(top: 20, left: 8, bottom: 0, right: 8)))
    }

    private func sectionCard(icon: String, title: String) -> CardView {
        let card = CardView(radius: 16, padding: .zero, shadowOpacity: 0.05, shadowBlur: 12, shadowY: 4)
        card.stack.add(UIStackView.h(10, [iconTile(icon, background: AssessmentUI.softPrimary, size: 31, iconSize: 16, radius: 9),
                                          UILabel(title, font: .poppins(14.5, .bold), color: .appTextDark, lines: 0)])
            .padded(UIEdgeInsets(top: 14, left: 16, bottom: 12, right: 16)))
        card.stack.add(divider(color: .grey300, thickness: 0.5))
        return card
    }

    private func row(_ label: String, _ value: String) -> UIView {
        let l = UILabel(label, font: .poppins(12.5), color: .grey600, lines: 0)
        l.setSize(width: 140)
        let t = value.trimmingCharacters(in: .whitespaces)
        let v = UILabel(t.isEmpty ? "-" : t, font: .poppins(13, .semibold), color: .appTextDark, lines: 0, alignment: .right)
        return UIStackView.h(0, alignment: .top, [l, v]).padded(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0))
    }

    private func render(_ d: MutationApplicationDetail) {
        clear()
        let s = contentStack
        // Header
        let header = CardView(radius: 16, shadowOpacity: 0.05, shadowBlur: 12, shadowY: 4)
        let ack = UILabel(d.ackNo.isEmpty ? ackNo : d.ackNo, font: .poppins(17, .bold), color: .appTextDark)
        ack.lineBreakMode = .byTruncatingTail
        let copy = UIImageView(symbol: "doc.on.doc", size: 14, color: .appPrimary)
        copy.onTap { [weak self] in
            guard let self else { return }
            UIPasteboard.general.string = self.ackNo
            self.snack("Acknowledgement number copied")
        }
        let applied = UILabel("Applied \(MutationUI.formatDate(d.ackDate))", font: .poppins(12.5, .semibold), color: .appPrimary)
            .padded(UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 12))
        applied.backgroundColor = UIColor.appPrimary.withAlphaComponent(0.12)
        applied.layer.cornerRadius = 14
        applied.setContentHuggingPriority(.required, for: .horizontal)
        applied.setContentCompressionResistancePriority(.required, for: .horizontal)
        header.stack.add(UIStackView.h(8, alignment: .top, [
            UIStackView.v(3, [UILabel("Acknowledgement No.", font: .poppins(12), color: .grey600),
                              UIStackView.h(6, [ack, copy, FlexSpacer()])]),
            applied,
        ]))
        s.add(header)
        s.addSpacer(16)

        let property = sectionCard(icon: "building.2", title: "Property & Previous Owner")
        let pRows = UIStackView.v(0, [])
        for (l, v) in [("Property ID", d.propertyId), ("Previous Owner", d.oldOwnerName),
                       ("Father/Husband Name", d.oldFatherHusbandName), ("Mobile No.", d.oldMobileNo),
                       ("Address", d.oldAddress), ("Zone / Ward / Mohalla", "\(d.zoneName) / \(d.wardName) / \(d.mohallaName)"),
                       ("Mutation Cause", MutationUI.prettify(d.mutationCauseString)),
                       ("Property Occupied By", d.propertyOccupiedBy)] { pRows.add(row(l, v)) }
        property.stack.add(pRows.padded(UIEdgeInsets(top: 8, left: 16, bottom: 12, right: 16)))
        s.add(property)
        s.addSpacer(16)

        let owner = sectionCard(icon: "person", title: "New Owner / Applicant")
        let oRows = UIStackView.v(0, [])
        for (l, v) in [("Occupier Name", d.occupierName), ("Father/Husband Name", d.fatherHusbandName),
                       ("Mobile No.", d.mobileNo), ("Alternate Mobile", d.alternateMobileNo), ("Email", d.emailId),
                       ("Communication Address", d.communicationAddress), ("PIN Code", d.occPinCode)] { oRows.add(row(l, v)) }
        owner.stack.add(oRows.padded(UIEdgeInsets(top: 8, left: 16, bottom: 12, right: 16)))
        s.add(owner)
        s.addSpacer(16)

        let fees = sectionCard(icon: "list.bullet.rectangle.portrait", title: "Fees & Registry")
        let fRows = UIStackView.v(0, [])
        let a = MutationUI.formatAmount
        for (l, v) in [("Property Cost", "₹\(a(d.propertyCost))"), ("Registry Date", MutationUI.formatDate(d.registryDate)),
                       ("Current ARV", "₹\(a(d.currentArv))"), ("Mutation Fees", "₹\(a(d.mutationFees))"),
                       ("Late Fees", "₹\(a(d.lateFees))"), ("Publication Fees", "₹\(a(d.publicationFees))"),
                       ("Processing Fees", "₹\(a(d.processingFees))"), ("ULB Processing Fees", "₹\(a(d.ulbProcessingFees))"),
                       ("Residual Fees", "₹\(a(d.residualFees))")] { fRows.add(row(l, v)) }
        fees.stack.add(fRows.padded(UIEdgeInsets(top: 8, left: 16, bottom: 6, right: 16)))
        fees.stack.add(divider(color: .grey300, thickness: 0.5).padded(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)))
        fees.stack.add(UIStackView.h(8, [UILabel("Total Fees", font: .poppins(14, .bold), color: .appTextDark), FlexSpacer(),
                                         UILabel("₹\(a(d.totalFees))", font: .poppins(16, .bold), color: .appPrimary)])
            .padded(UIEdgeInsets(top: 10, left: 16, bottom: 16, right: 16)))
        s.add(fees)
    }
}

extension JSON {
    /// Dart `num.toString()` for a value parsed as double (whole numbers print without ".0"
    /// when they came from an int literal; this keeps the common int case readable).
    static func dartNumString(_ d: Double) -> String {
        d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : "\(d)"
    }
}
