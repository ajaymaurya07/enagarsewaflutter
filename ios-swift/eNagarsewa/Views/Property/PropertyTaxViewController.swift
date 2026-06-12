import UIKit
import Combine

// MARK: - PropertyTaxViewController  (matches Flutter's PropertyTaxScreen — list of saved properties)

final class PropertyTaxViewController: UIViewController {

    private let viewModel: PropertyTaxViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: PropertyTaxViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let emptyView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavBar()
        setupLayout()
        bindViewModel()
        viewModel.loadProperties()
    }

    // MARK: - Nav bar

    private func setupNavBar() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let backBtn = UIButton(type: .system)
        backBtn.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        backBtn.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        backBtn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        let titleL = UILabel()
        titleL.text = "My Properties"
        titleL.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        titleL.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        titleL.translatesAutoresizingMaskIntoConstraints = false

        let helpBtn = UIButton(type: .system)
        helpBtn.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        helpBtn.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        helpBtn.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(backBtn)
        container.addSubview(titleL)
        container.addSubview(helpBtn)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 56),
            backBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            backBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: 36),
            backBtn.heightAnchor.constraint(equalToConstant: 36),
            titleL.leadingAnchor.constraint(equalTo: backBtn.trailingAnchor, constant: 4),
            titleL.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            helpBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            helpBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            helpBtn.widthAnchor.constraint(equalToConstant: 40),
            helpBtn.heightAnchor.constraint(equalToConstant: 40),
        ])

        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ])
        setupContentBelow(container)
    }

    private func setupContentBelow(_ navBar: UIView) {
        // Spinner
        spinner.color = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        // Scroll + cards
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Empty state
        emptyView.isHidden = true
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)
        buildEmptyState()

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
            emptyView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func buildEmptyState() {
        let iconCircle = UIView()
        iconCircle.backgroundColor = .white
        iconCircle.layer.cornerRadius = 56
        iconCircle.layer.shadowColor = UIColor.black.cgColor
        iconCircle.layer.shadowOpacity = 0.03
        iconCircle.layer.shadowRadius = 20
        iconCircle.widthAnchor.constraint(equalToConstant: 112).isActive = true
        iconCircle.heightAnchor.constraint(equalToConstant: 112).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: "house.circle"))
        iconView.tintColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
        ])

        let title = UILabel()
        title.text = "No properties added yet"
        title.font = UIFont(name: "Poppins-SemiBold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        title.textAlignment = .center

        let sub = UILabel()
        sub.text = "Your verified properties will appear here for quick access."
        sub.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        sub.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        sub.textAlignment = .center
        sub.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconCircle, title, sub])
        stack.axis = .vertical; stack.spacing = 24; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            if loading { self?.spinner.startAnimating() } else { self?.spinner.stopAnimating() }
            self?.scrollView.isHidden = loading
            self?.emptyView.isHidden = true
        }.store(in: &cancellables)

        viewModel.$properties.receive(on: DispatchQueue.main).sink { [weak self] properties in
            guard let self else { return }
            self.contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            if properties.isEmpty {
                self.scrollView.isHidden = true
                self.emptyView.isHidden = false
            } else {
                self.scrollView.isHidden = false
                self.emptyView.isHidden = true
                properties.forEach { prop in
                    self.contentStack.addArrangedSubview(self.buildPropertyCard(prop))
                }
            }
        }.store(in: &cancellables)
    }

    // MARK: - Property card

    private func buildPropertyCard(_ property: PropertyEntity) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 20
        card.clipsToBounds = false
        card.addCardShadow()
        card.isUserInteractionEnabled = true

        // Header: icon circle + PID + chevron
        let iconCircle = UIView()
        iconCircle.backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.898, alpha: 1)
        iconCircle.layer.cornerRadius = 12
        iconCircle.widthAnchor.constraint(equalToConstant: 42).isActive = true
        iconCircle.heightAnchor.constraint(equalToConstant: 42).isActive = true
        let cityIcon = UIImageView(image: UIImage(systemName: "building.columns.circle"))
        cityIcon.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        cityIcon.contentMode = .scaleAspectFit
        cityIcon.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(cityIcon)
        NSLayoutConstraint.activate([
            cityIcon.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            cityIcon.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            cityIcon.widthAnchor.constraint(equalToConstant: 22),
            cityIcon.heightAnchor.constraint(equalToConstant: 22),
        ])

        let pidLabel = UILabel()
        pidLabel.text = "PID: \(property.propertyId)"
        pidLabel.font = UIFont(name: "Poppins-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
        pidLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let headerRow = UIStackView(arrangedSubviews: [iconCircle, pidLabel, chevron])
        headerRow.axis = .horizontal; headerRow.spacing = 12; headerRow.alignment = .center

        // Divider
        let divider = UIView()
        divider.backgroundColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        divider.heightAnchor.constraint(equalToConstant: 0.8).isActive = true

        // Detail rows
        let detailsStack = UIStackView(arrangedSubviews: [
            makeDetailRow("Owner", property.ownerName),
            makeDetailRow("Ward", property.ward),
            makeDetailRow("Mohalla", property.mohalla),
            makeDetailRow("Mobile", property.phoneNumber),
        ])
        detailsStack.axis = .vertical; detailsStack.spacing = 12

        let cardInner = UIStackView(arrangedSubviews: [headerRow, divider, detailsStack])
        cardInner.axis = .vertical; cardInner.spacing = 0
        cardInner.setCustomSpacing(16, after: headerRow)
        cardInner.setCustomSpacing(20, after: divider)
        cardInner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardInner)
        NSLayoutConstraint.activate([
            cardInner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            cardInner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardInner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            cardInner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        let tap = ClosureTapGesture { [weak self] in
            self?.viewModel.didSelectProperty(property)
        }
        card.addGestureRecognizer(tap)
        return card
    }

    private func makeDetailRow(_ label: String, _ value: String) -> UIView {
        let keyL = UILabel()
        keyL.text = "\(label):"
        keyL.font = UIFont(name: "Poppins-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        keyL.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        keyL.setContentHuggingPriority(.required, for: .horizontal)
        keyL.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let valL = UILabel()
        valL.text = value.isEmpty ? "N/A" : value
        valL.font = UIFont(name: "Poppins-SemiBold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold)
        valL.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        valL.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [keyL, valL])
        row.axis = .horizontal; row.spacing = 8; row.alignment = .top
        return row
    }

    // MARK: - Actions

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - ClosureTapGesture (utility)

final class ClosureTapGesture: UITapGestureRecognizer {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(fire))
    }
    @objc private func fire() { action() }
}

