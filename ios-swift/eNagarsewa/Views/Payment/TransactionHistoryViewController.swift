import UIKit
import Combine

final class TransactionHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let viewModel: TransactionHistoryViewModel
    weak var coordinator: MainCoordinator?
    private var cancellables = Set<AnyCancellable>()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    init(viewModel: TransactionHistoryViewModel, coordinator: MainCoordinator) {
        self.viewModel   = viewModel
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transaction History"
        view.backgroundColor = .appBackground
        tableView.dataSource = self; tableView.delegate = self
        tableView.register(TransactionCell.self, forCellReuseIdentifier: "TransactionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(tableView); view.addSubview(activityIndicator)
        tableView.pinToEdges(of: view); activityIndicator.center(in: view)

        viewModel.$transactions.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.tableView.reloadData() }.store(in: &cancellables)
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating() }.store(in: &cancellables)
        viewModel.onViewAppear()
    }

    func tableView(_ tv: UITableView, numberOfRowsInSection s: Int) -> Int { viewModel.transactions.count }
    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "TransactionCell", for: ip) as! TransactionCell
        cell.configure(with: viewModel.transactions[ip.row]); return cell
    }
    func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        coordinator?.showTransactionDetails(viewModel.transactions[ip.row])
    }
    func tableView(_ tv: UITableView, heightForRowAt ip: IndexPath) -> CGFloat { 80 }
}
