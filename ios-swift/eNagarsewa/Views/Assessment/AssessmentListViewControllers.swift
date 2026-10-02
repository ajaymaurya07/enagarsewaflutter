import UIKit

/// Port of lib/assessment_type_selection_screen.dart.
final class AssessmentTypeSelectionViewController: BaseViewController {

    override var screenBackground: UIColor { .appFieldFill }
    private var reassessment = false
    private var tabs: [UIView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Property Tax Assessment", titleColor: AssessmentUI.textColor, backColor: .appPrimary,
                     titleSize: 17, titleWeight: .semibold)
        let continueButton = AssessmentUI.actionButton("Continue")
        continueButton.onEvent { [weak self] in
            guard let self else { return }
            self.push(self.reassessment ? ReassessmentViewController() : AssessmentListViewController())
        }
        let bar = UIView()
        bar.addSubview(continueButton)
        view.addSubview(bar)
        bar.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            continueButton.topAnchor.constraint(equalTo: bar.topAnchor, constant: 16),
            continueButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            continueButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            continueButton.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -16),
        ])
        installScrollStack(above: bar)
        contentStack.add(UILabel("What would you like to do?", font: .poppins(16, .bold), color: AssessmentUI.textColor))
        contentStack.addSpacer(16)
        let row = UIStackView.h(12, alignment: .fill, [])
        row.distribution = .fillEqually
        contentStack.add(row)
        for (i, item) in [("Assessment", "Assess a property for the first time", "chart.bar.doc.horizontal"),
                          ("Re-Assessment", "Reassess an already assessed property", "checklist.checked")].enumerated() {
            let tab = UIView()
            tab.layer.cornerRadius = 16
            tab.onTap { [weak self] in
                self?.reassessment = i == 1
                self?.render()
            }
            tab.accessibilityLabel = item.0
            tab.tag = i
            let stack = UIStackView.v(0, [
                UIStackView.h(0, [UIImageView(symbol: item.2, size: 24, color: .appPrimary), FlexSpacer(), UIImageView()]),
                UILabel(item.0, font: .poppins(14, .bold), color: .appTextMid),
                UILabel(item.1, font: .poppins(11), color: .appTextSub, lines: 0),
            ])
            stack.setCustomSpacing(14, after: stack.arrangedSubviews[0])
            stack.setCustomSpacing(4, after: stack.arrangedSubviews[1])
            tab.addSubview(stack)
            stack.pinToEdges(of: tab, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
            row.addArrangedSubview(tab)
            tabs.append(tab)
        }
        render()
    }

    private func render() {
        for tab in tabs {
            let selected = (tab.tag == 1) == reassessment
            tab.backgroundColor = selected ? AssessmentUI.softPrimary : .white
            tab.layer.borderWidth = selected ? 1.5 : 1
            tab.layer.borderColor = (selected ? UIColor.appPrimary : .grey300).cgColor
            if let header = (tab.subviews.first as? UIStackView)?.arrangedSubviews.first as? UIStackView,
               let radio = header.arrangedSubviews.last as? UIImageView {
                radio.image = .symbol(selected ? "largecircle.fill.circle" : "circle", size: 18)
                radio.tintColor = selected ? .appPrimary : .grey400
            }
        }
    }
}

/// Common list screen for assessments (fresh) and re-assessments.
class AssessmentApplicationsListViewController: BaseViewController {

    override var screenBackground: UIColor { .appFieldFill }

    enum Kind { case assessment, reassessment }
    let kind: Kind
    private var items: [ReassessmentListItem] = []
    private var deletingAckNo: String?
    private var isLoading = true
    private var errorMessage: String?
    private let listStack = UIStackView.v(14, [])
    private let refresh = UIRefreshControl()
    var needsReload = false

