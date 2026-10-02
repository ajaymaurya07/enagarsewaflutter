import UIKit

/// Port of lib/dashboard_screen.dart.
final class DashboardViewController: BaseViewController {

    override var hidesNavigationBar: Bool { true }

    private var userType = ""
    private var displayName = "User"
    private var canSearchProperty: Bool {
        let t = userType.lowercased()
        return t == "admin" || t == "citizen"
    }

    private var statuses: [PropertyPaymentStatus] = []
    private var currentPage = 0
    private var sliderTimer: Timer?
    private var reloadOnAppear = false

    private let nameLabel = UILabel(nil, font: .poppins(20, .bold), color: .appPrimary)
    private let sliderClip = UIView()
    private let sliderScroll = UIScrollView()
    private let sliderRow = UIStackView.h(0, alignment: .fill, [])
    private let indicator = UIStackView.h(6, [])
    private var indicatorContainer = UIView()
    private let searchCard = UIView()
    private let bottomBar = DashboardBottomBar()
    private var serviceCards: [String: UIView] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadUserInfo()
        Task { await loadPaymentStatuses() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if reloadOnAppear {
            reloadOnAppear = false
            Task { await loadPaymentStatuses() }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAutoScroll()
        TourGuide.autoStartIfFirstVisit(.dashboard) { startTour() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sliderTimer?.invalidate()
        sliderTimer = nil
    }

    // MARK: - Layout

    private func buildUI() {
        let welcome = UILabel("Welcome", font: .poppins(14, .medium), color: .grey600)
        let header = UIStackView.h(8, [
            UIStackView.v(0, [welcome, nameLabel]), FlexSpacer(),
            iconButton("questionmark.circle", color: .appPrimary) { [weak self] in self?.startTour() },
        ])
        view.addSubview(header)
        header.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(bottomBar)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.onTapHistory = { [weak self] in self?.push(TransactionHistoryViewController()) }
        bottomBar.onTapAccount = { [weak self] in self?.push(AccountViewController()) }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 40, right: 16), below: header, above: bottomBar)
        view.bringSubviewToFront(bottomBar)

        // Slider (PageView, viewportFraction 0.95, height 150)
        sliderClip.clipsToBounds = true
        sliderClip.setSize(height: 150)
        sliderScroll.isPagingEnabled = true
        sliderScroll.showsHorizontalScrollIndicator = false
        sliderScroll.clipsToBounds = false
        sliderScroll.delegate = self
        sliderClip.addSubview(sliderScroll)
        sliderScroll.translatesAutoresizingMaskIntoConstraints = false
        sliderScroll.addSubview(sliderRow)
        sliderRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sliderScroll.topAnchor.constraint(equalTo: sliderClip.topAnchor),
            sliderScroll.bottomAnchor.constraint(equalTo: sliderClip.bottomAnchor),
            sliderScroll.centerXAnchor.constraint(equalTo: sliderClip.centerXAnchor),
            sliderScroll.widthAnchor.constraint(equalTo: sliderClip.widthAnchor, multiplier: 0.95),
            sliderRow.topAnchor.constraint(equalTo: sliderScroll.contentLayoutGuide.topAnchor),
            sliderRow.bottomAnchor.constraint(equalTo: sliderScroll.contentLayoutGuide.bottomAnchor),
            sliderRow.leadingAnchor.constraint(equalTo: sliderScroll.contentLayoutGuide.leadingAnchor),
            sliderRow.trailingAnchor.constraint(equalTo: sliderScroll.contentLayoutGuide.trailingAnchor),
            sliderRow.heightAnchor.constraint(equalTo: sliderScroll.frameLayoutGuide.heightAnchor),
        ])
        contentStack.add(sliderClip)
        indicatorContainer = centered(indicator).padded(UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0))
        contentStack.add(indicatorContainer)
        indicatorContainer.isHidden = true

        // Search New Property
        buildSearchCard()
        contentStack.addSpacer(24)
        contentStack.add(searchCard)

        contentStack.addSpacer(32)
        let title = NSAttributedString(string: "Quick Services", attributes: [
            .font: UIFont.poppins(18, .bold), .foregroundColor: UIColor.appTextLabel, .kern: 0.1])
        let titleLabel = UILabel()
        titleLabel.attributedText = title
        contentStack.add(titleLabel)
        contentStack.addSpacer(16)
        contentStack.add(buildServiceGrid())
        renderSlider()
    }

    private func buildSearchCard() {
        searchCard.backgroundColor = .white
        searchCard.layer.cornerRadius = 16
        searchCard.addShadow(opacity: 0.04, blur: 15, offsetY: 8)
        let texts = UIStackView.v(0, [
            UILabel("Search New Property", font: .poppins(16, .bold), color: .appTextMid),
            UILabel("Add more properties to your list", font: .poppins(12), color: .grey600),
        ])
        let row = UIStackView.h(16, [
            iconTile("plus.rectangle.on.rectangle", size: 52, iconSize: 26),
            texts, FlexSpacer(),
            UIImageView(symbol: "chevron.forward", size: 14, color: .appTextFaint, weight: .semibold),
        ])
        searchCard.addSubview(row)
        row.pinToEdges(of: searchCard, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        searchCard.onTap { [weak self] in self?.push(SearchPropertyViewController()) }
        searchCard.isHidden = true
    }

    private func buildServiceGrid() -> UIView {
        typealias Service = (key: String, title: String, desc: String, icon: String, lines: Int, action: () -> Void)
        let services: [Service] = [
            ("ots", "OTS", "Visit the department portal", "globe", 3, { [weak self] in
                self?.push(UrbanDevelopmentWebViewController()) }),
            ("propertyTax", "Property Tax", "Manage all property tax", "building.2", 2, { [weak self] in
                self?.reloadOnAppear = true
                self?.push(PropertyTaxViewController()) }),
            ("grievance", "Track Grievance", "Manage all property grievances", "doc.text", 2, { [weak self] in
                self?.push(TrackGrievanceViewController()) }),
            ("arv", "ARV Change History", "Manage all ARV change history", "clock.arrow.circlepath", 2, { [weak self] in
                self?.push(ArvChangeHistoryViewController()) }),
            ("assessment", "Property Tax Assessment", "Manage all property assessments", "chart.bar.doc.horizontal", 2, { [weak self] in
                self?.push(AssessmentTypeSelectionViewController()) }),
            ("water", "Water & Sewerage", "Manage water and sewerage services", "drop", 2, { [weak self] in
                self?.push(WaterConnectionListViewController()) }),
            ("mutation", "Mutation", "Manage name transfer and mutation", "arrow.left.arrow.right", 2, { [weak self] in
                self?.push(MutationViewController()) }),
        ]
        let grid = UIStackView.v(14, [])
        var row: UIStackView?
        for (i, s) in services.enumerated() {
            if i % 2 == 0 {
                row = UIStackView.h(14, alignment: .top, [])
                row!.distribution = .fillEqually
                grid.addArrangedSubview(row!)
            }
            let card = serviceCard(title: s.title, desc: s.desc, icon: s.icon, lines: s.lines)
            card.onTap(s.action)
            serviceCards[s.key] = card
            row!.addArrangedSubview(card)
        }
        if services.count % 2 == 1 { row?.addArrangedSubview(UIView()) }
        return grid
    }

    private func serviceCard(title: String, desc: String, icon: String, lines: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.addShadow(opacity: 0.05, blur: 15, offsetY: 8)
        let t = UILabel(title, font: .poppins(14, .bold), color: .appTextMid, lines: lines)
        t.lineBreakMode = .byTruncatingTail
        let d = UILabel(desc, font: .poppins(11), color: .appTextSub, lines: 0)
        let tile = iconTile(icon, size: 46, iconSize: 24)
        let stack = UIStackView.v(0, alignment: .leading, [tile, t, d])
        stack.setCustomSpacing(16, after: tile)
        stack.setCustomSpacing(6, after: t)
        card.addSubview(stack)
        stack.pinToEdges(of: card, insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
        return card
    }

    // MARK: - User

    private func loadUserInfo() {
        userType = StorageService.userType ?? ""
        switch userType.lowercased() {
        case "admin": displayName = "Admin"
        case "citizen": displayName = "Citizen"
        default: displayName = userType
        }
        if displayName.isEmpty { displayName = "User" }
        nameLabel.text = displayName
        searchCard.isHidden = !canSearchProperty
    }

    // MARK: - Payment status slider (local DB only — no network)

    private func loadPaymentStatuses() async {
        let properties = await DatabaseService.shared.getAllProperties()
        statuses = properties.compactMap(PropertyPaymentStatus.init(entity:))
        if currentPage >= 1 + statuses.count { currentPage = 0 }
        renderSlider()
        sendPaymentNotificationsIfNeeded(statuses)
    }

    private var sliderCount: Int { 1 + statuses.count }

    private func renderSlider() {
        sliderRow.removeAllArranged()
        var slides: [UIView] = [fastPaymentSlide()]
        slides += statuses.map(statusSlide)
        for slide in slides {
            let page = UIView()
            page.addSubview(slide)
            slide.pinToEdges(of: page, insets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8))
            sliderRow.addArrangedSubview(page)
            page.widthAnchor.constraint(equalTo: sliderScroll.frameLayoutGuide.widthAnchor).isActive = true
        }
        view.layoutIfNeeded()
        sliderScroll.contentOffset = CGPoint(x: CGFloat(currentPage) * sliderScroll.bounds.width, y: 0)
        renderIndicator()
    }

    private func renderIndicator() {
        indicator.removeAllArranged()
        indicatorContainer.isHidden = sliderCount < 2
        for i in 0..<sliderCount {
            let dot = UIView()
            dot.layer.cornerRadius = 3
            dot.backgroundColor = i == currentPage ? .appPrimary : .appPrimaryBorder
            dot.setSize(width: i == currentPage ? 18 : 6, height: 6)
            indicator.addArrangedSubview(dot)
        }
    }

    private func sliderCardBase() -> UIView {
        let v = UIView()
        v.backgroundColor = .appPrimaryLight
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.appPrimaryBorder.cgColor
        return v
    }

    private func fastPaymentSlide() -> UIView {
        let card = sliderCardBase()
        let texts = UIStackView.v(4, [
            UILabel("Fast Online Payment", font: .poppins(16, .bold), color: .appPrimary),
            UILabel("Make instant payments using UPI or Debit Card.", font: .poppins(12), color: .appTextBody, lines: 0),
        ])
        let row = UIStackView.h(16, [UIImageView(symbol: "bell.badge", size: 32, color: .appPrimary), texts])
        card.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            row.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return card
    }

    private func statusSlide(_ status: PropertyPaymentStatus) -> UIView {
        let card = sliderCardBase()
        let color = status.color
        var titleRow: [UIView] = [UILabel("Payment Status", font: .poppins(14, .semibold), color: .appPrimary), FlexSpacer()]
        if status.isPaid { titleRow.append(UIImageView(symbol: "checkmark.circle.fill", size: 18, color: .mGreen600)) }

        let badgeView = UIView()
        badgeView.backgroundColor = color.withAlphaComponent(0.1)
        badgeView.layer.cornerRadius = 8
        badgeView.addBorder(color: color)
        let badgeLabel = UILabel(status.status, font: .poppins(12, .bold), color: color)
        badgeView.addSubview(badgeLabel)
        badgeLabel.pinToEdges(of: badgeView, insets: UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))
        badgeView.setContentHuggingPriority(.required, for: .horizontal)
        badgeView.setContentCompressionResistancePriority(.required, for: .horizontal)

        var dueViews: [UIView] = [UILabel(status.billDate.map { "Due: \($0)" } ?? "Due: N/A",
                                          font: .poppins(11.5, .semibold), color: .appTextMid)]
        if !status.isPaid, status.netPayable != nil {
            dueViews.append(UILabel("Payable: ₹\(status.netPayableText)", font: .poppins(11.5, .semibold), color: color))
        }

        let top = UIStackView.v(0, [
            UIStackView.h(0, titleRow),
            UILabel(status.label, font: .poppins(11, .semibold), color: .appTextMid),
            UILabel(status.message, font: .poppins(11.5), color: .appTextBody, lines: 2),
        ])
        top.setCustomSpacing(2, after: top.arrangedSubviews[0])
        top.setCustomSpacing(6, after: top.arrangedSubviews[1])
        let bottom = UIStackView.h(10, [badgeView, UIStackView.v(0, dueViews)])

        card.addSubview(top)
        card.addSubview(bottom)
        top.translatesAutoresizingMaskIntoConstraints = false
        bottom.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            top.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            top.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            bottom.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            bottom.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -16),
            bottom.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func startAutoScroll() {
        sliderTimer?.invalidate()
        sliderTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self, self.sliderCount >= 2, !TourCoachMarkView.isActive else { return }
            self.currentPage = (self.currentPage + 1) % self.sliderCount
            UIView.animate(withDuration: 0.45, delay: 0, options: .curveEaseInOut) {
                self.sliderScroll.contentOffset = CGPoint(x: CGFloat(self.currentPage) * self.sliderScroll.bounds.width, y: 0)
            }
            self.renderIndicator()
        }
    }

    // MARK: - Payment due notifications (per property, per alert type, once a day)

    private func sendPaymentNotificationsIfNeeded(_ statuses: [PropertyPaymentStatus]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let comps = calendar.dateComponents([.year, .month, .day], from: today)
        for status in statuses where !status.isPaid {
            guard let due = status.dueDate,
                  let diff = calendar.dateComponents([.day], from: today, to: due).day else { continue }
            let message: String
            switch diff {
            case 7: message = "Your payment is due in 7 days."
            case 3: message = "Your payment is due in 3 days."
            case 1: message = "Your payment is due tomorrow."
            case 0: message = "Your payment is due today."
            case -3: message = "Your payment is overdue by 3 days."
            case -7: message = "Your payment is overdue by 7 days."
            default: continue
            }
            let key = "payment_notif_\(status.propertyId)_\(comps.year!)_\(comps.month!)_\(comps.day!)_\(diff)"
            guard !UserDefaultsService.shared.flag(key) else { continue }
            UserDefaultsService.shared.setFlag(key)
            PushNotificationService.shared.showLocalNotification(
                title: "Payment Alert", body: "Property \(status.propertyId): \(message)")
        }
    }

    // MARK: - Tour

    private func startTour() {
        var steps: [TourStep] = []
        if canSearchProperty {
            steps.append(TourStep(target: searchCard, icon: "plus.rectangle.on.rectangle", title: "Search New Property",
                                  description: "Use this option to search and add more properties to your list before proceeding with further services.",
                                  shape: .roundedRect(radius: 16)))
        }
        let items: [(String, String, String, String, TourCardEdge)] = [
            ("propertyTax", "building.2", "Property Tax", "Use this option to view and manage your property tax related services.", .bottom),
            ("grievance", "doc.text", "Track Grievance", "Use this section to review grievance requests and track their current status.", .bottom),
            ("arv", "clock.arrow.circlepath", "ARV Change History", "Use this option to review previous ARV change history records related to your property services.", .bottom),
            ("assessment", "chart.bar.doc.horizontal", "Property Tax Assessment", "Use this option to access property tax assessment services and related details.", .bottom),
            ("mutation", "arrow.left.arrow.right", "Mutation", "Use this option for property name transfer and mutation related services.", .top),
            ("water", "drop", "Water And Sewerage", "Use this section to access water and sewerage related services provided in the application.", .top),
        ]
        for (key, icon, title, body, edge) in items {
            guard let target = serviceCards[key] else { continue }
            steps.append(TourStep(target: target, icon: icon, title: title, description: body,
                                  shape: .roundedRect(radius: 16), edge: edge))
        }
        steps.append(TourStep(target: bottomBar, icon: "location.north.circle", title: "Bottom Navigation",
                              description: "Use the bottom navigation bar to move between Home, Transaction History, and Account sections at any time.",
                              shape: .roundedRect(radius: 14), edge: .top))
        TourCoachMarkView.present(steps: steps, scrollContainer: scrollView)
    }
}

