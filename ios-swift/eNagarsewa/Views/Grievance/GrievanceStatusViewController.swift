import UIKit
import Combine

final class GrievanceStatusViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let viewModel: GrievanceStatusViewModel
    private var cancellables = Set<AnyCancellable>()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    init(viewModel: GrievanceStatusViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Grievances"
        view.backgroundColor = .appBackground
        tableView.dataSource = self; tableView.delegate = self
        tableView.register(GrievanceCell.self, forCellReuseIdentifier: "GrievanceCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true; activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView); view.addSubview(activityIndicator)
        tableView.pinToEdges(of: view); activityIndicator.center(in: view)

        viewModel.$grievances.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.tableView.reloadData() }.store(in: &cancellables)
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating() }.store(in: &cancellables)
        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in if let msg { self?.showAlert(message: msg) } }.store(in: &cancellables)
        viewModel.onViewAppear()
    }

    func tableView(_ tv: UITableView, numberOfRowsInSection s: Int) -> Int { viewModel.grievances.count }
    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "GrievanceCell", for: ip) as! GrievanceCell
        cell.configure(with: viewModel.grievances[ip.row]); return cell
    }
    func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        viewModel.didSelect(viewModel.grievances[ip.row])
    }
    func tableView(_ tv: UITableView, heightForRowAt ip: IndexPath) -> CGFloat { 90 }
}

final class GrievanceCell: UITableViewCell {
    private let noLabel      = UILabel()
    private let categoryLabel = UILabel()
    private let statusLabel  = UILabel()
    private let dateLabel    = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        noLabel.font      = .boldSystemFont(ofSize: 14)
        categoryLabel.font = .systemFont(ofSize: 13); categoryLabel.textColor = .secondaryLabel
        statusLabel.font  = .systemFont(ofSize: 12, weight: .semibold)
        dateLabel.font    = .systemFont(ofSize: 11); dateLabel.textColor = .tertiaryLabel

        let left  = UIStackView(arrangedSubviews: [noLabel, categoryLabel, dateLabel]); left.axis = .vertical; left.spacing = 3
        let right = UIStackView(arrangedSubviews: [statusLabel]); right.axis = .vertical; right.alignment = .trailing
        let h = UIStackView(arrangedSubviews: [left, right]); h.distribution = .equalSpacing; h.alignment = .center
        h.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(h)
        NSLayoutConstraint.activate([h.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12), h.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16), h.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16), h.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with g: GrievanceData) {
        noLabel.text        = g.grievanceNo ?? g.grievanceId
        categoryLabel.text  = "\(g.serviceName ?? "") - \(g.subCategoryName ?? "")"
        dateLabel.text      = g.registrationDate ?? "-"
        statusLabel.text    = g.status ?? "-"
        let s = g.status?.lowercased() ?? ""
        statusLabel.textColor = s.contains("close") || s.contains("resolve") ? .appSuccess : s.contains("reject") ? .appError : .appWarning
    }
}