    init(kind: Kind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var isRe: Bool { kind == .reassessment }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: isRe ? "Property Re-Assessment" : "Property Tax Assessment", titleColor: AssessmentUI.textColor,
                     backColor: .appPrimary, titleSize: 17, titleWeight: .semibold)
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16))
        refresh.tintColor = .appPrimary
        refresh.addAction(UIAction { [weak self] _ in Task { await self?.fetch() } }, for: .valueChanged)
        scrollView.refreshControl = refresh

        let newButton = PrimaryButton(isRe ? "Re-Assessment" : "New Assessment", height: 50, radius: 12, fontSize: 15,
                                      weight: .semibold, icon: "plus.circle")
        newButton.onEvent { [weak self] in self?.handleNew() }
        contentStack.add(newButton)
        contentStack.addSpacer(24)
        contentStack.add(UILabel(isRe ? "Re-Assessment Summary" : "Assessment Summary", font: .poppins(16, .bold),
                                 color: AssessmentUI.textColor))
        contentStack.addSpacer(12)
        contentStack.add(listStack)
        Task { await fetch() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if needsReload {
            needsReload = false
            Task { await fetch() }
        }
    }

    func fetch() async {
        isLoading = true
        errorMessage = nil
        render()
        do {
            let response = try await OtpGateService.guardCall(propertyId: "", mobileNo: "", responseCode: { $0.responseCode }) {
                if self.isRe { return try await APIService.shared.getReassessmentList() }
                return try await APIService.shared.getAssessmentList()
            }
            if response.success != true {
                errorMessage = response.message ?? (isRe ? "Failed to fetch re-assessment list" : "Failed to fetch assessment list")
            } else {
                items = response.data
            }
        } catch {
            errorMessage = APIError.userMessage(error, fallback: isRe
                ? "Unable to fetch re-assessment list. Please try again."
                : "Unable to fetch assessment list. Please try again.")
        }
        isLoading = false
        refresh.endRefreshing()
        render()
    }

    private func render() {
        listStack.removeAllArranged()
        if isLoading {
            let s = UIActivityIndicatorView(style: .large)
            s.color = .appPrimary
            s.startAnimating()
            listStack.add(centered(s).padded(UIEdgeInsets(top: 60, left: 0, bottom: 60, right: 0)))
            return
        }
        if let errorMessage {
            listStack.add(AssessmentUI.messageState(icon: "wifi.slash", title: "Something went wrong", subtitle: errorMessage) {
                [weak self] in Task { await self?.fetch() }
            })
            return
        }
        if items.isEmpty {
            listStack.add(AssessmentUI.messageState(
                icon: "doc.text", title: isRe ? "No re-assessments yet" : "No assessments yet",
                subtitle: isRe ? "Re-Assessments you start will appear here so you can track their progress."
                               : "Assessments you start will appear here so you can track their progress.",
                retry: nil))
            return
        }
        for item in items { listStack.add(card(item)) }
    }

    private func card(_ item: ReassessmentListItem) -> UIView {
        let krutidev = isRe && UlbLanguageHelper.isKrutidev
        let card = CardView(radius: 16, padding: .zero, shadowOpacity: 0.05, shadowBlur: 12, shadowY: 4)
        let owner = item.ownerName?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? item.ownerName!.trimmingCharacters(in: .whitespaces) : "Unknown Owner"
        let ownerLabel = UILabel(owner, font: UlbLanguageHelper.font(15, .bold, krutidev: krutidev), color: AssessmentUI.textColor)
        ownerLabel.lineBreakMode = .byTruncatingTail
        let header = UIStackView.h(8, alignment: .top, [
            UIStackView.v(2, [ownerLabel, UILabel("Ack: \(item.ackNo ?? "-")", font: .poppins(12), color: .grey600)]),
            AssessmentUI.statusChip(completed: item.isCompletedFlag),
        ])
        card.stack.add(header.padded(UIEdgeInsets(top: 14, left: 16, bottom: 12, right: 16)), divider(color: .grey300, thickness: 0.5))

        func trimmed(_ v: String?) -> String {
            let t = v?.trimmingCharacters(in: .whitespaces) ?? ""
            return t.isEmpty ? "-" : t
        }
        var rows: [(String, String, Bool)] = []
        if isRe { rows.append(("Property ID", item.propertyId ?? "-", false)) }
        rows += [("House No.", trimmed(item.houseNo), false), ("Address", trimmed(item.address), isRe),
                 ("Assess Date", item.assessDate ?? "-", false)]
        let details = UIStackView.v(0, [])
        for (label, value, language) in rows {
            let l = UILabel(label, font: .poppins(12), color: .grey600)
            l.setSize(width: 88)
            let v = UILabel(value, font: UlbLanguageHelper.font(12.5, .semibold, krutidev: language && krutidev),
                            color: AssessmentUI.textColor, lines: 0, alignment: .right)
            details.add(UIStackView.h(0, alignment: .top, [l, v]).padded(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)))
        }
        card.stack.add(details.padded(UIEdgeInsets(top: 12, left: 16, bottom: 4, right: 16)))

        let footer = UIStackView.v(10, [])
        if isRe && !item.isCompletedFlag {
            let badge = UIStackView.h(5, [UIImageView(symbol: "point.topleft.down.curvedto.point.bottomright.up", size: 12, color: .grey600),
                                          UILabel("Stage \(item.currentStage ?? 0) of 4", font: .poppins(11, .semibold), color: .grey700)])
                .padded(UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))
            badge.backgroundColor = .white
            badge.layer.cornerRadius = 8
            badge.addBorder(color: .grey300)
            footer.add(UIStackView.h(0, [FlexSpacer(), badge]))
        }
        let isDeleting = item.ackNo != nil && deletingAckNo == item.ackNo
        let see = AssessmentUI.outlineAction("See Details", icon: "eye", color: .appPrimary)
        see.isEnabled = !isDeleting
        see.onEvent { [weak self] in self?.seeDetails(item) }
        let actions = UIStackView.h(10, alignment: .fill, [see])
        actions.distribution = .fillEqually
        if !item.isCompletedFlag {
            let del = AssessmentUI.outlineAction(isDeleting ? "Deleting..." : "Delete", icon: "trash", color: .mRed700)
            del.isEnabled = !isDeleting
            del.onEvent { [weak self] in self?.delete(item) }
            actions.addArrangedSubview(del)
        }
        footer.add(actions)
        card.stack.add(footer.padded(UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)))
        card.onTap { [weak self] in
            guard let self else { return }
            if self.isRe { self.handleCardTap(item) } else { self.seeDetails(item) }
        }
        return card
    }

    // MARK: Actions

    private func handleNew() {
        if isRe {
            let vc = NewReassessmentViewController()
            vc.onBackWithResult = { [weak self] in self?.needsReload = true }
            push(vc)
        } else {
            push(PropertyTaxAssessmentViewController())
        }
    }

    private func seeDetails(_ item: ReassessmentListItem) {
        guard let ackNo = item.ackNo else { return }
        Task {
            var property: PropertyEntity?
            if let pid = item.propertyId { property = await DatabaseService.shared.getPropertyById(pid) }
            push(AssessmentApplicationDetailViewController(ackNo: ackNo, propertyId: item.propertyId ?? "",
                                                           mobileNo: property?.phoneNumber ?? "", isReassessment: isRe))
        }
    }

    /// Re-assessment cards resume the flow at the backend's `next_stage`.
    private func handleCardTap(_ item: ReassessmentListItem) {
        guard let propertyId = item.propertyId, let ackNo = item.ackNo else { return }
        Task {
            let mobile = await DatabaseService.shared.getPropertyById(propertyId)?.phoneNumber ?? ""
            guard let next = item.nextStage else {
                if item.isCompletedFlag { seeDetails(item) } else {
                    snack("No further action is available for this re-assessment right now.")
                }
                return
            }
            if next >= 4 {
                push(AssessmentDocumentUploadViewController(ackNo: ackNo, isReassessment: true, propertyId: propertyId, mobileNo: mobile))
            } else {
                push(AssessmentStep2ViewController(ackNo: ackNo, propertyId: propertyId, mobileNo: mobile, isReassessment: true))
            }
        }
    }

    private func delete(_ item: ReassessmentListItem) {
        guard let ackNo = item.ackNo, !item.isCompletedFlag else { return }
        let noun = isRe ? "re-assessment" : "assessment"
        AppDialog.show(on: self, title: isRe ? "Delete Re-Assessment?" : "Delete Assessment?",
                       message: "This will permanently remove the in-progress \(noun) \(ackNo). This action cannot be undone.",
                       actions: [
            .init(title: "Cancel", style: .cancel, color: .grey700),
            .init(title: "Delete", style: .destructive, color: .mRed700) { [weak self] in self?.performDelete(item, ackNo: ackNo) },
        ])
    }

    private func performDelete(_ item: ReassessmentListItem, ackNo: String) {
        deletingAckNo = ackNo
        render()
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: item.propertyId ?? "", mobileNo: "",
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.deleteAssessment(ackNo: ackNo)
                }
                snack(response.message ?? (response.success == true
                    ? (isRe ? "Re-Assessment deleted successfully." : "Assessment deleted successfully.")
                    : (isRe ? "Failed to delete re-assessment" : "Failed to delete assessment")))
                deletingAckNo = nil
                if response.success == true { await fetch() } else { render() }
            } catch {
                deletingAckNo = nil
                render()
                snack(APIError.userMessage(error, fallback: isRe ? "Unable to delete this re-assessment. Please try again."
                                                                 : "Unable to delete this assessment. Please try again."))
            }
        }
    }
}

