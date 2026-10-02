import PDFKit
import UIKit

/// Port of lib/utils/water_connection_ui.dart.
enum WaterConnectionUI {
    static let textColor = UIColor.appTextDark
    static let background = UIColor.appFieldFill

    static func statusColor(_ status: String) -> UIColor {
        switch status.uppercased() {
        case "SUBMITTED": return UIColor(argb: 0xFF2563EB)
        case "APPROVED", "COMPLETED", "CONNECTED": return UIColor(argb: 0xFF1E9E5A)
        case "REJECTED", "CANCELLED": return UIColor(argb: 0xFFD92D20)
        case "PENDING", "IN_PROGRESS", "UNDER_REVIEW": return .appPrimary
        default: return UIColor(argb: 0xFF667085)
        }
    }

    static func statusIcon(_ status: String) -> String {
        switch status.uppercased() {
        case "SUBMITTED": return "checkmark.seal"
        case "APPROVED", "COMPLETED", "CONNECTED": return "checkmark.circle.fill"
        case "REJECTED", "CANCELLED": return "xmark.circle.fill"
        case "PENDING", "IN_PROGRESS", "UNDER_REVIEW": return "hourglass.bottomhalf.filled"
        default: return "info.circle"
        }
    }

    static func statusLabel(_ status: String) -> String { MutationUI.statusLabel(status) }

    static func statusChip(_ status: String, compact: Bool = true) -> UIView {
        let color = statusColor(status)
        let row = UIStackView.h(5, [
            UIImageView(symbol: statusIcon(status), size: compact ? 13 : 15, color: color),
            UILabel(statusLabel(status), font: .poppins(compact ? 11 : 12.5, .semibold), color: color),
        ]).padded(UIEdgeInsets(top: compact ? 5 : 7, left: compact ? 10 : 12, bottom: compact ? 5 : 7, right: compact ? 10 : 12))
        row.backgroundColor = color.withAlphaComponent(0.12)
        row.layer.cornerRadius = 14
        row.setContentHuggingPriority(.required, for: .horizontal)
        row.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    private static func parse(_ raw: String) -> Date? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.first?.isNumber == true else { return nil }
        return DateParsing.iso8601(t)
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.string(from: date)
    }

    /// `2026-07-30 18:38:13` → `30 Jul 2026, 06:38 PM`; unparseable values are returned unchanged.
    static func formatDateTime(_ raw: String) -> String {
        guard let d = parse(raw) else { let t = raw.trimmingCharacters(in: .whitespaces); return t.isEmpty ? "-" : t }
        return format(d, "dd MMM yyyy, hh:mm a")
    }

    static func formatDate(_ raw: String) -> String {
        guard let d = parse(raw) else { let t = raw.trimmingCharacters(in: .whitespaces); return t.isEmpty ? "-" : t }
        return format(d, "dd MMM yyyy")
    }

    static func prettify(_ value: String) -> String { MutationUI.prettify(value) }

    /// White card with a soft shadow used by the list/details screens.
    static func card() -> CardView {
        CardView(radius: 16, padding: .zero, shadowOpacity: 0.05, shadowBlur: 12, shadowY: 4)
    }

    static func sectionHeader(_ icon: String, _ title: String) -> UIView {
        UIStackView.h(10, [iconTile(icon, background: AssessmentUI.softPrimary, size: 31, iconSize: 17, radius: 9),
                           UILabel(title, font: .poppins(14.5, .bold), color: textColor, lines: 0)])
            .padded(UIEdgeInsets(top: 14, left: 16, bottom: 12, right: 16))
    }
}

// MARK: - List

/// Port of lib/water_connection_list_screen.dart.
final class WaterConnectionListViewController: BaseViewController {

    override var screenBackground: UIColor { WaterConnectionUI.background }