// MARK: - PropertyBillDetailsViewController (Flutter's PaymentDetailsScreen)

final class PropertyBillDetailsViewController: UIViewController {

    private let viewModel: PropertyTaxDetailViewModel
    private var cancellables = Set<AnyCancellable>()
    private var propertyDetailsExpanded = false

    init(viewModel: PropertyTaxDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI refs
    private var navBarView = UIView()
    private let scrollView = UIScrollView()
    private let mainStack  = UIStackView()
    private let spinner    = UIActivityIndicatorView(style: .large)
    private let errorView  = UIView()
    private weak var errorLabel: UILabel?
    private weak var propDetailsContent: UIView?
    private weak var propChevron: UIImageView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavBar()
        setupLayout()
        bindViewModel()
        viewModel.onViewAppear()
    }

    // MARK: - Nav bar

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

        let helpBtn = UIButton(type: .system)
        helpBtn.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        helpBtn.tintColor = .appPrimary
        helpBtn.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(backBtn); bar.addSubview(titleStack); bar.addSubview(helpBtn)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 64),
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

        errorView.isHidden = true
        errorView.translatesAutoresizingMaskIntoConstraints = false
        buildErrorView()
        view.addSubview(errorView)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.isHidden = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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

            errorView.topAnchor.constraint(equalTo: navBarView.bottomAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

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

    private func buildErrorView() {
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.circle"))
        icon.tintColor = .systemRed; icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 60).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let lbl = UILabel()
        lbl.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        lbl.textColor = .appCardText; lbl.textAlignment = .center; lbl.numberOfLines = 0
        errorLabel = lbl

        let btn = UIButton.primaryButton(title: "Retry")
        btn.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        btn.widthAnchor.constraint(equalToConstant: 160).isActive = true

        let stack = UIStackView(arrangedSubviews: [icon, lbl, btn])
        stack.axis = .vertical; stack.spacing = 20; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        errorView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -24),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            if loading {
                self?.spinner.startAnimating()
                self?.scrollView.isHidden = true
                self?.errorView.isHidden = true
            } else {
                self?.spinner.stopAnimating()
            }
        }.store(in: &cancellables)

        viewModel.$propertyDetails.receive(on: DispatchQueue.main).sink { [weak self] details in
            guard let details else { return }
            self?.errorView.isHidden = true
            self?.scrollView.isHidden = false
            self?.populateContent(details: details)
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            guard let msg else { return }
            self?.scrollView.isHidden = true
            self?.errorView.isHidden = false
            self?.errorLabel?.text = msg
        }.store(in: &cancellables)
    }

    // MARK: - Content

    private func populateContent(details: PropertyDetailsData) {
        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        propertyDetailsExpanded = false

        let bill  = details.billDetails
        let prop  = details.propertyDetailsInfo
        let owner = details.ownerDetails

        let advancePay = [bill?.houseTaxAdvance, bill?.waterTaxAdvance, bill?.sewerTaxAdvance,
                          bill?.otherTaxAdvance, bill?.waterChargeAdvance]
            .compactMap { Double($0 ?? "0") }.reduce(0, +)
        let advStr = String(format: "%.2f", advancePay)

        // 1. Tax Summary card
        let taxCard = buildTaxSummaryCard(bill: bill, arvValue: viewModel.property.arvValue, advanceTotal: advStr)
        mainStack.addArrangedSubview(taxCard)
        mainStack.setCustomSpacing(20, after: taxCard)

        // 2. Pay Your Tax Online button
        let payBtn = buildPayButton()
        mainStack.addArrangedSubview(payBtn)
        mainStack.setCustomSpacing(12, after: payBtn)

        // 3. Print + Payment History row
        let secRow = buildSecondaryButtonsRow()
        mainStack.addArrangedSubview(secRow)
        mainStack.setCustomSpacing(20, after: secRow)

        // 4. Expandable Property Details card
        mainStack.addArrangedSubview(buildPropertyDetailsCard(prop: prop, owner: owner))
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
                       ("Total ARV", arvValue.isEmpty ? nil : arvValue)] {
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

        let netAmt = bill?.netPayble ?? bill?.netPayable ?? "0"
        let netBox = buildNetPayableBox(netAmt)

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
        let printBtn   = makeSecondaryButton("Print Property",    icon: "printer",     action: #selector(printTapped))
        let historyBtn = makeSecondaryButton("Payment History",   icon: "creditcard",  action: #selector(historyTapped))
        let row = UIStackView(arrangedSubviews: [printBtn, historyBtn])
        row.axis = .horizontal; row.spacing = 12; row.distribution = .fillEqually
        return row
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

        for (k, v) in [("Property/House ID",   viewModel.property.propertyId),
                       ("Zone Name",           prop?.zoneName ?? "N/A"),
                       ("Ward Name",           prop?.wardName ?? "N/A"),
                       ("Mohalla Name",        prop?.mohallaName ?? "N/A"),
                       ("House No.",           prop?.houseNo ?? "N/A"),
                       ("Property Address",    prop?.address ?? "N/A"),
                       ("Owner Name",          owner?.ownerName ?? "N/A"),
                       ("Owner Mobile",        owner?.mobileNo ?? "N/A"),
                       ("Father Name",         owner?.fatherName ?? "N/A")] {
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

    // MARK: - Actions

    @objc private func backTapped()   { navigationController?.popViewController(animated: true) }
    @objc private func retryTapped()  { viewModel.onViewAppear() }
    @objc private func historyTapped(){ viewModel.didTapPaymentHistory() }

    @objc private func togglePropertyDetails() {
        propertyDetailsExpanded.toggle()
        propDetailsContent?.isHidden = !propertyDetailsExpanded
        propChevron?.image = UIImage(systemName: propertyDetailsExpanded ? "chevron.up" : "chevron.down")
    }

    @objc private func payTapped() {
        let mobile = viewModel.ownerMobile
        guard !mobile.isEmpty else {
            ENSSnackbar.show(in: view, message: "Mobile number not available for OTP", isError: true)
            return
        }
        sendOtpAndShowSheet(mobileNo: mobile)
    }

    @objc private func printTapped() {
        guard let details = viewModel.propertyDetails else { return }
        sharePrintableDetails(details)
    }

    // MARK: - OTP flow

    private func sendOtpAndShowSheet(mobileNo: String) {
        spinner.startAnimating()
        scrollView.isUserInteractionEnabled = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.spinner.stopAnimating()
                self.scrollView.isUserInteractionEnabled = true
            }
            do {
                try await self.viewModel.sendPaymentOtp()
                self.showOtpSheet(mobileNo: mobileNo)
            } catch {
                ENSSnackbar.show(in: self.view, message: error.localizedDescription, isError: true)
            }
        }
    }

    private func showOtpSheet(mobileNo: String) {
        let sheet = OTPBottomSheetVC()
        sheet.mobileNo = mobileNo
        sheet.onVerify = { [weak self, weak sheet] otp in
            sheet?.setVerifying(true)
            Task { @MainActor [weak self, weak sheet] in
                guard let self else { return }
                do {
                    try await self.viewModel.verifyPaymentOtp(otp)
                    sheet?.dismiss(animated: true) { self.showPaymentMethodSheet() }
                } catch {
                    sheet?.setVerifying(false)
                    sheet?.showError(error.localizedDescription)
                }
            }
        }
        if let presenter = sheet.sheetPresentationController {
            presenter.detents = [.medium()]
            presenter.prefersGrabberVisible = true
        }
        present(sheet, animated: true)
    }

    // MARK: - Payment method selection

    private func showPaymentMethodSheet() {
        let sheetVC = UIViewController()
        sheetVC.view.backgroundColor = .white

        let titleL = UILabel()
        titleL.text = "Select Payment Gateway"
        titleL.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        titleL.textColor = .appCardText

        let payuCard = buildPaymentOptionCard(
            title: "Pay with PayU", subtitle: "Safe & Secure", icon: "creditcard.fill"
        ) { [weak self, weak sheetVC] in
            sheetVC?.dismiss(animated: true) { self?.viewModel.onPayTax?() }
        }

        let stack = UIStackView(arrangedSubviews: [titleL, payuCard])
        stack.axis = .vertical; stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        sheetVC.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: sheetVC.view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: sheetVC.view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: sheetVC.view.trailingAnchor, constant: -24),
        ])

        if let presenter = sheetVC.sheetPresentationController {
            presenter.detents = [.medium()]
            presenter.prefersGrabberVisible = true
        }
        present(sheetVC, animated: true)
    }

    private func buildPaymentOptionCard(title: String, subtitle: String, icon: String,
                                        onTap: @escaping () -> Void) -> UIView {
        let card = UIView()
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1).cgColor
        card.layer.cornerRadius = 12
        card.isUserInteractionEnabled = true

        let iconImg = UIImageView(image: UIImage(systemName: icon))
        iconImg.tintColor = .appPrimary; iconImg.contentMode = .scaleAspectFit
        iconImg.widthAnchor.constraint(equalToConstant: 28).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let titleL = UILabel()
        titleL.text = title
        titleL.font = UIFont(name: "Poppins-Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
        titleL.textColor = .appCardText

        let subL = UILabel()
        subL.text = subtitle
        subL.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        subL.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)

        let textStack = UIStackView(arrangedSubviews: [titleL, subL])
        textStack.axis = .vertical; textStack.spacing = 2

        let arrowImg = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrowImg.tintColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        arrowImg.contentMode = .scaleAspectFit
        arrowImg.widthAnchor.constraint(equalToConstant: 16).isActive = true

        let row = UIStackView(arrangedSubviews: [iconImg, textStack, arrowImg])
        row.axis = .horizontal; row.spacing = 16; row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        card.addGestureRecognizer(ClosureTapGesture(onTap))
        return card
    }

    // MARK: - Print / Share

    private func sharePrintableDetails(_ details: PropertyDetailsData) {
        let bill  = details.billDetails
        let prop  = details.propertyDetailsInfo
        let owner = details.ownerDetails
        var lines = ["Property Tax Details",
                     "Property ID: \(viewModel.property.propertyId)", "",
                     "--- Property Information ---",
                     "Zone: \(prop?.zoneName ?? "N/A")",
                     "Ward: \(prop?.wardName ?? "N/A")",
                     "Mohalla: \(prop?.mohallaName ?? "N/A")",
                     "House No: \(prop?.houseNo ?? "N/A")",
                     "Address: \(prop?.address ?? "N/A")", "",
                     "--- Owner Information ---",
                     "Owner: \(owner?.ownerName ?? "N/A")",
                     "Father: \(owner?.fatherName ?? "N/A")",
                     "Mobile: \(owner?.mobileNo ?? "N/A")", "",
                     "--- Tax Summary ---",
                     "Bill Date: \(bill?.billDate ?? "N/A")",
                     "Bill No: \(bill?.billNo ?? "N/A")",
                     "Financial Year: \(bill?.finYear ?? "N/A")",
                     "House Tax Net: \(bill?.houseTaxNetAmount ?? "0")",
                     "Water Tax Net: \(bill?.waterTaxNetAmount ?? "0")",
                     "Sewer Tax Net: \(bill?.sewerTaxNetAmount ?? "0")",
                     "Other Tax Net: \(bill?.othertaxNetAmount ?? "0")",
                     "Water Charge Net: \(bill?.waterChargeNetAmount ?? "0")",
                     "Net Demand: \(bill?.netDemand ?? "0")",
                     "Net Payable: Rs. \(bill?.netPayble ?? bill?.netPayable ?? "0")"]
        let av = UIActivityViewController(activityItems: [lines.joined(separator: "\n")],
                                          applicationActivities: nil)
        av.popoverPresentationController?.sourceView = view
        present(av, animated: true)
    }
}