/// Port of lib/assessment_list_screen.dart.
final class AssessmentListViewController: AssessmentApplicationsListViewController {
    init() { super.init(kind: .assessment) }
    required init?(coder: NSCoder) { fatalError() }
}

/// Port of lib/reassessment_screen.dart.
final class ReassessmentViewController: AssessmentApplicationsListViewController {
    init() { super.init(kind: .reassessment) }
    required init?(coder: NSCoder) { fatalError() }
}

/// Port of lib/new_reassessment_screen.dart.
final class NewReassessmentViewController: BaseViewController {

    override var screenBackground: UIColor { .appFieldFill }
    var onBackWithResult: (() -> Void)?

    private var savedProperties: [PropertyEntity] = []
    private var selected: PropertyEntity?
    private var preCheck: ReassessmentGetS1Data?
    private var step1: ReassessmentStep1Data?
    private var isLoadingProperties = true
    private var isFetchingPreCheck = false
    private var didStart = false
    private let fileNoField = AssessmentUI.textField("Zonal File No.", keyboard: .numberPad, hint: "Enter Zonal File No.", floating: false)
    private let initButton = AssessmentUI.actionButton("Continue")
    private let floorsButton = AssessmentUI.actionButton("Continue to Floor Details")

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Re-Assessment", titleColor: AssessmentUI.textColor, backColor: .appPrimary, titleSize: 17,
                     titleWeight: .semibold)
        installScrollStack()
        initButton.onEvent { [weak self] in self?.handleInitialize() }
        floorsButton.onEvent { [weak self] in self?.handleContinueToFloors() }
        render()
        Task {
            savedProperties = await DatabaseService.shared.getAllProperties()
            isLoadingProperties = false
            render()
        }
    }

    /// The AppBar back button pops with `_didStartAnyReassessment` (always non-null), which
    /// makes the list refresh; swipe-back stays enabled as in Flutter (`canPop: true`).
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent { onBackWithResult?() }
    }

    private var activeAckNo: String? { step1?.ackNo ?? preCheck?.ackNo }

    private func render() {
        contentStack.removeAllArranged()
        let s = contentStack
        s.add(AssessmentUI.sectionTitle("Select Property"))
        s.addSpacer(12)
        if isLoadingProperties {
            let sp = UIActivityIndicatorView(style: .medium)
            sp.color = .appPrimary
            sp.startAnimating()
            s.add(centered(sp).padded(UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)))
        } else {
            let field = AssessmentUI.selectField(savedProperties.isEmpty ? "No saved property found" : "Select Property ID")
            field.value = selected?.propertyId
            if !savedProperties.isEmpty {
                field.onTap = { [weak self] in
                    guard let self else { return }
                    OptionPickerSheet.present(on: self, title: "Select Property", options: self.savedProperties.map(\.propertyId),
                                              selected: nil, searchable: true) { i in self.onPropertySelected(self.savedProperties[i]) }
                }
            }
            s.add(field)
        }
        if isFetchingPreCheck {
            let sp = UIActivityIndicatorView(style: .large)
            sp.color = .appPrimary
            sp.startAnimating()
            s.addSpacer(20)
            s.add(centered(sp))
        }
        let krutidev = UlbLanguageHelper.isKrutidevValue(selected?.ulbLang)
        if let pre = preCheck {
            s.addSpacer(24)
            s.add(AssessmentUI.sectionTitle("Last Re-Assessment Details"))
            s.addSpacer(12)
            s.add(AssessmentUI.infoCard([("Date of Last Assessment", pre.dateOfLastAssessment ?? "-", false),
                                         ("No. of Floors", "\(pre.noOfFloor ?? 0)", false),
                                         ("Ack No.", pre.ackNo ?? "-", false)], krutidev: krutidev, padding: 16, border: .grey300))
            if step1 == nil {
                s.addSpacer(20)
                s.add(initButton)
            }
        }
        if let d = step1 {
            s.addSpacer(24)
            s.add(AssessmentUI.sectionTitle("Property Details"))
            s.addSpacer(12)
            s.add(AssessmentUI.infoCard([
                ("Owner Name", d.ownerName ?? "-", true), ("Father/Husband Name", d.fatherName ?? "-", true),
                ("House No.", d.houseNo ?? "-", false), ("Address", d.address ?? "-", true),
                ("Zone", d.zoneName ?? "-", false), ("Ward", d.wardName ?? "-", false), ("Mohalla", d.mohallaName ?? "-", false),
                ("Road Location", d.roadLocationName ?? "-", false), ("Property Type", d.propertyTypeName ?? "-", false),
                ("Total Area", d.totalArea.map { "\(JSON.dartDoubleString($0)) sq.ft." } ?? "-", false),
                ("Old ARV", d.oldArv ?? "-", false),
            ], krutidev: krutidev, padding: 16, border: .grey300))
            s.addSpacer(16)
            s.add(AssessmentUI.labeled("Zonal File No.", fileNoField))
            s.addSpacer(20)
            s.add(floorsButton)
        }
        s.addSpacer(32)
    }

    private func onPropertySelected(_ p: PropertyEntity) {
        selected = p
        preCheck = nil
        step1 = nil
        isFetchingPreCheck = true
        render()
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: p.propertyId, mobileNo: p.phoneNumber,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.getReassessmentDetails(propertyId: p.propertyId)
                }
                isFetchingPreCheck = false
                if response.success == true, let data = response.data { preCheck = data } else {
                    snack(response.message ?? "Failed to fetch assessment details")
                }
            } catch {
                isFetchingPreCheck = false
                snack(APIError.userMessage(error, fallback: "Unable to fetch assessment details. Please try again."))
            }
            render()
        }
    }

    private func handleInitialize() {
        view.endEditing(true)
        guard let p = selected, let ack = preCheck?.ackNo else { return }
        initButton.isLoading = true
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: p.propertyId, mobileNo: p.phoneNumber,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.initializeReassessment(propertyId: p.propertyId, ackNo: ack)
                }
                initButton.isLoading = false
                if response.success == true, let data = response.data {
                    step1 = data
                    didStart = true
                    render()
                } else {
                    snack(response.message ?? "Failed to initialize re-assessment")
                }
            } catch {
                initButton.isLoading = false
                snack(APIError.userMessage(error, fallback: "Unable to initialize re-assessment. Please try again."))
            }
        }
    }

    private func handleContinueToFloors() {
        view.endEditing(true)
        guard let p = selected, let ack = activeAckNo else { return }
        let fileNo = fileNoField.trimmedText
        guard !fileNo.isEmpty else { snack("Please enter Zonal File No."); return }
        floorsButton.isLoading = true
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: p.propertyId, mobileNo: p.phoneNumber,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.fetchReassessmentFloorConfig(propertyId: p.propertyId, ackNo: ack, fileNo: fileNo)
                }
                floorsButton.isLoading = false
                guard response.success == true, let data = response.data else {
                    snack(response.message ?? "Failed to fetch floor configuration")
                    return
                }
                didStart = true
                push(AssessmentStep3ViewController(ackNo: data.ackNo ?? ack, floorNoList: data.floorNoList,
                                                   floorUsageList: data.floorUsageList,
                                                   constructionTypeList: data.constructionTypeList, isReassessment: true,
                                                   propertyId: data.propertyId ?? p.propertyId, mobileNo: p.phoneNumber))
            } catch {
                floorsButton.isLoading = false
                snack(APIError.userMessage(error, fallback: "Unable to fetch floor configuration. Please try again."))
            }
        }
    }
}