    private var isLoading = true
    private var errorMessage: String?
    private var items: [WaterConnectionListItem] = []
    private let refresh = UIRefreshControl()
    private let countLabel = UILabel(nil, font: .poppins(12.5), color: .grey600)
    private let listStack = UIStackView.v(14, [])

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Water & Sewerage", titleColor: WaterConnectionUI.textColor, backColor: .appPrimary,
                     titleSize: 17, titleWeight: .semibold)
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16))
        scrollView.alwaysBounceVertical = true
        refresh.tintColor = .appPrimary
        refresh.addAction(UIAction { [weak self] _ in Task { await self?.fetchList() } }, for: .valueChanged)
        scrollView.refreshControl = refresh

        contentStack.add(newConnectionCard())
        contentStack.addSpacer(24)
        contentStack.add(UIStackView.h(8, [UILabel("My Applications", font: .poppins(16, .bold), color: WaterConnectionUI.textColor),
                                           FlexSpacer(), countLabel]))
        contentStack.addSpacer(12)
        contentStack.add(listStack)
        Task { await fetchList() }
    }

    private func newConnectionCard() -> UIView {
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
        apply.onEvent { [weak self] in self?.handleNewConnection() }
        let header = UIStackView.h(12, [
            iconTile("drop.fill", color: .white, background: UIColor.white.withAlphaComponent(0.2), size: 40, iconSize: 22, radius: 10),
            UIStackView.v(2, [UILabel("New Water & Sewerage Connection", font: .poppins(14.5, .bold), color: .white, lines: 0),
                              UILabel("Apply in 4 simple steps", font: .poppins(12), color: UIColor.white.withAlphaComponent(0.9))]),
        ])
        let inner = UIStackView.v(14, [header, apply])
        gradient.addSubview(inner)
        inner.pinToEdges(of: gradient, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return gradient
    }

    private func handleNewConnection() {
        let vc = NewWaterConnectionViewController()
        vc.onSubmitted = { [weak self] in Task { await self?.fetchList() } }
        push(vc)
    }

    private func fetchList() async {
        if !refresh.isRefreshing {
            isLoading = true
            errorMessage = nil
            renderList()
        }
        do {
            let response = try await APIService.shared.getWaterConnectionList()
            if response.success {
                items = response.data
                errorMessage = nil
            } else {
                errorMessage = response.message.isEmpty ? "Failed to fetch water connection applications" : response.message
            }
        } catch {
            errorMessage = APIError.userMessage(error,
                                                fallback: "Unable to fetch water connection applications. Please try again.")
        }
        isLoading = false
        refresh.endRefreshing()
        renderList()
    }

    private func renderList() {
        listStack.arrangedSubviews.forEach { listStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        countLabel.text = (!isLoading && errorMessage == nil && !items.isEmpty) ? "\(items.count) total" : nil
        if isLoading {
            let sp = UIActivityIndicatorView(style: .large)
            sp.color = .appPrimary
            sp.startAnimating()
            listStack.add(centered(sp).padded(UIEdgeInsets(top: 60, left: 0, bottom: 60, right: 0)))
            return
        }
        if let errorMessage {
            listStack.add(AssessmentUI.messageState(icon: "wifi.slash", title: "Something went wrong", subtitle: errorMessage) {
                [weak self] in Task { await self?.fetchList() }
            })
            return
        }
        if items.isEmpty {
            listStack.add(AssessmentUI.messageState(
                icon: "drop", title: "No applications yet",
                subtitle: "Water & sewerage connection applications you submit will appear here so you can track their status.",
                retry: nil))
            return
        }
        for item in items { listStack.add(card(for: item)) }
    }

    private func card(for item: WaterConnectionListItem) -> UIView {
        let card = WaterConnectionUI.card()
        let name = item.applicantName.trimmingCharacters(in: .whitespaces)
        let title = UILabel(name.isEmpty ? "Unknown Applicant" : name, font: .poppins(15, .bold), color: WaterConnectionUI.textColor)
        title.lineBreakMode = .byTruncatingTail
        card.stack.add(UIStackView.h(8, alignment: .top, [
            UIStackView.v(2, [title, UILabel("Ack: \(item.ackNo.isEmpty ? "-" : item.ackNo)", font: .poppins(12), color: .grey600)]),
            WaterConnectionUI.statusChip(item.status),
        ]).padded(UIEdgeInsets(top: 14, left: 16, bottom: 12, right: 16)))
        card.stack.add(divider())

        let body = UIStackView.v(0, [])
        let tags = [("square.grid.2x2", item.connectionCategory), ("clock", item.connectionType),
                    ("drop", item.connectionRequirement), ("ruler", "\(item.pipeSize) mm")]
            .filter { !$0.1.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { tag($0.0, $0.1) }
        body.add(WrapView(spacing: 8, runSpacing: 8, views: tags))
        body.addSpacer(12)
        body.add(detailRow("Property ID", item.propertyId))
        body.add(detailRow("Mobile No.", item.mobileNo))
        body.add(detailRow("Applied On", WaterConnectionUI.formatDateTime(item.createdAt)))
        card.stack.add(body.padded(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)))

        let footer = UIStackView.h(4, [FlexSpacer(), UILabel("View Details", font: .poppins(12.5, .semibold), color: .appPrimary),
                                       UIImageView(symbol: "chevron.forward", size: 12, color: .appPrimary, weight: .semibold)])
            .padded(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
        footer.backgroundColor = UIColor(argb: 0xFFFDF6F0)
        footer.layer.cornerRadius = 16
        footer.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        card.stack.add(footer)
        card.onTap { [weak self] in
            self?.push(WaterConnectionDetailsViewController(id: item.id, ackNo: item.ackNo, applicantName: item.applicantName))
        }
        return card
    }

    private func tag(_ icon: String, _ value: String) -> UIView {
        let v = UIStackView.h(4, [UIImageView(symbol: icon, size: 13, color: .grey700),
                                  UILabel(value.trimmingCharacters(in: .whitespaces), font: .poppins(11.5, .medium), color: .grey800)])
            .padded(UIEdgeInsets(top: 5, left: 9, bottom: 5, right: 9))
        v.backgroundColor = UIColor(argb: 0xFFF3F4F6)
        v.layer.cornerRadius = 8
        return v
    }

    private func detailRow(_ label: String, _ value: String) -> UIView {
        let l = UILabel(label, font: .poppins(12), color: .grey600)
        l.setSize(width: 92)
        let t = value.trimmingCharacters(in: .whitespaces)
        let v = UILabel(t.isEmpty ? "-" : t, font: .poppins(12.5, .semibold), color: WaterConnectionUI.textColor, lines: 0,
                        alignment: .right)
        return UIStackView.h(0, alignment: .top, [l, v]).padded(UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0))
    }
}

/// Minimal Flutter `Wrap`: lays out intrinsic-size children in rows.
final class WrapView: UIView {
    private let spacing: CGFloat
    private let runSpacing: CGFloat
    private let views: [UIView]
    private var height: NSLayoutConstraint!

    init(spacing: CGFloat, runSpacing: CGFloat, views: [UIView]) {
        self.spacing = spacing
        self.runSpacing = runSpacing
        self.views = views
        super.init(frame: .zero)
        views.forEach { addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = true }
        height = heightAnchor.constraint(equalToConstant: 0)
        height.priority = .defaultHigh
        height.isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in views {
            let size = v.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            let w = min(size.width, bounds.width)
            if x > 0, x + w > bounds.width {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            v.frame = CGRect(x: x, y: y, width: w, height: size.height)
            x += w + spacing
            rowHeight = max(rowHeight, size.height)
        }
        let total = views.isEmpty ? 0 : y + rowHeight
        if height.constant != total {
            height.constant = total
            invalidateIntrinsicContentSize()
        }
    }
}

// MARK: - New connection

/// Port of lib/new_water_connection_screen.dart — four-part application form.
final class NewWaterConnectionViewController: BaseViewController {

    override var screenBackground: UIColor { WaterConnectionUI.background }

    /// `Navigator.pop(context, ackNo ?? true)` → the list refreshes.
    var onSubmitted: (() -> Void)?

    private static let totalSteps = 4
    private static let maxDocSize = 200 * 1024
    private static let disabledFill = UIColor(argb: 0xFFF3F4F6)
    private static let relationOptions = ["S/o", "D/o", "W/o"]
    private static let connectionTypeOptions = ["Permanent", "Temporary"]
    private static let connectionRequiredOptions = ["Water", "Sewerage", "Both"]
    private static let connectionCategoryOptions = ["Domestic", "Commercial"]
    private static let idProofOptions = ["Aadhaar Card", "PAN", "Voter ID"]
    /// Labels shown to the applicant → values the submit API accepts for `propertyProofType`.
    private static let propertyDocOptions: [(label: String, value: String)] = [
        ("Registry / Sale Deed (First & Last Page)", "SALE_DEED"),
        ("Lease Agreement (First & Last Page)", "Lease Agreement"),
    ]

    private var step = 0
    private var relation = "S/o"

    private var selectedZone: ZoneData?, selectedWard: WardData?, selectedMohalla: MohallaData?
    private var sameAsAbove = false
    private var selectedZone2: ZoneData?, selectedWard2: WardData?, selectedMohalla2: MohallaData?

    private var connectionType: String?, connectionRequired: String?, connectionCategory: String?
    private var pipeSize: String?
    private var pipeSizeError: String?
    private var pipeSizeTask: Task<Void, Never>?
    private var pipeSizeRequestId = 0

    private var idProofType: String?
    private var idProofFile: PickedFile?
    private var propertyDocType: String?
    private var propertyDocFile: PickedFile?
    private var selfPhotoFile: PickedFile?

    private var ulbId: String?
    private var zoneList: [ZoneData] = []
    private var wardList: [WardData] = [], mohallaList: [MohallaData] = []
    private var wardList2: [WardData] = [], mohallaList2: [MohallaData] = []
    private var isLoadingUlbId = true
    private var isLoadingZones = false
    private var isLoadingWards = false, isLoadingMohallas = false
    private var isLoadingWards2 = false, isLoadingMohallas2 = false
    private var isLoadingPipeSize = false
    private var isSubmitting = false

    private let progressHolder = UIView()
    private let backButton = OutlineButton("Back", color: .appPrimary, borderColor: .appPrimary, height: 48, fontSize: 15)
    private let continueButton = AssessmentUI.actionButton("Continue")
    private let pipeSizeArea = UIStackView.v(0, [])

    private lazy var ownerName = field("House Owner Name", required: true)
    private lazy var fatherHusbandName = field("Father/Husband Name", required: true)
    private lazy var mobileNo: ENSTextField = {
        let f = field("Mobile Number", keyboard: .phonePad, max: 10, digits: true)
        f.validator = { v in
            let t = v.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return "Please enter Mobile Number" }
            return t.range(of: #"^[6-9]\d{9}$"#, options: .regularExpression) == nil ? "Please enter a valid 10-digit mobile number" : nil
        }
        return f
    }()
    private lazy var plotHouseNo = field("Plot/House No.", required: true)
    private lazy var street = field("Street/Road", required: true)
    private lazy var landmark = field("Landmark", required: true, hint: "ex: near school, near PCO")
    private lazy var plotHouseNo2 = field("Plot/House No.", required: true)
    private lazy var street2 = field("Street/Road", required: true)
    private lazy var landmark2 = field("Landmark", required: true, hint: "ex: near school, near PCO")
    private lazy var propertyId = field("Property ID", required: true, hint: "Property ID alloted to property by ULB")
    private lazy var plotArea: ENSTextField = {
        let f = field("Plot Area (in sq. m)", keyboard: .decimalPad, decimals: true)
        f.validator = { v in
            let t = v.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return "Please enter Plot Area" }
            guard let p = Double(t), p > 0 else { return "Please enter a valid plot area" }
            return nil
        }
        f.onChange = { [weak self] _ in self?.scheduleFetchPipeSize() }
        return f
    }()

    private func field(_ label: String, required: Bool = false, keyboard: UIKeyboardType = .default, max: Int? = nil,
                       digits: Bool = false, decimals: Bool = false, hint: String? = nil) -> ENSTextField {
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
        c.textColor = WaterConnectionUI.textColor
        let f = ENSTextField(c)
        if let hint { f.hint = hint }
        if required {
            f.validator = { $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Please enter \(label)" : nil }
        }
        return f
    }

    // Effective correspondence address — read through when "Same as above" is ticked.
    private var corrPlotHouseNo: String { sameAsAbove ? plotHouseNo.trimmedText : plotHouseNo2.trimmedText }
    private var corrStreet: String { sameAsAbove ? street.trimmedText : street2.trimmedText }
    private var corrLandmark: String { sameAsAbove ? landmark.trimmedText : landmark2.trimmedText }
    private var corrZone: ZoneData? { sameAsAbove ? selectedZone : selectedZone2 }
    private var corrWard: WardData? { sameAsAbove ? selectedWard : selectedWard2 }
    private var corrMohalla: MohallaData? { sameAsAbove ? selectedMohalla : selectedMohalla2 }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "New Water & Sewerage Connection", titleColor: WaterConnectionUI.textColor, backColor: .appPrimary,
                     titleSize: 15, titleWeight: .semibold)
        view.addSubview(progressHolder)
        progressHolder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressHolder.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressHolder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressHolder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        let buttons = UIStackView.h(12, alignment: .fill, [backButton, continueButton])
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
        render()
        Task { await loadUlbId() }
    }

    deinit { pipeSizeTask?.cancel() }

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

    // MARK: - Lookups

    private func loadUlbId() async {
        ulbId = StorageService.ulbCache
        isLoadingUlbId = false
        if step == 1 { render() }
        guard let ulbId, !ulbId.isEmpty else { return }
        isLoadingZones = true
        if step == 1 { render() }
        if let zones = try? await APIService.shared.getZoneData(ulbId: ulbId) { zoneList = zones }
        isLoadingZones = false
        if step == 1 { render() }
    }

    private func fetchWards(_ zoneId: String, correspondence: Bool) {
        guard let ulbId else { return }
        if correspondence { isLoadingWards2 = true } else { isLoadingWards = true }
        render()
        Task {
            let wards = (try? await APIService.shared.getWardData(ulbId: ulbId, zoneId: zoneId)) ?? []
            if correspondence { wardList2 = wards; isLoadingWards2 = false } else { wardList = wards; isLoadingWards = false }
            if step == 1 { render() }
        }
    }

    private func fetchMohallas(_ zoneId: String, _ wardId: String, correspondence: Bool) {
        guard let ulbId else { return }
        if correspondence { isLoadingMohallas2 = true } else { isLoadingMohallas = true }
        render()
        Task {
            let mohallas = (try? await APIService.shared.getMohallaData(ulbId: ulbId, zoneId: zoneId, wardId: wardId)) ?? []
            if correspondence {
                mohallaList2 = mohallas
                isLoadingMohallas2 = false
            } else {
                mohallaList = mohallas
                isLoadingMohallas = false
            }
            if step == 1 { render() }
        }
    }

    /// Re-runs the pipe size lookup (debounced 600 ms) when the category or plot area changes.
    private func scheduleFetchPipeSize() {
        pipeSizeTask?.cancel()
        pipeSize = nil
        pipeSizeError = nil
        let category = connectionCategory
        let area = plotArea.trimmedText
        guard let category, !area.isEmpty, (Double(area) ?? 0) > 0 else {
            isLoadingPipeSize = false
            renderPipeSize()
            return
        }
        isLoadingPipeSize = true
        renderPipeSize()
        pipeSizeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await self?.fetchPipeSize(category: category, plotArea: area)
        }
    }

    private func fetchPipeSize(category: String, plotArea: String) async {
        pipeSizeRequestId += 1
        let requestId = pipeSizeRequestId
        var size: String?
        var error: String?
        do {
            let response = try await OtpGateService.guardCall(propertyId: propertyId.trimmedText, mobileNo: mobileNo.trimmedText,
                                                              responseCode: { $0.responseCode }) {
                try await APIService.shared.getPipeSize(categoryConnection: category, plotArea: plotArea)
            }
            if response.success, let data = response.data { size = data } else {
                error = response.message.isEmpty ? "Pipe size not available for the entered plot area." : response.message
            }
        } catch {
            error = APIError.userMessage(error)
        }
        guard requestId == pipeSizeRequestId else { return }
        pipeSize = size
        pipeSizeError = error
        isLoadingPipeSize = false
        renderPipeSize()
    }

    // MARK: - Rendering

    private func sectionTitle(_ t: String) -> UIView { UILabel(t, font: .poppins(16, .bold), color: WaterConnectionUI.textColor, lines: 0) }
    private func sectionHint(_ t: String) -> UIView { UILabel(t, font: .poppins(12), color: .grey600, lines: 0) }
    private func fieldLabel(_ t: String) -> UIView { UILabel(t, font: .poppins(14, .semibold), color: WaterConnectionUI.textColor, lines: 0) }

    private func render() {
        progressHolder.subviews.forEach { $0.removeFromSuperview() }
        let bar = AssessmentProgressBar(step: step + 1, total: Self.totalSteps)
        progressHolder.addSubview(bar)
        bar.pinToEdges(of: progressHolder)
        interceptsBack = step > 0 || isSubmitting
        backButton.isHidden = step == 0
        continueButton.setTitle(step == Self.totalSteps - 1 ? "Submit" : "Continue", for: .normal)

        let offset = scrollView.contentOffset
        let s = contentStack
        s.arrangedSubviews.forEach { s.removeArrangedSubview($0); $0.removeFromSuperview() }
        switch step {
        case 0: renderStep1()
        case 1: renderStep2()
        case 2: renderStep3()
        default: renderStep4()
        }
        s.layoutIfNeeded()
        scrollView.contentOffset = offset
    }

    private func goToStep(_ newStep: Int) {
        step = newStep
        render()
        scrollView.setContentOffset(.zero, animated: false)
    }

    private func renderStep1() {
        let s = contentStack
        s.add(sectionTitle("House Basic Details")); s.addSpacer(4)
        s.add(sectionHint("Enter the details of the house owner.")); s.addSpacer(14)
        s.add(ownerName); s.addSpacer(12)
        let relationField = AssessmentUI.selectField("")
        relationField.value = relation
        relationField.setSize(width: 96)
        relationField.onTap = { [weak self] in
            self?.showSelection("Select", Self.relationOptions) { i in
                self?.relation = Self.relationOptions[i]
                relationField.value = Self.relationOptions[i]
            }
        }
        s.add(UIStackView.h(12, alignment: .top, [relationField, fatherHusbandName])); s.addSpacer(12)
        s.add(mobileNo)
    }

    private func renderStep2() {
        let s = contentStack
        s.add(sectionTitle("Address of New Connection")); s.addSpacer(4)
        s.add(sectionHint("Where the new connection has to be installed.")); s.addSpacer(14)
        s.add(zoneField(correspondence: false)); s.addSpacer(16)
        s.add(wardField(correspondence: false)); s.addSpacer(16)
        s.add(mohallaField(correspondence: false)); s.addSpacer(16)
        s.add(plotHouseNo); s.addSpacer(12)
        s.add(street); s.addSpacer(12)
        s.add(landmark); s.addSpacer(28)

        s.add(sectionTitle("Communication/Correspondence Address")); s.addSpacer(4)
        s.add(sectionHint("Where letters and notices should be delivered."))
        let check = UIStackView.h(12, [
            UIImageView(symbol: sameAsAbove ? "checkmark.square.fill" : "square", size: 20,
                        color: sameAsAbove ? .appPrimary : .grey600),
            UILabel("Same as above address", font: .poppins(14), color: WaterConnectionUI.textColor), FlexSpacer(),
        ]).padded(UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0))
        check.onTap { [weak self] in
            guard let self else { return }
            self.view.endEditing(true)
            self.sameAsAbove.toggle()
            self.render()
        }
        s.add(check); s.addSpacer(4)
        if sameAsAbove {
            for (l, v) in [("Zone", corrZone?.zoneName), ("Ward", corrWard?.wardName), ("Mohalla", corrMohalla?.mohallaName),
                           ("Plot/House No.", corrPlotHouseNo), ("Street/Road", corrStreet), ("Landmark", corrLandmark)] {
                s.add(readOnlyField(l, v)); s.addSpacer(12)
            }
        } else {
            s.add(zoneField(correspondence: true)); s.addSpacer(16)
            s.add(wardField(correspondence: true)); s.addSpacer(16)
            s.add(mohallaField(correspondence: true)); s.addSpacer(16)
            s.add(plotHouseNo2); s.addSpacer(12)
            s.add(street2); s.addSpacer(12)
            s.add(landmark2)
        }
    }

    private func zoneField(correspondence: Bool) -> UIView {
        let selected = correspondence ? selectedZone2 : selectedZone
        let noUlb = ulbId?.isEmpty ?? true
        let hint = isLoadingUlbId ? "Loading..." : noUlb ? "ULB not found. Please open Dashboard first."
            : isLoadingZones ? "Loading Zones..." : (selected?.zoneName ?? "Select Zone")
        let enabled = !(isLoadingUlbId || noUlb || isLoadingZones)
        return selectableField(label: "Zone", hint: hint, onTap: enabled ? { [weak self] in
            guard let self else { return }
            self.showSelection("Select Zone", self.zoneList.map(\.zoneName)) { i in
                let zone = self.zoneList[i]
                if correspondence {
                    self.selectedZone2 = zone; self.selectedWard2 = nil; self.selectedMohalla2 = nil
                    self.wardList2 = []; self.mohallaList2 = []
                } else {
                    self.selectedZone = zone; self.selectedWard = nil; self.selectedMohalla = nil
                    self.wardList = []; self.mohallaList = []
                }
                self.fetchWards(zone.zoneId, correspondence: correspondence)
            }
        } : nil)
    }

    private func wardField(correspondence: Bool) -> UIView {
        let zone = correspondence ? selectedZone2 : selectedZone
        let selected = correspondence ? selectedWard2 : selectedWard
        let loading = correspondence ? isLoadingWards2 : isLoadingWards
        let wards = correspondence ? wardList2 : wardList
        return selectableField(label: "Ward", hint: loading ? "Loading Wards..." : (selected?.wardName ?? "Select Ward"),
                               onTap: (zone == nil || loading) ? nil : { [weak self] in
            guard let self, let zone else { return }
            self.showSelection("Select Ward", wards.map(\.wardName)) { i in
                let ward = wards[i]
                if correspondence {
                    self.selectedWard2 = ward; self.selectedMohalla2 = nil; self.mohallaList2 = []
                } else {
                    self.selectedWard = ward; self.selectedMohalla = nil; self.mohallaList = []
                }
                self.fetchMohallas(zone.zoneId, ward.wardId, correspondence: correspondence)
            }
        })
    }

    private func mohallaField(correspondence: Bool) -> UIView {
        let ward = correspondence ? selectedWard2 : selectedWard
        let selected = correspondence ? selectedMohalla2 : selectedMohalla
        let loading = correspondence ? isLoadingMohallas2 : isLoadingMohallas
        let mohallas = correspondence ? mohallaList2 : mohallaList
        return selectableField(label: "Mohalla", hint: loading ? "Loading Mohallas..." : (selected?.mohallaName ?? "Select Mohalla"),
                               onTap: (ward == nil || loading) ? nil : { [weak self] in
            guard let self else { return }
            self.showSelection("Select Mohalla", mohallas.map(\.mohallaName)) { i in
                if correspondence { self.selectedMohalla2 = mohallas[i] } else { self.selectedMohalla = mohallas[i] }
                self.render()
            }
        })
    }

    private func renderStep3() {
        let s = contentStack
        s.add(sectionTitle("Connection Details")); s.addSpacer(4)
        s.add(sectionHint("Tell us what kind of connection you need.")); s.addSpacer(14)
        s.add(selectableField(label: "Connection Type", hint: connectionType ?? "Select Connection Type") { [weak self] in
            self?.showSelection("Select Connection Type", Self.connectionTypeOptions) { i in
                self?.connectionType = Self.connectionTypeOptions[i]
                self?.render()
            }
        })
        s.addSpacer(16)
        s.add(selectableField(label: "Connection Required", hint: connectionRequired ?? "Select Connection Required") { [weak self] in
            self?.showSelection("Select Connection Required", Self.connectionRequiredOptions) { i in
                self?.connectionRequired = Self.connectionRequiredOptions[i]
                self?.render()
            }
        })
        s.addSpacer(16)
        s.add(propertyId); s.addSpacer(12)
        s.add(plotArea); s.addSpacer(12)
        s.add(selectableField(label: "Connection Category", hint: connectionCategory ?? "Select Connection Category") { [weak self] in
            self?.showSelection("Select Connection Category", Self.connectionCategoryOptions) { i in
                self?.connectionCategory = Self.connectionCategoryOptions[i]
                self?.render()
                self?.scheduleFetchPipeSize()
            }
        })
        s.addSpacer(16)
        s.add(pipeSizeArea)
        renderPipeSize()
    }

    /// Pipe size comes from the Fetch Pipe Size API, so it is displayed rather than picked.
    private func renderPipeSize() {
        pipeSizeArea.arrangedSubviews.forEach { pipeSizeArea.removeArrangedSubview($0); $0.removeFromSuperview() }
        let value: String
        if isLoadingPipeSize {
            value = "Fetching Pipe Size..."
        } else if let pipeSize {
            value = "\(pipeSize) mm"
        } else if connectionCategory == nil || plotArea.trimmedText.isEmpty {
            value = "Enter Plot Area & select Connection Category"
        } else {
            value = "Not available"
        }
        pipeSizeArea.add(readOnlyField("Pipe Size (in mm)", value))
        if let pipeSizeError {
            pipeSizeArea.addSpacer(6)
            pipeSizeArea.add(UILabel(pipeSizeError, font: .poppins(12), color: .mRed, lines: 0))
        }
    }

    private func renderStep4() {
        let s = contentStack
        s.add(sectionTitle("Upload Documents")); s.addSpacer(4)
        s.add(sectionHint("Documents must be PDF and the photo JPG, each up to 200 KB.")); s.addSpacer(18)
        s.add(fieldLabel("ID Proof Type (select any one)"))
        s.add(radioGroup(Self.idProofOptions, selected: idProofType) { [weak self] value in self?.idProofType = value })
        s.addSpacer(10)
        s.add(fileUploadRow(idProofFile) { [weak self] in self?.pickDocument(["pdf"]) { self?.idProofFile = $0 } })
        s.addSpacer(24)
        s.add(fieldLabel("Document Related to Property (select any one)"))
        s.add(radioGroup(Self.propertyDocOptions.map(\.label), selected: propertyDocType) { [weak self] value in self?.propertyDocType = value })
        s.addSpacer(10)
        s.add(fileUploadRow(propertyDocFile) { [weak self] in self?.pickDocument(["pdf"]) { self?.propertyDocFile = $0 } })
        s.addSpacer(24)
        s.add(fieldLabel("Self Photo (scanned passport size)")); s.addSpacer(4)
        s.add(fileUploadRow(selfPhotoFile, hint: "No file chosen (JPG, max 200 KB)") { [weak self] in
            self?.pickDocument(["jpg", "jpeg"]) { self?.selfPhotoFile = $0 }
        })
    }

    private func selectableField(label: String?, hint: String, onTap: (() -> Void)?) -> UIView {
        let isPlaceholder = hint.contains("Select") || hint.contains("Loading") || hint.contains("not found")
        let text = UILabel(hint, font: .poppins(14), color: isPlaceholder ? .grey600 : WaterConnectionUI.textColor)
        text.lineBreakMode = .byTruncatingTail
        let box = UIStackView.h(8, [text, UIImageView(symbol: "chevron.down", size: 13, color: .grey600, weight: .semibold)])
            .padded(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        box.backgroundColor = onTap == nil ? Self.disabledFill : .white
        box.layer.cornerRadius = 12
        box.addBorder(color: .grey300)
        box.onTap { [weak self] in
            self?.view.endEditing(true)
            onTap?()
        }
        guard let label else { return box }
        return UIStackView.v(6, [UILabel(label, font: .poppins(13), color: .grey700), box])
    }

    private func readOnlyField(_ label: String, _ value: String?) -> UIView {
        let has = !(value ?? "").isEmpty
        let box = UILabel(has ? value : "Not filled yet", font: .poppins(14), color: has ? WaterConnectionUI.textColor : .grey600,
                          lines: 0).padded(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        box.backgroundColor = Self.disabledFill
        box.layer.cornerRadius = 12
        box.addBorder(color: .grey300)
        return UIStackView.v(6, [UILabel(label, font: .poppins(13), color: .grey700), box])
    }

    private func radioGroup(_ options: [String], selected: String?, onChange: @escaping (String) -> Void) -> UIView {
        let stack = UIStackView.v(0, [])
        for option in options {
            let row = UIStackView.h(10, [
                UIImageView(symbol: selected == option ? "largecircle.fill.circle" : "circle", size: 20,
                            color: selected == option ? .appPrimary : .grey600),
                UILabel(option, font: .poppins(13), color: WaterConnectionUI.textColor, lines: 0), FlexSpacer(),
            ]).padded(UIEdgeInsets(top: 8, left: 2, bottom: 8, right: 0))
            row.onTap { [weak self] in
                onChange(option)
                self?.render()
            }
            stack.add(row)
        }
        return stack
    }

    private func fileUploadRow(_ file: PickedFile?, hint: String = "No file chosen (PDF, max 200 KB)",
                               onPick: @escaping () -> Void) -> UIView {
        let choose = OutlineButton(file == nil ? "Choose File" : "Replace", color: .appPrimary, borderColor: .appPrimary,
                                   height: 36, radius: 8, fontSize: 13)
        choose.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        choose.setContentHuggingPriority(.required, for: .horizontal)
        choose.setContentCompressionResistancePriority(.required, for: .horizontal)
        choose.onEvent(.touchUpInside, onPick)
        let name = UILabel(file?.filename ?? hint, font: .poppins(13), color: file == nil ? .grey600 : WaterConnectionUI.textColor)
        name.lineBreakMode = .byTruncatingTail
        var views: [UIView] = [choose, name]
        if file != nil { views.append(UIImageView(symbol: "checkmark.circle.fill", size: 20, color: .mGreen)) }
        let row = UIStackView.h(12, views).padded(12)
        row.backgroundColor = .white
        row.layer.cornerRadius = 12
        row.addBorder(color: .grey300)
        return row
    }

    private func showSelection(_ title: String, _ items: [String], _ onSelect: @escaping (Int) -> Void) {
        view.endEditing(true)
        OptionPickerSheet.present(on: self, title: title, options: items, selected: nil, searchable: true) { [weak self] i in
            onSelect(i)
            self?.render()
        }
    }

    private func pickDocument(_ extensions: [String], onPicked: @escaping (PickedFile) -> Void) {
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
            onPicked(file)
            render()
        }
    }

    // MARK: - Navigation / validation

    private func handleContinue() {
        view.endEditing(true)
        guard validateCurrentStep() else { return }
        if step < Self.totalSteps - 1 {
            goToStep(step + 1)
            return
        }
        submit()
    }

    private func validateCurrentStep() -> Bool {
        switch step {
        case 0:
            return ![ownerName, fatherHusbandName, mobileNo].map { $0.validate() }.contains(false)
        case 1:
            var fields = [plotHouseNo, street, landmark]
            if !sameAsAbove { fields += [plotHouseNo2, street2, landmark2] }
            guard !fields.map({ $0.validate() }).contains(false) else { return false }
            if selectedZone == nil || selectedWard == nil || selectedMohalla == nil {
                snack("Please select Zone, Ward and Mohalla")
                return false
            }
            if !sameAsAbove, selectedZone2 == nil || selectedWard2 == nil || selectedMohalla2 == nil {
                snack("Please select Zone, Ward and Mohalla for the correspondence address")
                return false
            }
            return true
        case 2:
            guard ![propertyId, plotArea].map({ $0.validate() }).contains(false) else { return false }
            if connectionType == nil { snack("Please select Connection Type"); return false }
            if connectionRequired == nil { snack("Please select Connection Required"); return false }
            if connectionCategory == nil { snack("Please select Connection Category"); return false }
            if isLoadingPipeSize { snack("Please wait, fetching the applicable pipe size..."); return false }
            if pipeSize == nil {
                snack(pipeSizeError ?? "Pipe size could not be determined. Please check the Plot Area and Connection Category.")
                return false
            }
            return true
        default:
            if idProofType == nil { snack("Please select an ID Proof Type"); return false }
            if idProofFile == nil { snack("Please upload the ID Proof document"); return false }
            if propertyDocType == nil { snack("Please select a Document Related to Property"); return false }
            if propertyDocFile == nil { snack("Please upload the Document Related to Property"); return false }
            if selfPhotoFile == nil { snack("Please upload your Self Photo"); return false }
            return true
        }
    }

    private func submit() {
        guard let zone = selectedZone, let ward = selectedWard, let mohalla = selectedMohalla,
              let cZone = corrZone, let cWard = corrWard, let cMohalla = corrMohalla,
              let connectionType, let connectionRequired, let connectionCategory, let pipeSize, let idProofType,
              let proofType = Self.propertyDocOptions.first(where: { $0.label == propertyDocType })?.value,
              let selfPhoto = selfPhotoFile, let idProof = idProofFile, let propertyDoc = propertyDocFile else { return }
        isSubmitting = true
        interceptsBack = true
        continueButton.isLoading = true
        backButton.isEnabled = false
        let fields: [(String, String)] = [
            ("applicantName", ownerName.trimmedText), ("relationType", relation),
            ("fatherHusbandName", fatherHusbandName.trimmedText), ("mobileNo", mobileNo.trimmedText),
            ("newZoneId", zone.zoneId), ("newWardId", ward.wardId), ("newMohallaId", mohalla.mohallaId),
            ("newPlotNo", plotHouseNo.trimmedText), ("newStreet", street.trimmedText), ("newLandmark", landmark.trimmedText),
            ("corrZoneId", cZone.zoneId), ("corrWardId", cWard.wardId), ("corrMohallaId", cMohalla.mohallaId),
            ("corrPlotNo", corrPlotHouseNo), ("corrStreet", corrStreet), ("corrLandmark", corrLandmark),
            ("connectionType", connectionType), ("connectionRequirement", connectionRequired),
            ("propertyId", propertyId.trimmedText), ("plotArea", plotArea.trimmedText),
            ("connectionCategory", connectionCategory), ("pipeSize", pipeSize),
            ("idProofType", idProofType), ("propertyProofType", proofType),
        ]
        let pid = propertyId.trimmedText, mobile = mobileNo.trimmedText
        Task {
            var ackNo: String?
            var errorMessage: String?
            do {
                let response = try await OtpGateService.guardCall(propertyId: pid, mobileNo: mobile,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.submitConnection(fields: fields, selfPhoto: selfPhoto.upload,
                                                                 idProofDocument: idProof.upload,
                                                                 propertyProofDocument: propertyDoc.upload)
                }
                if response.success { ackNo = response.ackNo } else {
                    errorMessage = response.message.isEmpty ? "Failed to submit the application. Please try again." : response.message
                }
            } catch {
                errorMessage = APIError.userMessage(error)
            }
            isSubmitting = false
            interceptsBack = step > 0
            continueButton.isLoading = false
            backButton.isEnabled = true
            if let errorMessage { snack(errorMessage); return }
            var message = "Your new water & sewerage connection application has been submitted."
            if let ackNo { message += "\n\nAcknowledgement No: \(ackNo)" }
            AppDialog.show(on: self, icon: "checkmark.circle.fill", iconColor: .mGreen, iconSize: 28, title: "Submitted",
                           message: message, actions: [.init(title: "OK") { [weak self] in
                               self?.onSubmitted?()
                               self?.navigationController?.popViewController(animated: true)
                           }], dismissible: false)
        }
    }
}

