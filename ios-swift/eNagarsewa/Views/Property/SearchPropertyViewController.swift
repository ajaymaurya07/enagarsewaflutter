import UIKit
import Combine

final class SearchPropertyViewController: UIViewController {

    private let viewModel: SearchPropertyViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: SearchPropertyViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private lazy var ulbPicker     = makePicker(placeholder: "Select ULB")
    private lazy var zonePicker    = makePicker(placeholder: "Select Zone")
    private lazy var wardPicker    = makePicker(placeholder: "Select Ward")
    private lazy var mohallaPicker = makePicker(placeholder: "Select Mohalla")
    private lazy var ownerField    = UITextField.styledTextField(placeholder: "Owner name")
    private lazy var propertyIdField = UITextField.styledTextField(placeholder: "Property ID")
    private lazy var houseNoField  = UITextField.styledTextField(placeholder: "House number")
    private lazy var mobileField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "Mobile number")
        tf.keyboardType = .phonePad; return tf
    }()
    private lazy var searchButton  = UIButton.primaryButton(title: "Search")

    private let errorLabel: UILabel = {
        let l = UILabel(); l.textColor = .appError; l.numberOfLines = 0
        l.isHidden = true; l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium); ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false; return ai
    }()

    // Picker data sources
    private var ulbItems: [UlbData] = []
    private var zoneItems: [ZoneData] = []
    private var wardItems: [WardData] = []
    private var mohallaItems: [MohallaData] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search Property"
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
        setupActions()
        viewModel.onViewAppear()
    }

    private func setupLayout() {
        let scroll = UIScrollView()
        let content = UIView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll); scroll.addSubview(content)
        scroll.pinToEdges(of: view)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        let sectionLabel = UILabel()
        sectionLabel.text = "Location Filters"
        sectionLabel.font = .boldSystemFont(ofSize: 14)
        sectionLabel.textColor = .secondaryLabel
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        let sectionLabel2 = UILabel()
        sectionLabel2.text = "Search Criteria"
        sectionLabel2.font = .boldSystemFont(ofSize: 14)
        sectionLabel2.textColor = .secondaryLabel
        sectionLabel2.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [
            sectionLabel, ulbPicker, zonePicker, wardPicker, mohallaPicker,
            sectionLabel2, ownerField, propertyIdField, houseNoField, mobileField,
            errorLabel, searchButton, activityIndicator
        ])
        stack.axis = .vertical; stack.spacing = 14; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            searchButton.heightAnchor.constraint(equalToConstant: 50),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
        ])
    }

    private func bindViewModel() {
        viewModel.$ulbs.receive(on: DispatchQueue.main).sink { [weak self] ulbs in
            self?.ulbItems = ulbs
        }.store(in: &cancellables)

        viewModel.$zones.receive(on: DispatchQueue.main).sink { [weak self] zones in
            self?.zoneItems = zones
            self?.zonePicker.isEnabled = !zones.isEmpty
        }.store(in: &cancellables)

        viewModel.$wards.receive(on: DispatchQueue.main).sink { [weak self] wards in
            self?.wardItems = wards
            self?.wardPicker.isEnabled = !wards.isEmpty
        }.store(in: &cancellables)

        viewModel.$mohalles.receive(on: DispatchQueue.main).sink { [weak self] mohalles in
            self?.mohallaItems = mohalles
            self?.mohallaPicker.isEnabled = !mohalles.isEmpty
        }.store(in: &cancellables)

        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in
            l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
            self?.searchButton.isEnabled = !l
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            self?.errorLabel.text = msg; self?.errorLabel.isHidden = msg == nil
        }.store(in: &cancellables)
    }

    private func setupActions() {
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        ulbPicker.addTarget(self, action: #selector(showUlbPicker), for: .touchUpInside)
        zonePicker.addTarget(self, action: #selector(showZonePicker), for: .touchUpInside)
        wardPicker.addTarget(self, action: #selector(showWardPicker), for: .touchUpInside)
        mohallaPicker.addTarget(self, action: #selector(showMohallaPicker), for: .touchUpInside)
    }

    @objc private func searchTapped() {
        view.endEditing(true)
        viewModel.ownerName    = ownerField.text ?? ""
        viewModel.propertyId   = propertyIdField.text ?? ""
        viewModel.houseNo      = houseNoField.text ?? ""
        viewModel.mobileNumber = mobileField.text ?? ""
        viewModel.search()
    }

    @objc private func showUlbPicker()     { showPicker(items: ulbItems.map(\.ulbName))    { [weak self] idx in self?.viewModel.selectUlb(self!.ulbItems[idx]); self?.ulbPicker.setTitle(self?.ulbItems[idx].ulbName, for: .normal) } }
    @objc private func showZonePicker()    { showPicker(items: zoneItems.map(\.zoneName))  { [weak self] idx in self?.viewModel.selectZone(self!.zoneItems[idx]); self?.zonePicker.setTitle(self?.zoneItems[idx].zoneName, for: .normal) } }
    @objc private func showWardPicker()    { showPicker(items: wardItems.map(\.wardName))  { [weak self] idx in self?.viewModel.selectWard(self!.wardItems[idx]); self?.wardPicker.setTitle(self?.wardItems[idx].wardName, for: .normal) } }
    @objc private func showMohallaPicker() { showPicker(items: mohallaItems.map(\.mohallaName)) { [weak self] idx in self?.viewModel.selectedMohalla = self?.mohallaItems[idx]; self?.mohallaPicker.setTitle(self?.mohallaItems[idx].mohallaName, for: .normal) } }

    private func showPicker(items: [String], onSelect: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: "Select", message: nil, preferredStyle: .actionSheet)
        for (i, item) in items.enumerated() {
            alert.addAction(UIAlertAction(title: item, style: .default) { _ in onSelect(i) })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func makePicker(placeholder: String) -> UIButton {
        var config = UIButton.Configuration.bordered()
        config.title = placeholder
        let b = UIButton(configuration: config)
        b.contentHorizontalAlignment = .left
        b.translatesAutoresizingMaskIntoConstraints = false
        b.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return b
    }
}
