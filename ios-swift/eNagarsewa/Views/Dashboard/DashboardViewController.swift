import UIKit
import Combine

final class DashboardViewController: UIViewController {

    private let viewModel: DashboardViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    // Property card
    private let propertyCard = UIView()
    private let propertyLabel: UILabel = {
        let l = UILabel()
        l.text = "No property selected"
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Quick action grid (2×3)
    private let actionsGrid = UICollectionView(frame: .zero,
        collectionViewLayout: UICollectionViewFlowLayout())

    private let actions: [(title: String, icon: String, action: String)] = [
        ("Pay Tax",             "indianrupeesign.circle",       "payTax"),
        ("Search Property",     "magnifyingglass.circle",       "search"),
        ("Payment History",     "clock.arrow.circlepath",       "payHistory"),
        ("Transactions",        "list.bullet.rectangle",        "txnHistory"),
        ("Apply Grievance",     "exclamationmark.bubble",       "applyGrievance"),
        ("Track Grievance",     "location.magnifyingglass",     "trackGrievance"),
        ("Grievance Status",    "checkmark.seal",               "grievanceStatus"),
        ("My Account",          "person.circle",                "account"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "e-Nagarsewa"
        view.backgroundColor = .appBackground
        setupNavigationBar()
        setupLayout()
        bindViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.onViewAppear()
    }

    // MARK: - Navigation bar

    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .appPrimary
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance  = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .white

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.circle"),
            style: .plain, target: self, action: #selector(accountTapped)
        )
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.pinToEdges(of: view)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        setupPropertyCard()
        setupActionsGrid()
    }

    private func setupPropertyCard() {
        propertyCard.backgroundColor = .appPrimary
        propertyCard.roundCorners(radius: 16)
        propertyCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(propertyCard)
        propertyCard.addSubview(propertyLabel)

        let searchBtn = UIButton(type: .system)
        searchBtn.setTitle("Search Property", for: .normal)
        searchBtn.setTitleColor(.white, for: .normal)
        searchBtn.layer.borderColor = UIColor.white.cgColor
        searchBtn.layer.borderWidth = 1
        searchBtn.layer.cornerRadius = 8
        searchBtn.translatesAutoresizingMaskIntoConstraints = false
        searchBtn.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        propertyCard.addSubview(searchBtn)

        NSLayoutConstraint.activate([
            propertyCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            propertyCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            propertyCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            propertyCard.heightAnchor.constraint(equalToConstant: 120),

            propertyLabel.topAnchor.constraint(equalTo: propertyCard.topAnchor, constant: 16),
            propertyLabel.leadingAnchor.constraint(equalTo: propertyCard.leadingAnchor, constant: 16),
            propertyLabel.trailingAnchor.constraint(equalTo: searchBtn.leadingAnchor, constant: -8),

            searchBtn.trailingAnchor.constraint(equalTo: propertyCard.trailingAnchor, constant: -16),
            searchBtn.centerYAnchor.constraint(equalTo: propertyCard.centerYAnchor),
            searchBtn.widthAnchor.constraint(equalToConstant: 120),
            searchBtn.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func setupActionsGrid() {
        let layout = actionsGrid.collectionViewLayout as! UICollectionViewFlowLayout
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        actionsGrid.backgroundColor = .clear
        actionsGrid.dataSource = self
        actionsGrid.delegate = self
        actionsGrid.register(ActionCell.self, forCellWithReuseIdentifier: "ActionCell")
        actionsGrid.isScrollEnabled = false
        actionsGrid.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionsGrid)

        let gridHeight = CGFloat((actions.count + 1) / 2) * (100 + 12) + 32
        NSLayoutConstraint.activate([
            actionsGrid.topAnchor.constraint(equalTo: propertyCard.bottomAnchor, constant: 8),
            actionsGrid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            actionsGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            actionsGrid.heightAnchor.constraint(equalToConstant: gridHeight),
            actionsGrid.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$selectedProperty.receive(on: DispatchQueue.main).sink { [weak self] prop in
            if let p = prop {
                self?.propertyLabel.text = "\(p.ownerName)\n\(p.address)"
                self?.propertyLabel.textColor = .white
            } else {
                self?.propertyLabel.text = "No property selected"
                self?.propertyLabel.textColor = UIColor.white.withAlphaComponent(0.7)
            }
        }.store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func searchTapped()  { viewModel.didTapSearchProperty() }
    @objc private func accountTapped() { viewModel.didTapAccount() }
}

// MARK: - CollectionView

extension DashboardViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { actions.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "ActionCell", for: ip) as! ActionCell
        cell.configure(title: actions[ip.item].title, icon: actions[ip.item].icon)
        return cell
    }

    func collectionView(_ cv: UICollectionView, layout cvl: UICollectionViewLayout, sizeForItemAt ip: IndexPath) -> CGSize {
        let w = (cv.frame.width - 44) / 2
        return CGSize(width: w, height: 100)
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        switch actions[ip.item].action {
        case "payTax":          viewModel.didTapPayTax()
        case "search":          viewModel.didTapSearchProperty()
        case "payHistory":      viewModel.didTapPaymentHistory()
        case "txnHistory":      viewModel.didTapTransactionHistory()
        case "applyGrievance":  viewModel.didTapApplyGrievance()
        case "trackGrievance":  viewModel.didTapTrackGrievance()
        case "grievanceStatus": viewModel.didTapGrievanceStatus()
        case "account":         viewModel.didTapAccount()
        default: break
        }
    }
}

// MARK: - Action Cell

final class ActionCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .appSurface
        contentView.roundCorners(radius: 12)
        contentView.addShadow()

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .appPrimary
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .vertical; stack.spacing = 8; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        stack.center(in: contentView)
        iconView.setSize(width: 36, height: 36)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, icon: String) {
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title
    }
}
