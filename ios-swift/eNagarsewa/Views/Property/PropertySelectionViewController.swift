import UIKit
import Combine

final class PropertySelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let viewModel: PropertySelectionViewModel
    private var cancellables = Set<AnyCancellable>()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(viewModel: PropertySelectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Property (\(viewModel.properties.count) found)"
        view.backgroundColor = .appBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PropertyCell.self, forCellReuseIdentifier: "PropertyCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.pinToEdges(of: view)
    }

    func tableView(_ tv: UITableView, numberOfRowsInSection s: Int) -> Int { viewModel.properties.count }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "PropertyCell", for: ip) as! PropertyCell
        cell.configure(with: viewModel.properties[ip.row])
        return cell
    }

    func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        viewModel.selectProperty(at: ip.row)
    }

    func tableView(_ tv: UITableView, heightForRowAt ip: IndexPath) -> CGFloat { 80 }
}

// MARK: - ViewModel

@MainActor
final class PropertySelectionViewModel: ObservableObject {

    let properties: [PropertyData]
    weak var coordinator: PropertyCoordinator?
    private let appState = AppState.shared

    init(properties: [PropertyData], coordinator: PropertyCoordinator) {
        self.properties  = properties
        self.coordinator = coordinator
    }

    func selectProperty(at index: Int) {
        let p = properties[index]
        let entity = PropertyEntity(
            propertyId: p.propertyId, ownerName: p.ownerName,
            ward: "", mohalla: "", phoneNumber: "", email: "",
            userType: UserDefaultsService.shared.userType ?? "",
            ulbId: UserDefaultsService.shared.selectedUlbId ?? "",
            arvValue: p.totalArv ?? "", userId: "",
            fatherName: "", address: p.address
        )
        appState.selectedProperty = entity
        coordinator?.propertySelected()
    }
}

// MARK: - PropertyCell

final class PropertyCell: UITableViewCell {

    private let ownerLabel   = UILabel()
    private let addressLabel = UILabel()
    private let idLabel      = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        ownerLabel.font = .boldSystemFont(ofSize: 15)
        addressLabel.font = .systemFont(ofSize: 13); addressLabel.textColor = .secondaryLabel; addressLabel.numberOfLines = 2
        idLabel.font = .systemFont(ofSize: 12); idLabel.textColor = .tertiaryLabel

        let stack = UIStackView(arrangedSubviews: [ownerLabel, addressLabel, idLabel])
        stack.axis = .vertical; stack.spacing = 4; stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with property: PropertyData) {
        ownerLabel.text   = property.ownerName
        addressLabel.text = property.address
        idLabel.text      = "ID: \(property.propertyId)"
    }
}