// MARK: - Details

/// Port of lib/water_connection_details_screen.dart.
final class WaterConnectionDetailsViewController: BaseViewController {

    private enum DocumentKind { case selfPhoto, idProof, propertyProof }

    override var screenBackground: UIColor { WaterConnectionUI.background }

    private let id: String
    private let ackNo: String
    private let applicantName: String
    private var details: WaterConnectionDetails?
    private var openingDocument: DocumentKind?
    private let refresh = UIRefreshControl()

    init(id: String, ackNo: String, applicantName: String = "") {
        self.id = id
        self.ackNo = ackNo
        self.applicantName = applicantName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Application Details", titleColor: WaterConnectionUI.textColor, backColor: .appPrimary,
                     titleSize: 17, titleWeight: .semibold)
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 28, right: 16))
        scrollView.alwaysBounceVertical = true
        refresh.tintColor = .appPrimary
        refresh.addAction(UIAction { [weak self] _ in Task { await self?.fetchDetails(silent: true) } }, for: .valueChanged)
        scrollView.refreshControl = refresh
        Task { await fetchDetails(silent: false) }
    }

    private func fetchDetails(silent: Bool) async {
        if !silent { setLoading(true) }
        var errorMessage: String?
        do {
            let response = try await APIService.shared.getWaterConnectionDetails(id: id, ackNo: ackNo)
            if response.success, let data = response.data { details = data } else {
                errorMessage = response.message.isEmpty ? "Failed to fetch application details" : response.message
            }
        } catch {
            errorMessage = APIError.userMessage(error, fallback: "Unable to fetch application details. Please try again.")
        }
        setLoading(false)
        refresh.endRefreshing()
        if let errorMessage {
            // A silent refresh (document link renewal) keeps the details already on screen.
            if !silent || details == nil { details = nil; renderError(errorMessage) }
            return
        }
        render()
    }

    private func clear() {
        contentStack.arrangedSubviews.forEach { contentStack.removeArrangedSubview($0); $0.removeFromSuperview() }
    }

    private func renderError(_ message: String) {
        clear()
        contentStack.add(AssessmentUI.messageState(icon: "wifi.slash", title: "Something went wrong", subtitle: message) {
            [weak self] in Task { await self?.fetchDetails(silent: false) }
        }.padded(UIEdgeInsets(top: 20, left: 8, bottom: 0, right: 8)))
    }

    private func document(_ kind: DocumentKind) -> WaterConnectionDocument? {
        guard let details else { return nil }
        switch kind {
        case .selfPhoto: return details.selfPhoto
        case .idProof: return details.idProofDocument
        case .propertyProof: return details.propertyProofDocument
        }
    }

    /// Signed links live only a few minutes — an expired one is refreshed by re-fetching
    /// the details, and the viewer can ask for another if its download still fails.
    private func openDocument(_ kind: DocumentKind, title: String, subtitle: String) {
        guard openingDocument == nil else { return }
        openingDocument = kind
        render()
        Task {
            var doc = document(kind)
            if let d = doc, d.isExpired {
                await fetchDetails(silent: true)
                doc = document(kind)
            }
            openingDocument = nil
            render()
            guard let doc else { snack("This document is not available."); return }
            push(WaterDocumentViewerController(url: doc.url, title: title, subtitle: subtitle) { [weak self] in
                guard let self else { return nil }
                await self.fetchDetails(silent: true)
                return self.document(kind)?.url
            })
        }
    }

    private func render() {
        guard let d = details else { return }
        clear()
        let s = contentStack
        s.add(headerCard(d)); s.addSpacer(16)
        s.add(section("person", "Applicant Details", [
            ("Applicant Name", d.applicantName), ("Relation", d.relationType), ("Father/Husband Name", d.fatherHusbandName),
            ("Mobile No.", d.mobileNo), ("Property ID", d.propertyId),
        ])); s.addSpacer(16)
        s.add(section("drop", "Connection Details", [
            ("Connection Type", d.connectionType), ("Connection Required", d.connectionRequirement),
            ("Connection Category", d.connectionCategory), ("Plot Area", formatPlotArea(d.plotArea)),
            ("Pipe Size", d.pipeSize.trimmingCharacters(in: .whitespaces).isEmpty ? "-" : "\(d.pipeSize.trimmingCharacters(in: .whitespaces)) mm"),
        ])); s.addSpacer(16)
        s.add(section("house", "Address of New Connection", [
            ("Plot/House No.", d.newPlotNo), ("Street/Road", d.newStreet), ("Landmark", d.newLandmark),
            ("Zone ID", d.newZoneId), ("Ward ID", d.newWardId), ("Mohalla ID", d.newMohallaId),
        ])); s.addSpacer(16)
        s.add(section("envelope", "Correspondence Address", [
            ("Plot/House No.", d.corrPlotNo), ("Street/Road", d.corrStreet), ("Landmark", d.corrLandmark),
            ("Zone ID", d.corrZoneId), ("Ward ID", d.corrWardId), ("Mohalla ID", d.corrMohallaId),
        ])); s.addSpacer(16)
        s.add(documentsCard(d))
    }

    private func formatPlotArea(_ plotArea: String) -> String {
        guard let v = Double(plotArea) else { return plotArea }
        let text = v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.2f", v)
        return "\(text) sq. m"
    }

    private func headerCard(_ d: WaterConnectionDetails) -> UIView {
        let card = CardView(radius: 16, shadowOpacity: 0.05, shadowBlur: 12, shadowY: 4)
        let ack = UILabel(d.ackNo.isEmpty ? "-" : d.ackNo, font: .poppins(17, .bold), color: WaterConnectionUI.textColor)
        ack.lineBreakMode = .byTruncatingTail
        let copy = UIImageView(symbol: "doc.on.doc", size: 16, color: .appPrimary)
        copy.onTap { [weak self] in
            guard let self else { return }
            UIPasteboard.general.string = self.ackNo
            self.snack("Acknowledgement number copied")
        }
        card.stack.add(UIStackView.h(8, alignment: .top, [
            UIStackView.v(3, [UILabel("Acknowledgement No.", font: .poppins(12), color: .grey600),
                              UIStackView.h(6, [ack, copy, FlexSpacer()])]),
            WaterConnectionUI.statusChip(d.status, compact: false),
        ]))
        card.stack.addSpacer(14)
        let sep = UIView()
        sep.backgroundColor = .grey200
        sep.setSize(width: 1, height: 34)
        let applied = stamp("calendar.badge.checkmark", "Applied On", WaterConnectionUI.formatDateTime(d.createdAt))
        let updated = stamp("arrow.clockwise", "Last Updated", WaterConnectionUI.formatDateTime(d.updatedAt))
        let row = UIStackView.h(12, alignment: .center, [applied, sep, updated])
        applied.widthAnchor.constraint(equalTo: updated.widthAnchor).isActive = true
        card.stack.add(row)
        let message = d.responseMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !message.isEmpty {
            card.stack.addSpacer(14)
            let color = WaterConnectionUI.statusColor(d.status)
            let box = UIStackView.h(8, alignment: .top, [UIImageView(symbol: "bubble.left", size: 15, color: color),
                                                         UILabel(message, font: .poppins(12.5), color: WaterConnectionUI.textColor, lines: 0)])
                .padded(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
            box.backgroundColor = color.withAlphaComponent(0.08)
            box.layer.cornerRadius = 10
            card.stack.add(box)
        }
        return card
    }

    private func stamp(_ icon: String, _ label: String, _ value: String) -> UIView {
        UIStackView.v(3, alignment: .leading, [
            UIStackView.h(5, [UIImageView(symbol: icon, size: 14, color: .grey600), UILabel(label, font: .poppins(11.5), color: .grey600)]),
            UILabel(value, font: .poppins(12.5, .semibold), color: WaterConnectionUI.textColor, lines: 0),
        ])
    }

    private func section(_ icon: String, _ title: String, _ rows: [(String, String)]) -> UIView {
        let card = WaterConnectionUI.card()
        card.stack.add(WaterConnectionUI.sectionHeader(icon, title))
        card.stack.add(divider())
        let body = UIStackView.v(0, [])
        for (label, value) in rows {
            let l = UILabel(label, font: .poppins(12.5), color: .grey600, lines: 0)
            l.setSize(width: 132)
            let t = value.trimmingCharacters(in: .whitespaces)
            let v = UILabel(t.isEmpty ? "-" : t, font: .poppins(13, .semibold), color: WaterConnectionUI.textColor, lines: 0,
                            alignment: .right)
            body.add(UIStackView.h(0, alignment: .top, [l, v]).padded(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)))
        }
        card.stack.add(body.padded(UIEdgeInsets(top: 8, left: 16, bottom: 12, right: 16)))
        return card
    }

    private func documentsCard(_ d: WaterConnectionDetails) -> UIView {
        let card = WaterConnectionUI.card()
        card.stack.add(WaterConnectionUI.sectionHeader("folder", "Uploaded Documents"))
        card.stack.add(divider())
        let idSub = WaterConnectionUI.prettify(d.idProofType)
        let propSub = WaterConnectionUI.prettify(d.propertyProofType)
        card.stack.add(documentRow(.idProof, icon: "person.text.rectangle", color: UIColor(argb: 0xFFD92D20), title: "ID Proof", subtitle: idSub))
        card.stack.add(divider().padded(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)))
        card.stack.add(documentRow(.propertyProof, icon: "doc.text", color: UIColor(argb: 0xFF7A5AF8), title: "Property Proof",
                                   subtitle: propSub))
        card.stack.add(divider().padded(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)))
        card.stack.add(documentRow(.selfPhoto, icon: "photo", color: UIColor(argb: 0xFF2563EB), title: "Self Photo",
                                   subtitle: "Passport size photograph"))
        card.stack.addSpacer(6)
        card.stack.add(UILabel("Document links are valid for a few minutes and are refreshed automatically when you open one.",
                               font: .poppins(11.5), color: .grey600, lines: 0)
            .padded(UIEdgeInsets(top: 0, left: 16, bottom: 14, right: 16)))
        return card
    }

    private func documentRow(_ kind: DocumentKind, icon: String, color: UIColor, title: String, subtitle: String) -> UIView {
        let available = document(kind) != nil
        let busy = openingDocument == kind
        var views: [UIView] = [
            iconTile(icon, color: color, background: color.withAlphaComponent(0.1), size: 37, iconSize: 19, radius: 10),
            UIStackView.v(1, [UILabel(title, font: .poppins(13.5, .semibold), color: WaterConnectionUI.textColor),
                              UILabel(available ? subtitle : "Not uploaded", font: .poppins(11.5), color: .grey600, lines: 0)]),
        ]
        if busy {
            let sp = UIActivityIndicatorView(style: .medium)
            sp.color = .appPrimary
            sp.startAnimating()
            views.append(sp)
        } else if available {
            let view = UILabel("View", font: .poppins(12, .semibold), color: .appPrimary)
                .padded(UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))
            view.layer.cornerRadius = 8
            view.addBorder(color: .appPrimary)
            view.setContentHuggingPriority(.required, for: .horizontal)
            views.append(view)
        }
        let row = UIStackView.h(12, views).padded(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        if available {
            row.onTap { [weak self] in
                guard let self, self.openingDocument == nil else { return }
                self.openDocument(kind, title: title, subtitle: subtitle)
            }
        }
        return row
    }
}