/// Port of lib/assessment_application_detail_screen.dart.
final class AssessmentApplicationDetailViewController: BaseViewController {

    override var screenBackground: UIColor { .appFieldFill }
    private let ackNo: String, propertyId: String, mobileNo: String, isReassessment: Bool

    init(ackNo: String, propertyId: String = "", mobileNo: String = "", isReassessment: Bool = false) {
        self.ackNo = ackNo
        self.propertyId = propertyId
        self.mobileNo = mobileNo
        self.isReassessment = isReassessment
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: isReassessment ? "Re-Assessment Details" : "Assessment Details", titleColor: AssessmentUI.textColor,
                     backColor: .appPrimary, titleSize: 17, titleWeight: .semibold)
        installScrollStack()
        Task { await fetch() }
    }

    private func fetch() async {
        contentStack.removeAllArranged()
        setLoading(true)
        do {
            let response = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: mobileNo,
                                                              responseCode: { $0.responseCode }) {
                try await APIService.shared.getAssessmentApplicationDetail(ackNo: self.ackNo)
            }
            setLoading(false)
            guard response.success == true, let data = response.data else {
                showError(response.message ?? "Failed to fetch application details")
                return
            }
            render(data)
        } catch {
            setLoading(false)
            showError(APIError.userMessage(error, fallback: "Unable to fetch application details. Please try again."))
        }
    }

    private func showError(_ message: String) {
        let retry = PrimaryButton("Retry", height: 40, radius: 20, fontSize: 14, weight: .medium)
        retry.contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        retry.onEvent { [weak self] in Task { await self?.fetch() } }
        let stack = UIStackView.v(0, alignment: .center, [
            UIImageView(symbol: "exclamationmark.circle", size: 56, color: .mRed),
            UILabel(message, font: .poppins(14), color: .black87, lines: 0, alignment: .center), retry,
        ])
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[0])
        stack.setCustomSpacing(24, after: stack.arrangedSubviews[1])
        contentStack.add(stack.padded(UIEdgeInsets(top: 120, left: 8, bottom: 0, right: 8)))
    }

    private static func text(_ v: String?) -> String {
        let t = v?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "-" : t
    }

    private static func money(_ v: String?) -> String {
        let t = text(v)
        return AssessmentApplicationDetailData.asNumber(t) == nil ? t : "₹\(t)"
    }

    private static func area(_ v: String?) -> String {
        let t = text(v)
        return AssessmentApplicationDetailData.asNumber(t) == nil ? t : "\(t) sq.ft."
    }

    private func render(_ d: AssessmentApplicationDetailData) {
        let krutidev = isReassessment && UlbLanguageHelper.isKrutidev
        let s = contentStack
        var headerViews: [UIView] = [
            UILabel("Ack No: \(Self.text(d.ackId))", font: .poppins(15, .bold), color: AssessmentUI.textColor, lines: 0),
            UILabel("Total ARV: \(Self.money(d.totalArv))", font: .poppins(13), color: .grey800),
        ]
        if let status = d.status?.trimmingCharacters(in: .whitespaces), !status.isEmpty {
            headerViews.append(UILabel(status, font: .poppins(12.5, .semibold), color: .appPrimary, lines: 0))
        }
        let header = UIStackView.v(4, headerViews).padded(14)
        header.backgroundColor = AssessmentUI.softPrimary
        header.layer.cornerRadius = 12
        header.addBorder(color: UIColor.appPrimary.withAlphaComponent(0.4))
        s.add(header)

        func section(_ title: String, _ icon: String, _ rows: [(String, String, Bool)]) {
            s.addSpacer(20)
            s.add(AssessmentUI.sectionTitle(title, icon: icon, size: 15))
            s.addSpacer(10)
            s.add(AssessmentUI.infoCard(rows, krutidev: krutidev))
        }
        let t = Self.text
        section("Owner Details", "person.text.rectangle", [
            ("Owner Name", t(d.ownerName), true), ("Father/Husband Name", t(d.fatherName), true),
            ("Mobile Number", t(d.mobile), false), ("Email", t(d.email), false),
        ])
        section("Property Details", "building.2", [
            ("Property ID", t(d.propertyId), false), ("House No.", t(d.houseNo), false), ("Address", t(d.address), true),
            ("Landmark", t(d.landmark), false), ("Point of Presence", t(d.popName), false), ("Zone", t(d.zoneName), false),
            ("Ward", t(d.wardName), false), ("Mohalla", t(d.mohallaName), false), ("Property Type", t(d.propertyTypeName), false),
            ("Nature of House", t(d.natureHouseName), false), ("Road Location", t(d.roadLocationName), false),
            ("Usage Detail", t(d.detail), false), ("File No.", t(d.fileNo), false),
            ("Total Area", Self.area(d.totalAreaOfProperty), false),
        ])
        section("Assessment Details", "doc.text", [
            ("Assess Type", t(d.assessType), false), ("Assess Date", t(d.assessDate), false), ("Total ARV", t(d.totalArv), false),
            ("Net ARV", t(d.netArv), false), ("Old ARV", t(d.oldArv), false), ("Entered On", t(d.enteredTs), false),
            ("Entered By", t(d.enteredBy), false), ("Assessment Order No.", t(d.assessOrderNo), false),
            ("Order Issued By", t(d.assessOrderIssuedBy), false), ("Order Date", t(d.assessOrderTs), false),
            ("Rebate Type", t(d.rebateType), false), ("Rebate Date", t(d.rebateDate), false),
        ])
        s.addSpacer(20)
        s.add(AssessmentUI.sectionTitle("Tax Breakdown", icon: "list.bullet.rectangle.portrait", size: 15))
        s.addSpacer(10)
        s.add(taxCard(d))
        s.addSpacer(24)
    }

    private func taxCard(_ d: AssessmentApplicationDetailData) -> UIView {
        func amount(_ v: String?) -> Double { AssessmentApplicationDetailData.asNumber(v) ?? 0 }
        let parts = [d.currentTax, d.arrear, d.interest, d.waterTax, d.waterTaxArrear, d.waterTaxInterest, d.sewerageTax,
                     d.sewerageTaxArrear, d.sewerageTaxInterest, d.waterCharge, d.waterChargeArrear, d.waterChargeInterest,
                     d.garbageTax, d.garbageTaxArrear, d.garbageTaxInterest]
        let grand = parts.reduce(0) { $0 + amount($1) }
        let card = CardView(radius: 12, padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12), shadowOpacity: 0, border: .grey200)
        func row(_ label: String, _ value: String?, bold: Bool = false) {
            card.stack.add(UIStackView.h(8, [
                UILabel(label, font: .poppins(13, bold ? .bold : .regular), color: .grey800, lines: 0), FlexSpacer(),
                UILabel(Self.money(value), font: .poppins(13, bold ? .bold : .medium), color: bold ? .appPrimary : .grey900),
            ]).padded(UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)))
        }
        func sep() { card.stack.add(divider(color: .grey300, thickness: 0.5).padded(UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0))) }
        row("Property Tax", d.currentTax); row("Property Tax Arrear", d.arrear); row("Property Tax Interest", d.interest)
        row("Modified Property Tax", d.modifiedCurrentTax); sep()
        row("Water Tax", d.waterTax); row("Water Tax Arrear", d.waterTaxArrear); row("Water Tax Interest", d.waterTaxInterest); sep()
        row("Sewerage Tax", d.sewerageTax); row("Sewerage Tax Arrear", d.sewerageTaxArrear)
        row("Sewerage Tax Interest", d.sewerageTaxInterest); sep()
        row("Water Charge", d.waterCharge); row("Water Charge Arrear", d.waterChargeArrear)
        row("Water Charge Interest", d.waterChargeInterest); sep()
        row("Garbage Tax", d.garbageTax); row("Garbage Tax Arrear", d.garbageTaxArrear)
        row("Garbage Tax Interest", d.garbageTaxInterest); sep()
        row("Grand Total", String(format: "%.2f", grand), bold: true)
        return card
    }
}