extension DashboardViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === sliderScroll, scrollView.bounds.width > 0 else { return }
        currentPage = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        renderIndicator()
    }
}

// MARK: - Payment status model (Dart `_PropertyPaymentStatus`)

struct PropertyPaymentStatus {
    let propertyId: String
    let billDate: String?
    let dueDate: Date?
    let netPayable: Double?
    let status: String

    /// nil when neither bill date nor net payable is cached — no card for that property.
    init?(entity: PropertyEntity) {
        let billDate = Self.clean(entity.billDate)
        let netPayable = Self.parseAmount(entity.netPayable)
        guard billDate != nil || netPayable != nil else { return nil }
        let due = Self.parseDate(billDate)
        let paid = netPayable.map { $0 <= 0 } ?? false
        if paid {
            status = "Payment Done"
        } else if let due {
            let today = Calendar.current.startOfDay(for: Date())
            status = due < today ? "Overdue" : (due == today ? "Due Today" : "Upcoming")
        } else {
            status = "Payment Due"
        }
        self.propertyId = entity.propertyId
        self.billDate = billDate
        self.dueDate = due
        self.netPayable = netPayable
    }

    var isPaid: Bool { status == "Payment Done" }

    var color: UIColor {
        switch status {
        case "Payment Done": return .mGreen
        case "Overdue":      return .mRed
        case "Due Today":    return .mOrange
        case "Upcoming":     return .mBlue
        default:             return .mDeepOrange
        }
    }