// MARK: - Document viewer

/// Port of lib/water_document_viewer_screen.dart — bytes are downloaded through the pinned
/// client and rendered in-app (PDFKit for PDFs, a zoomable image view for photos).
final class WaterDocumentViewerController: BaseViewController {

    private enum Format { case pdf, image, unsupported }

    private var url: String
    private let docTitle: String
    private let subtitle: String
    private let refreshLink: (() async -> String?)?

    private var bytes: Data?
    private var format: Format = .unsupported
    private var isSharing = false
    private var errorMessage: String?
    private let container = UIView()

    init(url: String, title: String, subtitle: String = "", refreshLink: (() async -> String?)? = nil) {
        self.url = url
        self.docTitle = title
        self.subtitle = subtitle
        self.refreshLink = refreshLink
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: nil, titleColor: WaterConnectionUI.textColor, backColor: .appPrimary)
        let titleLabel = UILabel(docTitle, font: .poppins(16, .semibold), color: WaterConnectionUI.textColor)
        var titleViews: [UIView] = [titleLabel]
        let sub = subtitle.trimmingCharacters(in: .whitespaces)
        if !sub.isEmpty {
            let s = UILabel(sub, font: .poppins(11.5), color: .grey600)
            s.lineBreakMode = .byTruncatingTail
            titleViews.append(s)
        }
        navigationItem.titleView = UIStackView.v(0, alignment: .center, titleViews)
        view.addSubview(container)
        container.pinToSafeArea(of: view)
        Task { await load(refreshFirst: false) }
    }

    private func updateShareItem() {
        if isSharing {
            let sp = UIActivityIndicatorView(style: .medium)
            sp.color = .appPrimary
            sp.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: sp)
        } else if bytes != nil {
            navigationItem.rightBarButtonItem = barItem("square.and.arrow.up", color: .appPrimary) { [weak self] in self?.share() }
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func load(refreshFirst: Bool) async {
        errorMessage = nil
        setLoading(true)
        do {
            if refreshFirst, let refreshLink, let fresh = await refreshLink(), !fresh.isEmpty { url = fresh }
            let data = try await APIService.shared.downloadWaterConnectionDocument(url)
            bytes = data
            format = Self.detectFormat(data)
            errorMessage = format == .unsupported
                ? "This file type cannot be previewed in the app. Use Share to open it in another app." : nil
        } catch {
            errorMessage = APIError.userMessage(error, fallback: "Could not open this document. Please try again.")
        }
        setLoading(false)
        render()
    }

    private static func detectFormat(_ b: Data) -> Format {
        let bytes = [UInt8](b.prefix(12))
        func starts(_ sig: [UInt8], at offset: Int = 0) -> Bool {
            bytes.count >= offset + sig.count && Array(bytes[offset..<offset + sig.count]) == sig
        }
        if starts([0x25, 0x50, 0x44, 0x46]) { return .pdf }
        if starts([0xFF, 0xD8, 0xFF]) || starts([0x89, 0x50, 0x4E, 0x47]) || starts([0x47, 0x49, 0x46, 0x38]) || starts([0x42, 0x4D]) {
            return .image
        }
        if starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x45, 0x42, 0x50], at: 8) { return .image }
        return .unsupported
    }

    private var fileName: String {
        let ext: String
        switch format {
        case .pdf: ext = "pdf"
        case .image: ext = (bytes?.count ?? 0) > 3 && bytes?.first == 0x89 ? "png" : "jpg"
        case .unsupported: ext = "bin"
        }
        let safe = docTitle.replacingOccurrences(of: "[^A-Za-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return "\(safe.isEmpty ? "document" : safe).\(ext)"
    }

    private func share() {
        guard let bytes, !isSharing else { return }
        isSharing = true
        updateShareItem()
        DocumentActions.share(bytes, fileName: fileName, from: self)
        isSharing = false
        updateShareItem()
    }

    private func render() {
        container.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = format == .image && errorMessage == nil ? UIColor(argb: 0xFF1A1A1A) : WaterConnectionUI.background
        updateShareItem()
        if errorMessage != nil || bytes == nil {
            renderError()
            return
        }
        guard let bytes else { return }
        switch format {
        case .pdf:
            let pdfView = PDFView()
            pdfView.autoScales = true
            pdfView.backgroundColor = WaterConnectionUI.background
            if let doc = PDFDocument(data: bytes) {
                pdfView.document = doc
                container.addSubview(pdfView)
                pdfView.pinToEdges(of: container)
            } else {
                errorMessage = "This PDF could not be rendered. Use Share / Save to open it in another app."
                renderError()
            }
        case .image:
            let zoom = ZoomImageView(image: UIImage(data: bytes))
            container.addSubview(zoom)
            zoom.pinToEdges(of: container)
            let hint = UILabel("Pinch to zoom · drag to pan", font: .poppins(11.5), color: UIColor.white.withAlphaComponent(0.7),
                               alignment: .center).padded(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
            hint.backgroundColor = UIColor.black.withAlphaComponent(0.54)
            container.addSubview(hint)
            hint.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hint.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hint.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                hint.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        case .unsupported:
            renderError()
        }
    }

    private func renderError() {
        container.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = WaterConnectionUI.background
        let canShare = bytes != nil
        let button = PrimaryButton(canShare ? "Share / Save" : "Retry", height: 46, radius: 12, fontSize: 14, weight: .semibold,
                                   icon: canShare ? "square.and.arrow.up" : "arrow.clockwise")
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 26, bottom: 0, right: 26)
        button.onEvent { [weak self] in
            guard let self else { return }
            if canShare { self.share() } else { Task { await self.load(refreshFirst: true) } }
        }
        let views: [UIView] = [
            iconTile("doc.text", background: AssessmentUI.softPrimary, size: 82, iconSize: 42, radius: 41),
            UILabel(canShare ? "Preview not available" : "Cannot open this document", font: .poppins(15.5, .bold),
                    color: WaterConnectionUI.textColor, lines: 0, alignment: .center),
            UILabel(errorMessage ?? "Please try again.", font: .poppins(13), color: .grey600, lines: 0, alignment: .center),
            button,
        ]
        let stack = UIStackView.v(0, alignment: .center, views)
        stack.setCustomSpacing(18, after: views[0])
        stack.setCustomSpacing(8, after: views[1])
        stack.setCustomSpacing(20, after: views[2])
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
        ])
    }
}

/// `InteractiveViewer(minScale: 1, maxScale: 5)` around an aspect-fit image.
final class ZoomImageView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()

    init(image: UIImage?) {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: frameLayoutGuide.heightAnchor),
        ])
        if image == nil {
            let l = UILabel("This image could not be displayed.", font: .poppins(13), color: UIColor.white.withAlphaComponent(0.7),
                            lines: 0, alignment: .center)
            addSubview(l)
            l.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                l.centerYAnchor.constraint(equalTo: frameLayoutGuide.centerYAnchor),
                l.leadingAnchor.constraint(equalTo: frameLayoutGuide.leadingAnchor, constant: 32),
                l.trailingAnchor.constraint(equalTo: frameLayoutGuide.trailingAnchor, constant: -32),
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
}
