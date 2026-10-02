import UIKit

/// Port of lib/track_grievance_screen.dart.
final class TrackGrievanceViewController: BaseViewController {

    override var screenBackground: UIColor { UIColor.Scheme.surfaceContainerLowest }

    private var applyCard: UIView!
    private var statusCard: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Track Grievance", background: UIColor.Scheme.surface, titleColor: UIColor.Scheme.onSurface,
                     rightItems: [helpItem(color: UIColor.Scheme.primary) { [weak self] in self?.startTour() }])
        installScrollStack(insets: UIEdgeInsets(top: 18, left: 16, bottom: 24, right: 16))
        applyCard = optionCard(title: "Apply Now", subtext: "Start a new request", icon: "checklist",
                               color: UIColor.Scheme.primary) { [weak self] in self?.push(ApplyGrievanceViewController()) }
        statusCard = optionCard(title: "Track Status", subtext: "Know your request status", icon: "scope",
                                color: UIColor.Scheme.secondary) { [weak self] in self?.push(GrievanceStatusViewController()) }
        contentStack.add(applyCard)
        contentStack.addSpacer(14)
        contentStack.add(statusCard)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        TourGuide.autoStartIfFirstVisit(.trackGrievance) { startTour() }
    }

    private func optionCard(title: String, subtext: String, icon: String, color: UIColor,
                            action: @escaping () -> Void) -> UIView {
        let card = CardView(radius: 18, padding: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18),
                            background: UIColor.Scheme.surface, shadowOpacity: 0.04, shadowBlur: 14, shadowY: 6,
                            border: UIColor.Scheme.outlineVariant)
        let chevron = iconTile("chevron.forward", color: UIColor.Scheme.onSurfaceVariant,
                               background: UIColor.Scheme.surfaceContainerLow, size: 32, iconSize: 12, radius: 16)
        card.stack.add(UIStackView.h(14, [
            iconTile(icon, color: color, background: color.withAlphaComponent(0.12), size: 52, iconSize: 26, radius: 14),
            UIStackView.v(3, [UILabel(title, font: .poppins(16, .bold), color: UIColor.Scheme.onSurface),
                              UILabel(subtext, font: .poppins(14), color: UIColor.Scheme.onSurfaceVariant, lines: 0)]),
            FlexSpacer(), chevron,
        ]))
        card.onTap {
            guard !TourCoachMarkView.isActive else { return }
            action()
        }
        return card
    }

    private func startTour() {
        guard !TourCoachMarkView.isActive else { return }
        TourCoachMarkView.present(steps: [
            TourStep(target: applyCard, icon: "checklist", title: "Apply Now",
                     description: "Use this option to raise a new grievance request.", shape: .roundedRect(radius: 18)),
            TourStep(target: statusCard, icon: "scope", title: "Track Status",
                     description: "Use this option to check grievance details and track your request.",
                     shape: .roundedRect(radius: 18), edge: .top),
        ], scrollContainer: scrollView)
    }
}

/// Port of lib/grievance_status_screen.dart.
final class GrievanceStatusViewController: BaseViewController {

    override var screenBackground: UIColor { .appFieldFill }