    var label: String { "PID: \(propertyId)" }

    var message: String {
        switch status {
        case "Payment Done": return "Payment received successfully. Your account is up to date."
        case "Overdue":      return "Your payment is overdue. Please clear dues to avoid penalties."
        case "Due Today":    return "Your payment is due today. Complete payment to stay updated."
        case "Upcoming":     return "Your payment is upcoming. You can pay early for convenience."
        default:             return "You have an outstanding amount on this property."
        }
    }

    var netPayableText: String {
        guard let amount = netPayable else { return "-" }
        return amount == amount.rounded() ? String(Int(amount)) : String(format: "%.2f", amount)
    }

    static func clean(_ value: String?) -> String? {
        guard let t = value?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, t != "-",
              t.lowercased() != "null", t.lowercased() != "n/a" else { return nil }
        return t
    }

    static func parseAmount(_ value: String?) -> Double? {
        clean(value).flatMap { Double($0.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "₹", with: "")) }
    }

    /// `dd-mm-yyyy` → local midnight; nil on bad format.
    static func parseDate(_ value: String?) -> Date? {
        guard let parts = value?.trimmingCharacters(in: .whitespaces).split(separator: "-"), parts.count == 3,
              let d = Int(parts[0]), let m = Int(parts[1]), let y = Int(parts[2]) else { return nil }
        return Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
    }
}

// MARK: - Bottom navigation

final class DashboardBottomBar: UIView {

    var onTapHistory: (() -> Void)?
    var onTapAccount: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 7.5
        layer.shadowOffset = CGSize(width: 0, height: -2)

        let home = tab("house.fill", "Home", selected: true) {}
        let history = tab("list.bullet.rectangle.portrait.fill", "History", selected: false) { [weak self] in self?.onTapHistory?() }
        let account = tab("person.fill", "Account", selected: false) { [weak self] in self?.onTapAccount?() }
        let stack = UIStackView.h(0, alignment: .fill, [home, history, account])
        stack.distribution = .fillEqually
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: 58),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private func tab(_ icon: String, _ title: String, selected: Bool, action: @escaping () -> Void) -> UIView {
        let color: UIColor = selected ? .appPrimary : .appTextHint
        let v = UIStackView.v(3, alignment: .center, [
            UIImageView(symbol: icon, size: 21, color: color),
            UILabel(title, font: .poppins(12, selected ? .semibold : .medium), color: color),
        ])
        let container = UIView()
        container.addSubview(v)
        v.center(in: container)
        container.onTap(action)
        return container
    }
}
