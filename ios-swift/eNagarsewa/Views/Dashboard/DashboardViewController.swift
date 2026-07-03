import UIKit
import Combine

// MARK: - DashboardViewController

final class DashboardViewController: UIViewController {

    private let viewModel: DashboardViewModel
    private var cancellables = Set<AnyCancellable>()

    private var sliderTimer: Timer?
    private var currentSliderPage = 0

    // Refs updated from bindings
    private weak var displayNameLabel: UILabel?
    private weak var adminCardView: UIView?
    private weak var paymentStatusSlide: PaymentStatusSlideView?
    private weak var sliderScrollView: UIScrollView?

    // Refs kept for the first-run tour guide (see DashboardTourGuide below)
    private weak var propertyTaxCardView: UIView?
    private weak var grievanceCardView: UIView?
    private weak var arvHistoryCardView: UIView?
    private weak var propertyTaxAssessmentCardView: UIView?
    private weak var mutationCardView: UIView?
    private weak var waterSewerageCardView: UIView?
    private weak var bottomBarView: UIView?
    private var didPresentTour = false

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        bindViewModel()
        viewModel.onViewAppear()
        startSliderTimer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentTourIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sliderTimer?.invalidate(); sliderTimer = nil
    }

    // MARK: - Layout

    private func setupLayout() {
        // Bottom bar
        let bottomBar = DashboardBottomBar()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.onTapHistory = { [weak self] in self?.viewModel.didTapTransactionHistory() }
        bottomBar.onTapAccount = { [weak self] in self?.viewModel.didTapAccount() }
        view.addSubview(bottomBar)
        bottomBarView = bottomBar

        // Main scroll
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        // Header
        let header = buildHeader()

        // Slider
        let slider = buildSlider()

        // Admin card
        let adminCard = buildAdminCard()
        adminCard.isHidden = true
        adminCardView = adminCard

        // Section label
        let sectionLabel = UILabel()
        sectionLabel.text = "Quick Services"
        sectionLabel.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        sectionLabel.textColor = UIColor(red: 0.333, green: 0.333, blue: 0.333, alpha: 1)

        // Service grid
        let grid = buildServiceGrid()

        let mainStack = UIStackView(arrangedSubviews: [header, slider, adminCard, sectionLabel, grid])
        mainStack.axis = .vertical
        mainStack.spacing = 0
        mainStack.setCustomSpacing(24, after: slider)
        mainStack.setCustomSpacing(24, after: adminCard)
        mainStack.setCustomSpacing(16, after: sectionLabel)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: content.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Header

    private func buildHeader() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let welcomeLabel = UILabel()
        welcomeLabel.text = "Welcome"
        welcomeLabel.font = UIFont(name: "Poppins-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        welcomeLabel.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)

        let nameLabel = UILabel()
        nameLabel.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        nameLabel.textColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        displayNameLabel = nameLabel

        let textStack = UIStackView(arrangedSubviews: [welcomeLabel, nameLabel])
        textStack.axis = .vertical
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let helpBtn = UIButton(type: .system)
        helpBtn.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        helpBtn.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        helpBtn.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(textStack)
        container.addSubview(helpBtn)
        NSLayoutConstraint.activate([
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: helpBtn.leadingAnchor, constant: -8),
            helpBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            helpBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            helpBtn.widthAnchor.constraint(equalToConstant: 40),
            helpBtn.heightAnchor.constraint(equalToConstant: 40),
        ])
        return container
    }

    // MARK: - Slider

    private func buildSlider() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 150).isActive = true

        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.bounces = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sv)
        sv.pinToEdges(of: container)
        sliderScrollView = sv

        let sliderContent = UIView()
        sliderContent.translatesAutoresizingMaskIntoConstraints = false
        sv.addSubview(sliderContent)

        let slide1 = buildFastPaymentSlide()
        slide1.translatesAutoresizingMaskIntoConstraints = false
        let slide2 = PaymentStatusSlideView()
        slide2.translatesAutoresizingMaskIntoConstraints = false
        paymentStatusSlide = slide2

        sliderContent.addSubview(slide1)
        sliderContent.addSubview(slide2)

        NSLayoutConstraint.activate([
            sliderContent.topAnchor.constraint(equalTo: sv.topAnchor),
            sliderContent.leadingAnchor.constraint(equalTo: sv.leadingAnchor),
            sliderContent.trailingAnchor.constraint(equalTo: sv.trailingAnchor),
            sliderContent.bottomAnchor.constraint(equalTo: sv.bottomAnchor),
            sliderContent.heightAnchor.constraint(equalTo: sv.heightAnchor),

            slide1.topAnchor.constraint(equalTo: sliderContent.topAnchor),
            slide1.leadingAnchor.constraint(equalTo: sliderContent.leadingAnchor),
            slide1.bottomAnchor.constraint(equalTo: sliderContent.bottomAnchor),
            slide1.widthAnchor.constraint(equalTo: sv.widthAnchor),

            slide2.topAnchor.constraint(equalTo: sliderContent.topAnchor),
            slide2.leadingAnchor.constraint(equalTo: slide1.trailingAnchor),
            slide2.bottomAnchor.constraint(equalTo: sliderContent.bottomAnchor),
            slide2.widthAnchor.constraint(equalTo: sv.widthAnchor),
            slide2.trailingAnchor.constraint(equalTo: sliderContent.trailingAnchor),
        ])
        return container
    }

    private func buildFastPaymentSlide() -> UIView {
        let card = sliderCard()

        let icon = UIImageView(image: UIImage(systemName: "bell.badge"))
        icon.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 36).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let titleL = UILabel()
        titleL.text = "Fast Online Payment"
        titleL.font = UIFont(name: "Poppins-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        titleL.textColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)

        let subL = UILabel()
        subL.text = "Make instant payments using UPI or Debit Card."
        subL.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        subL.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        subL.numberOfLines = 2

        let tStack = UIStackView(arrangedSubviews: [titleL, subL])
        tStack.axis = .vertical; tStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [icon, tStack])
        row.axis = .horizontal; row.spacing = 16; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            row.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }

    private func sliderCard() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.898, alpha: 1)
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(red: 1.0, green: 0.878, blue: 0.698, alpha: 1).cgColor
        return v
    }

    // MARK: - Admin card

    private func buildAdminCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.addCardShadow()
        card.isUserInteractionEnabled = true

        let iconCircle = UIView()
        iconCircle.backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.898, alpha: 1)
        iconCircle.layer.cornerRadius = 12
        iconCircle.widthAnchor.constraint(equalToConstant: 52).isActive = true
        iconCircle.heightAnchor.constraint(equalToConstant: 52).isActive = true
        let icon = UIImageView(image: UIImage(systemName: "building.2.crop.circle"))
        icon.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
        ])

        let titleL = UILabel()
        titleL.text = "Search New Property"
        titleL.font = UIFont(name: "Poppins-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        titleL.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)

        let subL = UILabel()
        subL.text = "Add more properties to your list"
        subL.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        subL.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)

        let tStack = UIStackView(arrangedSubviews: [titleL, subL])
        tStack.axis = .vertical; tStack.spacing = 2

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 16).isActive = true

        let row = UIStackView(arrangedSubviews: [iconCircle, tStack, chevron])
        row.axis = .horizontal; row.spacing = 16; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(searchPropertyTapped)))
        return card
    }

    // MARK: - Service grid

    private let serviceConfigs: [(title: String, desc: String, icon: String, sel: Selector?)] = [
        ("Property Tax",             "Manage all property tax",           "house.circle",                 #selector(taxTapped)),
        ("Track Grievance",          "Manage all property grievances",    "doc.text.magnifyingglass",     #selector(grievanceTapped)),
        ("ARV Change History",       "Manage all ARV change history",     "clock.arrow.circlepath",       #selector(arvHistoryTapped)),
        ("Property Tax Assessment",  "Manage all property assessments",   "chart.bar.doc.horizontal",     nil),
        ("Mutation",                 "Manage name transfer and mutation", "arrow.left.arrow.right.circle",nil),
        ("Water & Sewerage",         "Manage water and sewerage services","drop.circle",                  nil),
    ]

    private func buildServiceGrid() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        var rows: [UIStackView] = []

        for i in stride(from: 0, to: serviceConfigs.count, by: 2) {
            var cells: [UIView] = []
            for j in 0..<2 {
                let idx = i + j
                if idx < serviceConfigs.count {
                    let cfg = serviceConfigs[idx]
                    let card = buildServiceCard(title: cfg.title, desc: cfg.desc, icon: cfg.icon, selector: cfg.sel)
                    switch idx {
                    case 0: propertyTaxCardView = card
                    case 1: grievanceCardView = card
                    case 2: arvHistoryCardView = card
                    case 3: propertyTaxAssessmentCardView = card
                    case 4: mutationCardView = card
                    case 5: waterSewerageCardView = card
                    default: break
                    }
                    cells.append(card)
                } else {
                    let spacer = UIView(); cells.append(spacer)
                }
            }
            let row = UIStackView(arrangedSubviews: cells)
            row.axis = .horizontal; row.spacing = 14; row.distribution = .fillEqually
            rows.append(row)
        }

        let grid = UIStackView(arrangedSubviews: rows)
        grid.axis = .vertical; grid.spacing = 14
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func buildServiceCard(title: String, desc: String, icon: String, selector: Selector?) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.clipsToBounds = false
        card.addCardShadow()

        let iconCircle = UIView()
        iconCircle.backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.898, alpha: 1)
        iconCircle.layer.cornerRadius = 12
        iconCircle.widthAnchor.constraint(equalToConstant: 46).isActive = true
        iconCircle.heightAnchor.constraint(equalToConstant: 46).isActive = true
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),
        ])

        let titleL = UILabel()
        titleL.text = title
        titleL.font = UIFont(name: "Poppins-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
        titleL.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
        titleL.numberOfLines = 2

        let descL = UILabel()
        descL.text = desc
        descL.font = UIFont(name: "Poppins-Regular", size: 11) ?? .systemFont(ofSize: 11)
        descL.textColor = UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1)
        descL.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [titleL, descL])
        textStack.axis = .vertical; textStack.spacing = 6

        let cardStack = UIStackView(arrangedSubviews: [iconCircle, textStack])
        cardStack.axis = .vertical; cardStack.spacing = 16
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        if let sel = selector {
            card.isUserInteractionEnabled = true
            card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: sel))
        }
        return card
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$displayName.receive(on: DispatchQueue.main)
            .sink { [weak self] name in self?.displayNameLabel?.text = name }
            .store(in: &cancellables)

        viewModel.$userType.receive(on: DispatchQueue.main)
            .sink { [weak self] type in self?.adminCardView?.isHidden = (type.lowercased() != "admin") }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            viewModel.$isLoadingPaymentStatus,
            viewModel.$paymentStatus,
            viewModel.$billDate,
            viewModel.$paymentDate
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] loading, status, bill, payment in
            guard let self else { return }
            self.paymentStatusSlide?.update(
                isLoading: loading,
                hasData: self.viewModel.propertyDetails != nil,
                status: status,
                billDate: bill,
                paymentDate: payment,
                statusColor: self.viewModel.paymentStatusColor(),
                message: self.viewModel.paymentStatusMessage()
            )
        }
        .store(in: &cancellables)
    }

    // MARK: - Slider timer

    private func startSliderTimer() {
        sliderTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.advanceSlider()
        }
    }

    private func advanceSlider() {
        guard let sv = sliderScrollView else { return }
        currentSliderPage = (currentSliderPage + 1) % 2
        let offset = CGPoint(x: CGFloat(currentSliderPage) * sv.frame.width, y: 0)
        sv.setContentOffset(offset, animated: true)
    }

    // MARK: - Actions

    @objc private func searchPropertyTapped() { viewModel.didTapSearchProperty() }
    @objc private func taxTapped()            { viewModel.didTapPropertyTax() }
    @objc private func grievanceTapped()      { viewModel.didTapTrackGrievance() }
    @objc private func arvHistoryTapped()     { viewModel.didTapArvChangeHistory() }

    // MARK: - Tour guide (first-run coach mark, see lib/tour_guides/dashboard_tour.dart)

    private func presentTourIfNeeded() {
        guard !didPresentTour, !UserDefaultsService.shared.hasTourBeenSeen(.dashboard) else { return }
        guard let propertyTaxCardView, let grievanceCardView, let arvHistoryCardView,
              let propertyTaxAssessmentCardView, let mutationCardView,
              let waterSewerageCardView, let bottomBarView else { return }
        didPresentTour = true

        var steps: [TourStep] = []
        if let adminCardView, !adminCardView.isHidden {
            steps.append(TourStep(
                target: adminCardView,
                icon: "building.2.crop.circle",
                title: "Search New Property",
                description: "Admin users can use this option to search and add more properties to their list before proceeding with further services.",
                edge: .bottom
            ))
        }
        steps.append(contentsOf: [
            TourStep(target: propertyTaxCardView, icon: "house.circle",
                     title: "Property Tax",
                     description: "Use this option to view and manage your property tax related services.",
                     edge: .bottom),
            TourStep(target: grievanceCardView, icon: "doc.text.magnifyingglass",
                     title: "Track Grievance",
                     description: "Use this section to review grievance requests and track their current status.",
                     edge: .bottom),
            TourStep(target: arvHistoryCardView, icon: "clock.arrow.circlepath",
                     title: "ARV Change History",
                     description: "Use this option to review previous ARV change history records related to your property services.",
                     edge: .bottom),
            TourStep(target: propertyTaxAssessmentCardView, icon: "chart.bar.doc.horizontal",
                     title: "Property Tax Assessment",
                     description: "Use this option to access property tax assessment services and related details.",
                     edge: .top),
            TourStep(target: mutationCardView, icon: "arrow.left.arrow.right.circle",
                     title: "Mutation",
                     description: "Use this option for property name transfer and mutation related services when available.",
                     edge: .top),
            TourStep(target: waterSewerageCardView, icon: "drop.circle",
                     title: "Water And Sewerage",
                     description: "Use this section to access water and sewerage related services provided in the application.",
                     edge: .top),
            TourStep(target: bottomBarView, icon: "arrow.left.arrow.right",
                     title: "Bottom Navigation",
                     description: "Use the bottom navigation bar to move between Home, Transaction History, and Account sections at any time.",
                     edge: .top),
        ])

        TourCoachMarkView.present(steps: steps) {
            UserDefaultsService.shared.markTourSeen(.dashboard)
        }
    }
}

