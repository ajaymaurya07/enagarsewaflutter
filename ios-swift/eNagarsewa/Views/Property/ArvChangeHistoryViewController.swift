import UIKit
import Combine

/// Matches Flutter's ArvChangeHistoryScreen:
/// property load -> (auto OTP / pick property) -> OTP verify -> ARV change timeline.
final class ArvChangeHistoryViewController: UIViewController {

    private let viewModel: ArvChangeHistoryViewModel
    private var cancellables = Set<AnyCancellable>()
    private var expandedIndices: Set<Int> = []

    private let contentContainer = UIView()
    private let loadingSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .large)
        s.color = .appPrimary
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    init(viewModel: ArvChangeHistoryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.961, green: 0.965, blue: 0.980, alpha: 1)
        setupNavBar()
        setupContainer()
        bindViewModel()
        viewModel.loadProperties()
    }

    // MARK: - Layout scaffolding

    private func setupNavBar() {
        let navRow = UIView()
        navRow.backgroundColor = .white
        navRow.translatesAutoresizingMaskIntoConstraints = false

        let backBtn = UIButton(type: .system)
        backBtn.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        backBtn.tintColor = .appPrimary
        backBtn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "ARV Change History"
        titleLabel.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        titleLabel.textColor = .appCardText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        navRow.addSubview(backBtn)
        navRow.addSubview(titleLabel)
        view.addSubview(navRow)
        view.addSubview(contentContainer)
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            navRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navRow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navRow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navRow.heightAnchor.constraint(equalToConstant: 52),

            backBtn.leadingAnchor.constraint(equalTo: navRow.leadingAnchor, constant: 8),
            backBtn.centerYAnchor.constraint(equalTo: navRow.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: 36),
            backBtn.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.centerXAnchor.constraint(equalTo: navRow.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navRow.centerYAnchor),

            contentContainer.topAnchor.constraint(equalTo: navRow.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupContainer() {
        contentContainer.addSubview(loadingSpinner)
        loadingSpinner.center(in: contentContainer)
    }

    @objc private func backTapped() { navigationController?.popViewController(animated: true) }

    // MARK: - Bindings

    private func bindViewModel() {
        Publishers.CombineLatest4(
            viewModel.$isLoadingInit, viewModel.$initError,
            viewModel.$needsPropertySelect, viewModel.$isOtpVerified
        )
        .combineLatest(viewModel.$isLoadingHistory)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _ in self?.render() }
        .store(in: &cancellables)

        viewModel.$historyError.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.render() }.store(in: &cancellables)

        viewModel.$sortNewestFirst.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.render() }.store(in: &cancellables)

        viewModel.$historyItems.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.expandedIndices = Set(0..<(self?.viewModel.historyItems.count ?? 0))
                self?.render()
            }.store(in: &cancellables)
    }

    // MARK: - Render state machine

    private func render() {
        contentContainer.subviews.forEach { if $0 !== loadingSpinner { $0.removeFromSuperview() } }

        if viewModel.isLoadingInit || viewModel.isLoadingHistory {
            loadingSpinner.isHidden = false
            loadingSpinner.startAnimating()
            return
        }
        loadingSpinner.stopAnimating()
        loadingSpinner.isHidden = true

        if let err = viewModel.initError {
            showStatePane(icon: "exclamationmark.circle", message: err, buttonTitle: "Try Again") { [weak self] in
                self?.viewModel.loadProperties()
            }
            return
        }
        if viewModel.needsPropertySelect {
            showPropertySelect()
            return
        }
        if !viewModel.isOtpVerified {
            // OTP is being sent / awaiting sheet presentation
            presentOtpSheetIfNeeded()
            return
        }
        if let err = viewModel.historyError {
            showStatePane(icon: "clock.arrow.circlepath", message: err, buttonTitle: "Retry") { [weak self] in
                self?.viewModel.retryHistory()
            }
            return
        }
        showTimeline()
    }

    // MARK: - Error / empty state pane

    private func showStatePane(icon: String, message: String, buttonTitle: String, action: @escaping () -> Void) {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = UIColor.systemRed.withAlphaComponent(0.6)
        iconView.contentMode = .scaleAspectFit
        iconView.setSize(width: 56, height: 56)

        let label = UILabel()
        label.text = message
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        label.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)

        let button = UIButton.primaryButton(title: buttonTitle)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 28, bottom: 10, right: 28)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconView, label, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Property select list

    private func showPropertySelect() {
        let headerLabel = UILabel()
        headerLabel.text = "Select Property"
        headerLabel.font = UIFont(name: "Poppins-Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
        headerLabel.textColor = .appCardText

        let subLabel = UILabel()
        subLabel.text = "Choose which property's ARV change history you want to view."
        subLabel.font = UIFont(name: "Poppins-Regular", size: 12.5) ?? .systemFont(ofSize: 12.5)
        subLabel.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        subLabel.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [headerLabel, subLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.layoutMargins = UIEdgeInsets(top: 18, left: 20, bottom: 14, right: 20)
        headerStack.backgroundColor = .white

        var cards: [UIView] = []
        for property in viewModel.properties {
            cards.append(makePropertyCard(property))
        }
        let cardsStack = UIStackView(arrangedSubviews: cards)
        cardsStack.axis = .vertical
        cardsStack.spacing = 12

        let scroll = UIScrollView()
        let content = UIView()
        [scroll, content, cardsStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        scroll.addSubview(content)
        content.addSubview(cardsStack)

        let mainStack = UIStackView(arrangedSubviews: [headerStack, scroll])
        mainStack.axis = .vertical
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor),

            cardsStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            cardsStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            cardsStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            cardsStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
        ])
    }

    private func makePropertyCard(_ property: PropertyEntity) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.addCardShadow()

        let idLabel = UILabel()
        idLabel.text = property.propertyId
        idLabel.font = UIFont(name: "Poppins-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        idLabel.textColor = .appCardText

        let ownerLabel = UILabel()
        ownerLabel.text = property.ownerName
        ownerLabel.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        ownerLabel.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)

        let textStack = UIStackView(arrangedSubviews: [idLabel, ownerLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        let chevron = UIImageView(image: UIImage(systemName: "chevron.forward"))
        chevron.tintColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
        chevron.setSize(width: 14, height: 14)

        let row = UIStackView(arrangedSubviews: [textStack, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        row.pinToEdges(of: card)

        let tap = UITapGestureRecognizer(target: self, action: #selector(propertyCardTapped(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        card.tag = viewModel.properties.firstIndex(where: { $0.propertyId == property.propertyId }) ?? 0
        return card
    }

    @objc private func propertyCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let card = gesture.view else { return }
        let property = viewModel.properties[card.tag]
        viewModel.sendOtp(for: property)
    }

    // MARK: - OTP sheet

    private var isOtpSheetPresented = false

    private func presentOtpSheetIfNeeded() {
        guard !viewModel.isLoadingInit, !isOtpSheetPresented, presentedViewController == nil else { return }
        isOtpSheetPresented = true
        let sheet = ArvOtpSheetViewController(viewModel: viewModel) { [weak self] verified in
            self?.isOtpSheetPresented = false
            if !verified {
                self?.navigationController?.popViewController(animated: true)
            }
        }
        sheet.modalPresentationStyle = .pageSheet
        sheet.isModalInPresentation = true
        if let pc = sheet.sheetPresentationController {
            pc.detents = [.medium()]
            pc.prefersGrabberVisible = true
        }
        present(sheet, animated: true)
    }

    // MARK: - Timeline content

    private func showTimeline() {
        let scroll = UIScrollView()
        let content = UIView()
        [scroll, content].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        scroll.addSubview(content)
        contentContainer.addSubview(scroll)
        scroll.pinToEdges(of: contentContainer)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        let infoCard = buildPropertyInfoCard()
        let sectionHeader = buildSectionHeader()

        let items = viewModel.displayItems
        var itemViews: [UIView] = []
        if items.isEmpty {
            itemViews.append(buildEmptyTimelineView())
        } else {
            for (i, item) in items.enumerated() {
                itemViews.append(buildTimelineRow(item, index: i, isFirst: i == 0, isLast: i == items.count - 1))
            }
        }
        let itemsStack = UIStackView(arrangedSubviews: itemViews)
        itemsStack.axis = .vertical
        itemsStack.spacing = 0

        let mainStack = UIStackView(arrangedSubviews: [infoCard, sectionHeader, itemsStack])
        mainStack.axis = .vertical
        mainStack.setCustomSpacing(0, after: infoCard)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
        ])
    }

    private func buildPropertyInfoCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.addCardShadow()

        let property = viewModel.selectedProperty
        let first = viewModel.historyItems.first

        func cell(_ label: String, _ value: String, blue: Bool = false) -> UIView {
            let l = UILabel(); l.text = label
            l.font = UIFont(name: "Poppins-Regular", size: 10.5) ?? .systemFont(ofSize: 10.5)
            l.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
            let v = UILabel(); v.text = value; v.numberOfLines = 2
            v.font = UIFont(name: "Poppins-Bold", size: 12) ?? .boldSystemFont(ofSize: 12)
            v.textColor = blue ? UIColor(red: 0.08, green: 0.4, blue: 0.75, alpha: 1) : .appCardText
            let s = UIStackView(arrangedSubviews: [l, v]); s.axis = .vertical; s.spacing = 2
            return s
        }

        func row(_ l: UIView, _ r: UIView) -> UIView {
            let s = UIStackView(arrangedSubviews: [l, r])
            s.axis = .horizontal; s.distribution = .fillEqually
            return s
        }

        let rows = UIStackView(arrangedSubviews: [
            row(cell("Property ID", property?.propertyId ?? first?.propertyId ?? "\u{2014}", blue: true),
                cell("House No.", first?.houseNo ?? "\u{2014}")),
            row(cell("Owner Name", property?.ownerName ?? first?.ownerName ?? "\u{2014}"),
                cell("Current ARV", first.map { "\(Int($0.currentArv ?? 0))" } ?? "\u{2014}")),
            row(cell("Property Address", property?.address ?? first?.address ?? "\u{2014}"),
                cell("Language", first?.ulbLanguage ?? "\u{2014}")),
        ])
        rows.axis = .vertical
        rows.spacing = 12
        rows.isLayoutMarginsRelativeArrangement = true
        rows.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        rows.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rows)
        rows.pinToEdges(of: card)
        return card
    }

    private func buildSectionHeader() -> UIView {
        let label = UILabel()
        label.text = "ARV Change History (\(viewModel.historyItems.count))"
        label.font = UIFont(name: "Poppins-Bold", size: 13.5) ?? .boldSystemFont(ofSize: 13.5)
        label.textColor = .appCardText

        let sortBtn = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = "Sort: \(viewModel.sortNewestFirst ? "Newest First" : "Oldest First")"
        config.image = UIImage(systemName: "arrow.up.arrow.down")
        config.imagePlacement = .leading
        config.imagePadding = 4
        config.baseForegroundColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        config.background.strokeColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        config.background.strokeWidth = 1
        config.background.cornerRadius = 20
        config.attributedTitle = AttributedString("Sort: \(viewModel.sortNewestFirst ? "Newest First" : "Oldest First")",
            attributes: AttributeContainer([.font: UIFont(name: "Poppins-Medium", size: 11) ?? .systemFont(ofSize: 11)]))
        sortBtn.configuration = config
        sortBtn.addAction(UIAction { [weak self] _ in self?.viewModel.toggleSort() }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [label, UIView(), sortBtn])
        row.axis = .horizontal
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 16, left: 0, bottom: 10, right: 0)
        return row
    }

    private func buildEmptyTimelineView() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "clock.arrow.circlepath"))
        icon.tintColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        icon.setSize(width: 56, height: 56)
        let label = UILabel()
        label.text = "No Records Found"
        label.font = UIFont(name: "Poppins-SemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
        let sub = UILabel()
        sub.text = "No ARV change history for this property."
        sub.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        sub.textColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
        let stack = UIStackView(arrangedSubviews: [icon, label, sub])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 40, left: 0, bottom: 40, right: 0)
        return stack
    }

    private func buildTimelineRow(_ item: ArvChangeHistoryItem, index: Int, isFirst: Bool, isLast: Bool) -> UIView {
        let isCurrent = item.arvChangeDate == viewModel.currentItemDate
        let isExpanded = expandedIndices.contains(index)

        // Timeline dot column
        let dot = UIView()
        dot.layer.cornerRadius = isCurrent ? 15 : 7
        dot.backgroundColor = isCurrent ? .systemGreen : UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.setSize(width: isCurrent ? 30 : 14, height: isCurrent ? 30 : 14)
        if isCurrent {
            let arrow = UIImageView(image: UIImage(systemName: "arrow.up"))
            arrow.tintColor = .white
            arrow.contentMode = .scaleAspectFit
            arrow.translatesAutoresizingMaskIntoConstraints = false
            dot.addSubview(arrow)
            NSLayoutConstraint.activate([
                arrow.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
                arrow.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
                arrow.widthAnchor.constraint(equalToConstant: 14),
                arrow.heightAnchor.constraint(equalToConstant: 14),
            ])
        }

        let lineTop = UIView()
        lineTop.backgroundColor = isFirst ? .clear : UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        lineTop.setSize(width: 2)
        let lineBottom = UIView()
        lineBottom.backgroundColor = isLast ? .clear : UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        lineBottom.setSize(width: 2)

        let timelineCol = UIStackView(arrangedSubviews: [lineTop, dot, lineBottom])
        timelineCol.axis = .vertical
        timelineCol.alignment = .center
        timelineCol.spacing = 4
        timelineCol.setSize(width: 30)

        // Card
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 12
        card.addCardShadow()

        let titleLabel = UILabel()
        titleLabel.text = "ARV Updated"
        titleLabel.font = isCurrent
            ? (UIFont(name: "Poppins-Bold", size: 13.5) ?? .boldSystemFont(ofSize: 13.5))
            : (UIFont(name: "Poppins-Regular", size: 13.5) ?? .systemFont(ofSize: 13.5))
        titleLabel.textColor = isCurrent ? .appCardText : UIColor(red: 0.44, green: 0.44, blue: 0.44, alpha: 1)

        var headerViews: [UIView] = [titleLabel]
        if isCurrent {
            let badge = UILabel()
            badge.text = "  Current  "
            badge.font = UIFont(name: "Poppins-SemiBold", size: 10.5) ?? .systemFont(ofSize: 10.5, weight: .semibold)
            badge.textColor = .systemGreen
            badge.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.08)
            badge.layer.cornerRadius = 10
            badge.layer.borderWidth = 1
            badge.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.5).cgColor
            badge.clipsToBounds = true
            headerViews.append(badge)
        }
        let headerRow = UIStackView(arrangedSubviews: headerViews)
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.isLayoutMarginsRelativeArrangement = true
        headerRow.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 10, right: 14)

        var cardChildren: [UIView] = [headerRow]

        if isExpanded {
            let divider1 = UIView(); divider1.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1); divider1.setSize(height: 1)
            let details = UIStackView(arrangedSubviews: [
                detailRow("Old ARV", "\(Int(item.oldArv ?? 0))"),
                detailRow("New ARV", "\(Int(item.currentArv ?? 0))"),
                detailRow("Changed By", item.ownerName ?? "\u{2014}"),
                detailRow("Change Date", item.arvChangeDate ?? "\u{2014}"),
                detailRow("ULB ID", item.ulbId.map { "\($0)" } ?? "\u{2014}", highlight: true),
            ])
            details.axis = .vertical
            details.isLayoutMarginsRelativeArrangement = true
            details.layoutMargins = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            cardChildren.append(divider1)
            cardChildren.append(details)
        }

        let toggleBtn = UIButton(type: .system)
        toggleBtn.setImage(UIImage(systemName: isExpanded ? "chevron.up" : "chevron.down"), for: .normal)
        toggleBtn.tintColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
        toggleBtn.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        toggleBtn.tag = index
        toggleBtn.addTarget(self, action: #selector(toggleExpand(_:)), for: .touchUpInside)
        toggleBtn.translatesAutoresizingMaskIntoConstraints = false
        toggleBtn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        cardChildren.append(toggleBtn)

        let cardStack = UIStackView(arrangedSubviews: cardChildren)
        cardStack.axis = .vertical
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        cardStack.pinToEdges(of: card)

        let row = UIStackView(arrangedSubviews: [timelineCol, card])
        row.axis = .horizontal
        row.alignment = .fill
        row.spacing = 8
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        return row
    }

    private func detailRow(_ label: String, _ value: String, highlight: Bool = false) -> UIView {
        let l = UILabel(); l.text = label
        l.font = UIFont(name: "Poppins-Regular", size: 12.5) ?? .systemFont(ofSize: 12.5)
        l.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        let v = UILabel(); v.text = value; v.textAlignment = .right
        v.font = UIFont(name: "Poppins-SemiBold", size: 12.5) ?? .systemFont(ofSize: 12.5, weight: .semibold)
        v.textColor = highlight ? UIColor(red: 0.08, green: 0.4, blue: 0.75, alpha: 1) : .appCardText

        let divider = UIView(); divider.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1); divider.setSize(height: 1)

        let row = UIStackView(arrangedSubviews: [l, v])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)

        let wrap = UIStackView(arrangedSubviews: [row, divider])
        wrap.axis = .vertical
        return wrap
    }

    @objc private func toggleExpand(_ sender: UIButton) {
        if expandedIndices.contains(sender.tag) {
            expandedIndices.remove(sender.tag)
        } else {
            expandedIndices.insert(sender.tag)
        }
        render()
    }
}