// MARK: - OTPBottomSheetVC

private final class OTPBottomSheetVC: UIViewController {

    var mobileNo: String = ""
    var onVerify: ((String) -> Void)?

    private let otpField = ENSInputField(placeholder: "Enter OTP", icon: "lock.fill", keyboardType: .numberPad)
    private weak var errorLabel: UILabel?
    private weak var verifyBtn: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        otpField.textField.becomeFirstResponder()
    }

    private func buildUI() {
        let handle = UIView()
        handle.backgroundColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        handle.layer.cornerRadius = 2
        handle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(handle)

        let titleL = UILabel()
        titleL.text = "Verification Required"
        titleL.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        titleL.textColor = .appCardText

        let subL = UILabel()
        subL.text = "Enter the OTP sent to \(mobileNo) to proceed with payment."
        subL.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        subL.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        subL.numberOfLines = 0

        let errL = UILabel()
        errL.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        errL.textColor = .systemRed; errL.numberOfLines = 0; errL.isHidden = true
        errorLabel = errL

        let otpLbl = UILabel.fieldLabel("Enter OTP")

        let btn = UIButton.primaryButton(title: "Verify & Proceed")
        btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        btn.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        verifyBtn = btn

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.titleLabel?.font = UIFont(name: "Poppins-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        cancelBtn.setTitleColor(UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1), for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let stack = UIStackView(arrangedSubviews: [titleL, subL, errL, otpLbl, otpField, btn, cancelBtn])
        stack.axis = .vertical; stack.spacing = 0
        stack.setCustomSpacing(4,  after: titleL)
        stack.setCustomSpacing(16, after: subL)
        stack.setCustomSpacing(8,  after: errL)
        stack.setCustomSpacing(8,  after: otpLbl)
        stack.setCustomSpacing(24, after: otpField)
        stack.setCustomSpacing(12, after: btn)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 40),
            handle.heightAnchor.constraint(equalToConstant: 4),
            stack.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    @objc private func verifyTapped() {
        let otp = otpField.textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !otp.isEmpty else { showError("Please enter OTP"); return }
        guard otp.count >= 4  else { showError("Please enter a valid OTP"); return }
        onVerify?(otp)
    }

    @objc private func cancelTapped() { dismiss(animated: true) }

    func showError(_ msg: String) { errorLabel?.text = msg; errorLabel?.isHidden = false }
    func setVerifying(_ on: Bool)  { verifyBtn?.setLoading(on) }
}