// MARK: - PaymentStatusSlideView

final class PaymentStatusSlideView: UIView {

    private let spinner = UIActivityIndicatorView(style: .medium)
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let statusBadge = UIView()
    private let statusLabel = UILabel()
    private let dueDateLabel = UILabel()
    private let payDateLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.898, alpha: 1)
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 1.0, green: 0.878, blue: 0.698, alpha: 1).cgColor

        spinner.color = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        titleLabel.text = "Payment Status"
        titleLabel.font = UIFont(name: "Poppins-SemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)

        messageLabel.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        messageLabel.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        messageLabel.numberOfLines = 2

        // Status badge row
        statusBadge.layer.cornerRadius = 8
        statusBadge.layer.borderWidth = 1
        statusLabel.font = UIFont(name: "Poppins-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        let badgeStack = UIStackView(arrangedSubviews: [statusLabel])
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        statusBadge.addSubview(badgeStack)
        NSLayoutConstraint.activate([
            badgeStack.topAnchor.constraint(equalTo: statusBadge.topAnchor, constant: 8),
            badgeStack.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: 12),
            badgeStack.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: -12),
            badgeStack.bottomAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: -8),
        ])

        dueDateLabel.font = UIFont(name: "Poppins-SemiBold", size: 12) ?? .systemFont(ofSize: 12, weight: .semibold)
        dueDateLabel.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)

        let bottomRow = UIStackView(arrangedSubviews: [statusBadge, dueDateLabel])
        bottomRow.axis = .horizontal; bottomRow.spacing = 12; bottomRow.alignment = .center

        payDateLabel.font = UIFont(name: "Poppins-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        payDateLabel.textColor = .systemGreen
        payDateLabel.isHidden = true

        contentStack.axis = .vertical; contentStack.spacing = 8
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(messageLabel)
        contentStack.addArrangedSubview(bottomRow)
        contentStack.addArrangedSubview(payDateLabel)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(spinner)
        addSubview(contentStack)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
        ])

        // Show "No data" state by default
        update(isLoading: false, hasData: false, status: "", billDate: "", paymentDate: "", statusColor: .systemGray, message: "")
    }

    func update(isLoading: Bool, hasData: Bool, status: String, billDate: String, paymentDate: String, statusColor: UIColor, message: String) {
        if isLoading {
            spinner.startAnimating()
            contentStack.isHidden = true
            return
        }
        spinner.stopAnimating()
        contentStack.isHidden = false

        if !hasData {
            messageLabel.text = "No property found. Add or verify a property to see due status."
            statusBadge.isHidden = true
            dueDateLabel.isHidden = true
            payDateLabel.isHidden = true
            return
        }

        messageLabel.text = message
        statusLabel.text = status
        statusLabel.textColor = statusColor
        statusBadge.backgroundColor = statusColor.withAlphaComponent(0.1)
        statusBadge.layer.borderColor = statusColor.cgColor
        statusBadge.isHidden = status.isEmpty
        dueDateLabel.text = billDate.isEmpty ? "" : "Due: \(billDate)"
        dueDateLabel.isHidden = billDate.isEmpty

        if !paymentDate.isEmpty && paymentDate != "-" {
            payDateLabel.text = "Last payment date: \(paymentDate)"
            payDateLabel.isHidden = false
        } else {
            payDateLabel.isHidden = true
        }
    }
}