// MARK: - OTP bottom sheet

final class ArvOtpSheetViewController: UIViewController {

    private let viewModel: ArvChangeHistoryViewModel
    private let onFinish: (Bool) -> Void
    private var cancellables = Set<AnyCancellable>()

    private let otpField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.textAlignment = .center
        tf.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        tf.defaultTextAttributes[.kern] = 6
        tf.backgroundColor = .appFieldFill
        tf.layer.cornerRadius = 14
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.appFieldBorder.cgColor
        tf.heightAnchor.constraint(equalToConstant: 54).isActive = true
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let errorLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "Poppins-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .systemRed
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    private lazy var verifyButton = UIButton.primaryButton(title: "Verify OTP")
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.setTitleColor(UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1), for: .normal)
        b.titleLabel?.font = UIFont(name: "Poppins-SemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        return b
    }()

    init(viewModel: ArvChangeHistoryViewModel, onFinish: @escaping (Bool) -> Void) {
        self.viewModel = viewModel
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        bindViewModel()
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    private func setupLayout() {
        let banner = UIView()
        banner.backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.898, alpha: 1)
        banner.layer.cornerRadius = 12
        let bannerLabel = UILabel()
        bannerLabel.text = "ARV change history is sensitive property data. Verify your mobile number to continue."
        bannerLabel.numberOfLines = 0
        bannerLabel.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        bannerLabel.textColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
        bannerLabel.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(bannerLabel)
        NSLayoutConstraint.activate([
            bannerLabel.topAnchor.constraint(equalTo: banner.topAnchor, constant: 12),
            bannerLabel.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -12),
            bannerLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            bannerLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
        ])

        let titleLabel = UILabel()
        titleLabel.text = "Enter OTP"
        titleLabel.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        titleLabel.textColor = .appCardText

        let subtitleLabel = UILabel()
        subtitleLabel.text = "A 6-digit code was sent to \(viewModel.maskedMobile)"
        subtitleLabel.font = UIFont(name: "Poppins-Regular", size: 12.5) ?? .systemFont(ofSize: 12.5)
        subtitleLabel.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)

        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [
            banner, titleLabel, subtitleLabel, errorLabel, otpField, verifyButton, cancelButton
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(20, after: banner)
        stack.setCustomSpacing(16, after: subtitleLabel)
        stack.setCustomSpacing(20, after: otpField)
        stack.setCustomSpacing(10, after: verifyButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            verifyButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func bindViewModel() {
        viewModel.$isVerifyingOtp.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.verifyButton.setLoading(loading)
            self?.cancelButton.isEnabled = !loading
        }.store(in: &cancellables)

        viewModel.$otpSheetError.receive(on: DispatchQueue.main).sink { [weak self] msg in
            self?.errorLabel.isHidden = (msg == nil)
            self?.errorLabel.text = msg
        }.store(in: &cancellables)
    }

    @objc private func verifyTapped() {
        view.endEditing(true)
        let otp = otpField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !otp.isEmpty else { viewModel.otpSheetError = "Please enter the OTP"; return }
        guard otp.count >= 4 else { viewModel.otpSheetError = "Please enter a valid OTP"; return }

        viewModel.verifyOtp(otp) { [weak self] verified in
            DispatchQueue.main.async {
                guard let self else { return }
                if verified {
                    self.dismiss(animated: true) { self.onFinish(true) }
                }
            }
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) { self.onFinish(false) }
    }
}
