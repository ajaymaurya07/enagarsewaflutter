import UIKit

/// Port of lib/arv_change_history_screen.dart.
final class ArvChangeHistoryViewController: BaseViewController {

    override var screenBackground: UIColor { UIColor(argb: 0xFFF5F6FA) }

    private enum State { case loading, initError(String), selectProperty, history, historyError(String) }

    private var state = State.loading
    private var properties: [PropertyEntity] = []
    private var selected: PropertyEntity?
    private var items: [ArvChangeHistoryItem] = []
    private var sortNewestFirst = true
    private var expanded: Set<String> = []
    private var currentItemDate: String?
    private var ulbNameById: [String: String] = [:]
    private let container = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "ARV Change History", titleColor: UIColor(argb: 0xFF222222), backColor: .appPrimary)
        view.addSubview(container)
        container.pinToSafeArea(of: view)
        Task { await loadProperties() }
        Task {
            if let list = try? await APIService.shared.getUlbData() {
                for u in list { if let id = u.ulbId, let name = u.ulbName { ulbNameById[id] = name } }
                if case .history = state { render() }
            }
        }
    }

    // MARK: - Data

    private func loadProperties() async {
        state = .loading
        render()
        let props = await DatabaseService.shared.getAllProperties()
        guard !props.isEmpty else {
            state = .initError("No property found. Please select a property first.")
            render()
            return
        }
        properties = props
        if props.count == 1 {
            await selectAndFetch(props[0])
        } else {
            state = .selectProperty
            render()
        }
    }

    private func selectAndFetch(_ property: PropertyEntity) async {
        selected = property
        await fetchHistory(property.propertyId)
    }

    private func key(_ item: ArvChangeHistoryItem, _ idx: Int) -> String {
        "\(item.arvChangeDate ?? String(idx))_\(item.oldArvText)_\(item.currentArvText)"
    }

    private func fetchHistory(_ propertyId: String) async {
        state = .loading
        items = []
        expanded.removeAll()
        render()
        do {
            let res = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: selected?.phoneNumber ?? "",
                                                         responseCode: { $0.responseCode }) {
                try await APIService.shared.getArvChangeHistory(propertyId: propertyId)
            }
            if res.success == true {
                items = res.data ?? []
                currentItemDate = items.first?.arvChangeDate
                for (i, item) in items.enumerated() { expanded.insert(key(item, i)) }
                state = .history
            } else {
                state = .historyError(res.message ?? "Failed to fetch ARV history")
            }
        } catch {
            state = .historyError(APIError.userMessage(error, fallback: "Unable to load ARV history. Please try again."))
        }
        render()
    }

    // MARK: - Rendering

    private func render() {
        container.subviews.forEach { $0.removeFromSuperview() }
        let content: UIView
        switch state {
        case .loading:
            let s = UIActivityIndicatorView(style: .large)
            s.color = .appPrimary
            s.startAnimating()
            content = s
            container.addSubview(s)
            s.center(in: container)
            return
        case .initError(let message):
            content = errorView(icon: "exclamationmark.circle", message: message, button: "Try Again") { [weak self] in
                Task { await self?.loadProperties() }
            }
        case .historyError(let message):
            content = errorView(icon: "clock.badge.xmark", message: message, button: "Retry") { [weak self] in
                guard let self, let p = self.selected else { return }
                Task { await self.fetchHistory(p.propertyId) }
            }
        case .selectProperty:
            content = propertySelectView()
            container.addSubview(content)
            content.pinToEdges(of: container)
            return
        case .history:
            content = historyView()
            container.addSubview(content)
            content.pinToEdges(of: container)
            return
        }
        container.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
        ])
    }

    private func errorView(icon: String, message: String, button: String, action: @escaping () -> Void) -> UIView {
        let b = PrimaryButton(button, height: 46, radius: 12, fontSize: 14, weight: .semibold)
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
        b.onEvent(.touchUpInside, action)
        let l = UILabel(message, font: .poppins(14), color: .grey600, lines: 0, alignment: .center)
        l.setLineHeight(1.4)
        let stack = UIStackView.v(0, alignment: .center, [UIImageView(symbol: icon, size: 56, color: .mRed300), l, b])
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[0])
        stack.setCustomSpacing(28, after: l)
        return stack
    }

    private func propertySelectView() -> UIView {
        let header = UIStackView.v(4, [
            UILabel("Select Property", font: .poppins(15, .bold), color: UIColor(argb: 0xFF222222)),
            UILabel("Choose which property's ARV change history you want to view.", font: .poppins(12.5),
                    color: .grey500, lines: 0),
        ]).padded(UIEdgeInsets(top: 18, left: 20, bottom: 14, right: 20))
        header.backgroundColor = .white

        let scroll = UIScrollView()
        let list = UIStackView.v(12, [])
        scroll.addSubview(list)
        list.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            list.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            list.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            list.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            list.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
        for p in properties {
            let card = CardView(radius: 14, shadowOpacity: 0.04, shadowBlur: 10, shadowY: 4)
            var texts: [UIView] = [
                UILabel(p.propertyId, font: .poppins(13, .bold), color: UIColor(argb: 0xFF222222)),
                UILabel(p.ownerName, font: UlbLanguageHelper.isKrutidevValue(p.ulbLang) ? .krutidev(12) : .poppins(12),
                        color: .grey500, lines: 0),
            ]
            if !p.ward.isEmpty { texts.append(UILabel("Ward: \(p.ward)", font: .poppins(11), color: .grey400)) }
            let textStack = UIStackView.v(2, texts)
            card.stack.add(UIStackView.h(14, [iconTile("building.2", size: 42, iconSize: 20, radius: 10), textStack,
                                              FlexSpacer(), UIImageView(symbol: "chevron.forward", size: 13, color: .grey400)]))
            card.onTap { [weak self] in Task { await self?.selectAndFetch(p) } }
            list.add(card)
        }
        let stack = UIStackView.v(0, [header, divider(), scroll])
        return stack
    }

    private var displayItems: [ArvChangeHistoryItem] { sortNewestFirst ? items : items.reversed() }

    private func historyView() -> UIView {
        let shown = displayItems
        let sortChip = UIStackView.h(4, [
            UIImageView(symbol: "arrow.up.arrow.down", size: 11, color: .grey600),
            UILabel("Sort: \(sortNewestFirst ? "Newest First" : "Oldest First")", font: .poppins(11, .medium), color: .grey600),
            UIImageView(symbol: "chevron.down", size: 10, color: .grey600),
        ]).padded(UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10))
        sortChip.backgroundColor = .white
        sortChip.layer.cornerRadius = 14
        sortChip.addBorder(color: .grey200)
        sortChip.onTap { [weak self] in
            self?.sortNewestFirst.toggle()
            self?.render()
        }
        let header = UIStackView.h(8, [
            UILabel("ARV Change History (\(shown.count))", font: .poppins(13.5, .bold), color: UIColor(argb: 0xFF222222)),
            FlexSpacer(), sortChip,
        ]).padded(UIEdgeInsets(top: 16, left: 16, bottom: 10, right: 16))

        let scroll = UIScrollView()
        let stack = UIStackView.v(0, [header])
        scroll.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
        if shown.isEmpty {
            let empty = UIStackView.v(4, alignment: .center, [
                UIImageView(symbol: "clock.arrow.circlepath", size: 56, color: .grey300),
                UILabel("No Records Found", font: .poppins(14, .semibold), color: .grey400),
                UILabel("No ARV change history for this property.", font: .poppins(12), color: .grey400),
            ])
            stack.add(empty.padded(UIEdgeInsets(top: 120, left: 16, bottom: 0, right: 16)))
        } else {
            for (i, item) in shown.enumerated() {
                stack.add(timelineItem(item, idx: i, total: shown.count).padded(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)))
            }
        }
        return scroll
    }

    private func timelineItem(_ item: ArvChangeHistoryItem, idx: Int, total: Int) -> UIView {
        let isCurrent = item.arvChangeDate == currentItemDate
        let k = key(item, idx)
        let isExpanded = expanded.contains(k)

        // Timeline rail
        let rail = UIView()
        rail.setSize(width: 44)
        let topLine = UIView(), bottomLine = UIView()
        topLine.backgroundColor = idx == 0 ? .clear : .grey300
        bottomLine.backgroundColor = idx == total - 1 ? .clear : .grey300
        let dot: UIView = isCurrent
            ? iconTile("arrow.up", color: .white, background: UIColor(argb: 0xFF4CAF50), size: 30, iconSize: 14, radius: 15)
            : { let d = UIView(); d.backgroundColor = .grey600; d.layer.cornerRadius = 7; d.setSize(width: 14, height: 14); return d }()
        [topLine, dot, bottomLine].forEach { rail.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            topLine.topAnchor.constraint(equalTo: rail.topAnchor),
            topLine.centerXAnchor.constraint(equalTo: rail.centerXAnchor),
            topLine.widthAnchor.constraint(equalToConstant: 2),
            topLine.heightAnchor.constraint(equalToConstant: isCurrent ? 16 : 23),
            dot.topAnchor.constraint(equalTo: topLine.bottomAnchor),
            dot.centerXAnchor.constraint(equalTo: rail.centerXAnchor),
            bottomLine.topAnchor.constraint(equalTo: dot.bottomAnchor),
            bottomLine.centerXAnchor.constraint(equalTo: rail.centerXAnchor),
            bottomLine.widthAnchor.constraint(equalToConstant: 2),
            bottomLine.bottomAnchor.constraint(equalTo: rail.bottomAnchor),
        ])

        // Card
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 12
        card.addShadow(opacity: 0.04, blur: 8, offsetY: 3)
        let clip = UIStackView.v(0, [])
        let inner = UIView()
        inner.layer.cornerRadius = 12
        inner.clipsToBounds = true
        inner.addSubview(clip)
        clip.pinToEdges(of: inner)
        card.addSubview(inner)
        inner.pinToEdges(of: card)

        var titleRow: [UIView] = [UILabel("ARV Updated", font: .poppins(13.5, isCurrent ? .bold : .medium),
                                          color: isCurrent ? UIColor(argb: 0xFF222222) : .grey700), FlexSpacer()]
        if isCurrent {
            let chip = UILabel("Current", font: .poppins(10.5, .semibold), color: .mGreen700).padded(UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10))
            chip.backgroundColor = .mGreen50
            chip.layer.cornerRadius = 10
            chip.addBorder(color: UIColor(argb: 0xFF66BB6A))
            titleRow.append(chip)
        }
        clip.add(UIStackView.h(8, titleRow).padded(UIEdgeInsets(top: 12, left: 14, bottom: 10, right: 14)))

        if isExpanded {
            let krutidev = UlbLanguageHelper.isKrutidevValue(selected?.ulbLang)
            let entries: [(String, String, Bool, Bool)] = [
                ("Property ID", item.propertyId ?? "—", true, false),
                ("Old Property ID", item.oldPropertyId ?? "—", false, false),
                ("Owner Name", item.ownerName ?? "—", false, true),
                ("Father/Husband Name", item.fatherHusbandName ?? "—", false, true),
                ("House No.", item.houseNo ?? "—", false, false),
                ("Address", item.address ?? "—", false, true),
                ("Old ARV", item.oldArvText, false, false),
                ("New ARV", item.currentArvText, false, false),
                ("Change Date", item.arvChangeDate ?? "—", false, false),
                ("ULB Name", item.ulbId.map { ulbNameById[String($0)] ?? String($0) } ?? "—", true, false),
                ("ULB Language", item.ulbLanguage ?? "—", false, false),
            ]
            let rows = UIStackView.v(0, [])
            for (i, e) in entries.enumerated() {
                let l = UILabel(e.0, font: .poppins(12.5), color: .grey500, lines: 0)
                let useKd = e.3 && krutidev
                let v = UILabel(e.1, font: UlbLanguageHelper.font(12.5, .semibold, krutidev: useKd),
                                color: e.2 && !useKd ? UIColor(argb: 0xFF1565C0) : UIColor(argb: 0xFF222222),
                                lines: 0, alignment: .right)
                let row = UIStackView.h(0, alignment: .center, [l, v])
                l.widthAnchor.constraint(equalTo: v.widthAnchor, multiplier: 2.0 / 3.0).isActive = true
                rows.add(row.padded(UIEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)))
                if i != entries.count - 1 { rows.add(divider(color: .grey100)) }
            }
            clip.add(divider(color: .grey100), rows.padded(UIEdgeInsets(top: 2, left: 14, bottom: 0, right: 14)))
        }
        let toggle = UIImageView(symbol: isExpanded ? "chevron.up" : "chevron.down", size: 14, color: .grey400, weight: .semibold)
        let toggleBar = centered(toggle).padded(UIEdgeInsets(top: 7, left: 0, bottom: 7, right: 0))
        toggleBar.backgroundColor = .grey50
        toggleBar.onTap { [weak self] in
            guard let self else { return }
            if self.expanded.contains(k) { self.expanded.remove(k) } else { self.expanded.insert(k) }
            self.render()
        }
        clip.add(toggleBar)

        let cardWrap = card.padded(UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0))
        return UIStackView.h(8, alignment: .fill, [rail, cardWrap])
    }
}