    private var firstCard: UIView?
    private var firstChip: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Grievance Status", titleColor: .black87, backColor: .black,
                     rightItems: [helpItem { [weak self] in self?.startTour(showUnavailable: true) }])
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), spacing: 16)
        Task { await load() }
    }

    private func centerMessage(_ text: String) {
        let l = UILabel(text, font: .systemFont(ofSize: 14), color: .black87, lines: 0, alignment: .center)
        view.addSubview(l)
        l.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            l.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            l.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            l.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func load() async {
        setLoading(true)
        guard let email = StorageService.emailId, !email.isEmpty else {
            setLoading(false)
            centerMessage("Error: Exception: Email not found in storage")
            return
        }
        do {
            let response = try await APIService.shared.getGrievanceDetails(emailId: email)
            setLoading(false)
            guard let list = response.data, !list.isEmpty else {
                centerMessage("No grievances found.")
                return
            }
            for (i, g) in list.enumerated() { contentStack.add(card(g, first: i == 0)) }
            DispatchQueue.main.async { [weak self] in
                TourGuide.autoStartIfFirstVisit(.grievanceStatus) { self?.startTour(showUnavailable: false) }
            }
        } catch {
            setLoading(false)
            centerMessage("Error: Exception: \(APIError.userMessage(error))")
        }
    }

    private func card(_ g: GrievanceDetails, first: Bool) -> UIView {
        let card = CardView(radius: 15, shadowOpacity: 0.05, shadowBlur: 10, shadowY: 4)
        let chip = UILabel("Pending", font: .poppins(12, .semibold), color: .mOrange)
            .padded(UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
        chip.backgroundColor = UIColor.mOrange.withAlphaComponent(0.1)
        chip.layer.cornerRadius = 12
        chip.setContentHuggingPriority(.required, for: .horizontal)
        card.stack.add(UIStackView.h(8, [
            UILabel("ID: \(g.grievanceNo ?? "N/A")", font: .poppins(16, .bold), color: UIColor(argb: 0xFF0E3B90), lines: 0),
            FlexSpacer(), chip,
        ]))
        card.stack.add(divider(color: .grey300, thickness: 0.5).padded(UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)))
        for (label, value) in [("Category", g.categoryName), ("Sub-category", g.subcategoryName), ("Date & Time", g.updatedAt)] {
            let l = UILabel("\(label):", font: .poppins(14, .semibold), color: .grey700)
            l.setSize(width: 110)
            card.stack.add(UIStackView.h(0, alignment: .top, [l, UILabel(value ?? "N/A", font: .poppins(14), color: .grey600, lines: 0)])
                .padded(UIEdgeInsets(top: 0, left: 0, bottom: 4, right: 0)))
        }
        card.onTap { [weak self] in
            guard !TourCoachMarkView.isActive, let no = g.grievanceNo else { return }
            self?.push(GrievanceStatusDetailsViewController(grievanceNo: no))
        }
        if first {
            firstCard = card
            firstChip = chip
        }
        return card
    }

    private func startTour(showUnavailable: Bool) {
        guard !TourCoachMarkView.isActive else { return }
        guard let firstCard, let firstChip else {
            if showUnavailable { snack("Tour will be available once grievance records load.") }
            return
        }
        TourCoachMarkView.present(steps: [
            TourStep(target: firstCard, icon: "doc.text", title: "Grievance Card",
                     description: "This card shows your grievance number, category, sub-category, and updated date. Tap it to open full grievance details.",
                     shape: .roundedRect(radius: 16)),
            TourStep(target: firstChip, icon: "clock.badge.exclamationmark", title: "Current Status",
                     description: "Use this badge to quickly check the latest status of your grievance request.",
                     shape: .roundedRect(radius: 16)),
        ], scrollContainer: scrollView)
    }
}

/// Port of lib/grievance_status_details_screen.dart.
final class GrievanceStatusDetailsViewController: BaseViewController {

    override var screenBackground: UIColor { .appFieldFill }
    private let grievanceNo: String