// MARK: - DashboardBottomBar

final class DashboardBottomBar: UIView {

    var onTapHistory: (() -> Void)?
    var onTapAccount: (() -> Void)?

    private let homeBtn = DashboardTabButton(icon: "house.fill", label: "Home", selected: true)
    private let historyBtn = DashboardTabButton(icon: "receipt.fill", label: "History", selected: false)
    private let accountBtn = DashboardTabButton(icon: "person.fill", label: "Account", selected: false)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .white
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: -2)

        let stack = UIStackView(arrangedSubviews: [homeBtn, historyBtn, accountBtn])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let safePad = UIView()
        safePad.translatesAutoresizingMaskIntoConstraints = false
        addSubview(safePad)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: 56),
            safePad.topAnchor.constraint(equalTo: stack.bottomAnchor),
            safePad.leadingAnchor.constraint(equalTo: leadingAnchor),
            safePad.trailingAnchor.constraint(equalTo: trailingAnchor),
            safePad.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            bottomAnchor.constraint(equalTo: safePad.bottomAnchor),
        ])

        historyBtn.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        accountBtn.addTarget(self, action: #selector(accountTapped), for: .touchUpInside)
    }

    @objc private func historyTapped() { onTapHistory?() }
    @objc private func accountTapped() { onTapAccount?() }
}

// MARK: - DashboardTabButton

final class DashboardTabButton: UIControl {
    private let iconView = UIImageView()
    private let label = UILabel()
    private let iconName: String
    private let labelText: String

    private let orange = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
    private let grey = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)

    init(icon: String, label: String, selected: Bool) {
        self.iconName = icon
        self.labelText = label
        super.init(frame: .zero)
        setup()
        setSelected(selected)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.text = labelText
        label.font = UIFont(name: "Poppins-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .vertical; stack.spacing = 3; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func setSelected(_ on: Bool) {
        let color = on ? orange : grey
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = color
        label.textColor = color
        if on { label.font = UIFont(name: "Poppins-SemiBold", size: 12) ?? .systemFont(ofSize: 12, weight: .semibold) }
        else { label.font = UIFont(name: "Poppins-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium) }
    }
}