    init(grievanceNo: String) {
        self.grievanceNo = grievanceNo
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Grievance Details", titleColor: .black87, backColor: .black)
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 20, right: 16))
        Task { await load() }
    }

    private func message(_ text: String) {
        let l = UILabel(text, font: .systemFont(ofSize: 14), color: .black87, lines: 0, alignment: .center)
        view.addSubview(l)
        l.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            l.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            l.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            l.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func load() async {
        setLoading(true)
        // Flutter reads the app-wide language cache here (not a property's own value).
        let krutidev = UlbLanguageHelper.isKrutidev
        do {
            let response = try await APIService.shared.getGrievanceStatus(grievanceNo: grievanceNo)
            setLoading(false)
            guard let d = response.data.first else { message("No details found."); return }
            render(d, krutidev: krutidev)
        } catch {
            setLoading(false)
            message("Error: Exception: \(APIError.userMessage(error))")
        }
    }

    private func render(_ d: GrievanceStatusData, krutidev: Bool) {
        let header = UIView()
        let gradient = GradientView(colors: [.mBlue50, .mBlue100])
        (gradient.layer as? CAGradientLayer)?.startPoint = .zero
        (gradient.layer as? CAGradientLayer)?.endPoint = CGPoint(x: 1, y: 1)
        gradient.layer.cornerRadius = 20
        header.addSubview(gradient)
        gradient.pinToEdges(of: header)
        header.layer.shadowColor = UIColor.mBlue.cgColor
        header.layer.shadowOpacity = 0.15
        header.layer.shadowRadius = 5
        header.layer.shadowOffset = CGSize(width: 0, height: 4)
        let chip = UILabel(d.status ?? "Pending", font: .poppins(12, .semibold), color: UIColor(argb: 0xFF0D47A1))
            .padded(UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))
        chip.backgroundColor = UIColor.mBlue.withAlphaComponent(0.1)
        chip.layer.cornerRadius = 14
        chip.setContentHuggingPriority(.required, for: .horizontal)
        let idLabel = UILabel("ID: \(d.complaintId ?? "N/A")", font: .poppins(18, .bold), color: .black87)
        idLabel.lineBreakMode = .byTruncatingTail
        let headerStack = UIStackView.v(10, [UIStackView.h(12, [idLabel, chip]),
                                             UILabel(d.categoryName ?? "Complaint", font: .poppins(14), color: .black54, lines: 0)])
        header.addSubview(headerStack)
        headerStack.pinToEdges(of: header, insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
        contentStack.add(header)
        contentStack.addSpacer(16)

        let addressRaw = "\(d.address1 ?? "") \(d.address2 ?? "")".trimmingCharacters(in: .whitespaces)
        section("Basic Information", [
            ("Name", d.name ?? "N/A", true), ("Father Name", d.fatherHusbandName ?? "N/A", true),
            ("Mobile", d.mobile ?? "N/A", false), ("Email", d.email ?? "N/A", false),
        ], krutidev: krutidev)
        section("Location Details", [
            ("ULB", d.ulbName ?? "N/A", false), ("Zone", d.zoneName ?? "N/A", false), ("Ward", d.wardName ?? "N/A", false),
            ("Mohalla", d.mohallaName ?? "N/A", false), ("Landmark", d.landmark ?? "N/A", false),
            ("Address", addressRaw.isEmpty ? "N/A" : addressRaw, true),
        ], krutidev: krutidev)
        section("Complaint Details", [
            ("Category", d.categoryName ?? "N/A", false), ("Sub-category", d.subCategoryName ?? "N/A", false),
            ("Description", d.complaintDesc ?? "N/A", false), ("Date", d.complaintDate ?? "N/A", false),
            ("Time", d.complaintTime ?? "N/A", false),
        ], krutidev: krutidev)
        section("Assignment & Resolution", [
            ("Assigned Official", d.assignedOffName ?? "N/A", false), ("Official Mobile", d.assignedOffMobile ?? "N/A", false),
            ("Employee Name", d.assignedEmpName ?? "N/A", false), ("Close Remark", d.closeRemark ?? "N/A", false),
            ("Resolution Date", d.closeDate ?? "N/A", false),
        ], krutidev: krutidev, last: true)
    }

    private func section(_ title: String, _ rows: [(String, String, Bool)], krutidev: Bool, last: Bool = false) {
        contentStack.add(UILabel(title, font: .poppins(16, .bold), color: .appTextDark)
            .padded(UIEdgeInsets(top: 0, left: 4, bottom: 8, right: 0)))
        let card = CardView(radius: 15, background: UIColor(argb: 0xFFFBFCFF), shadowOpacity: 0.01, shadowBlur: 10, shadowY: 2)
        for (label, value, language) in rows {
            let l = UILabel("\(label):", font: .poppins(13, .medium), color: .grey600)
            l.setSize(width: 120)
            let v = UILabel(value, font: UlbLanguageHelper.font(13, .semibold, krutidev: language && krutidev),
                            color: .appTextMid, lines: 0)
            card.stack.add(UIStackView.h(0, alignment: .top, [l, v]).padded(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)))
        }
        contentStack.add(card)
        if !last { contentStack.addSpacer(16) }
    }
}
