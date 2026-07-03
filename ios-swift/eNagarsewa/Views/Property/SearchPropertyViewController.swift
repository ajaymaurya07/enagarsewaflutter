import UIKit
import Combine

// MARK: - SearchPropertyViewController

final class SearchPropertyViewController: UIViewController {

    private let viewModel: SearchPropertyViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: SearchPropertyViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Mode chip buttons
    private var chipButtons: [String: UIButton] = [:]
    private let modes = ["By Owner", "By Property ID", "By House No", "By Location", "By Mobile No"]

    // Card
    private let formCard = UIView()

    // ULB
    private lazy var ulbDropdown = DropdownField()

    // Error label
    private let errorLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        l.textColor = UIColor(red: 0.80, green: 0.11, blue: 0.11, alpha: 1)
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    // Form body (rebuilt on mode change)
    private let formBodyContainer = UIView()

    // Search button
    private lazy var searchButton: UIButton = {
        let b = UIButton.primaryButton(title: "Search")
        return b
    }()

    // Refs kept for the first-run tour guide (see lib/tour_guides/search_property_tour.dart)
    private weak var modeChipsContainerView: UIView?
    private var didPresentTour = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        bindViewModel()
        viewModel.onViewAppear()
        updateModeChips()
        rebuildFormBody()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentTourIfNeeded()
    }

    // MARK: - Layout

    private func setupLayout() {
        // Scroll
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Nav bar row
        let navRow = makeNavBar()

        // Mode chips
        let chipsContainer = makeModeChipsView()
        modeChipsContainerView = chipsContainer

        // Form card
        formCard.backgroundColor = .white
        formCard.layer.cornerRadius = 20
        formCard.layer.shadowColor = UIColor.black.cgColor
        formCard.layer.shadowOpacity = 0.06
        formCard.layer.shadowRadius = 10
        formCard.layer.shadowOffset = CGSize(width: 0, height: 8)
        formCard.translatesAutoresizingMaskIntoConstraints = false

        // ULB label + dropdown
        let ulbLabel = makeFieldLabel("Select ULB")
        ulbDropdown.placeholder = "Choose ULB"
        ulbDropdown.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        formBodyContainer.translatesAutoresizingMaskIntoConstraints = false

        searchButton.translatesAutoresizingMaskIntoConstraints = false
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)

        // Tap ULB
        ulbDropdown.addTarget(self, action: #selector(ulbTapped), for: .touchUpInside)

        // Card inner stack
        let cardStack = UIStackView(arrangedSubviews: [
            ulbLabel, ulbDropdown, errorLabel, formBodyContainer, searchButton
        ])
        cardStack.axis = .vertical
        cardStack.spacing = 8
        cardStack.setCustomSpacing(16, after: ulbDropdown)
        cardStack.setCustomSpacing(16, after: errorLabel)
        cardStack.setCustomSpacing(28, after: formBodyContainer)
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        formCard.addSubview(cardStack)

        // Main content stack
        let mainStack = UIStackView(arrangedSubviews: [navRow, chipsContainer, formCard])
        mainStack.axis = .vertical
        mainStack.spacing = 0
        mainStack.setCustomSpacing(20, after: chipsContainer)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            // Card inner
            cardStack.topAnchor.constraint(equalTo: formCard.topAnchor, constant: 20),
            cardStack.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 20),
            cardStack.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -20),
            cardStack.bottomAnchor.constraint(equalTo: formCard.bottomAnchor, constant: -20),
            ulbDropdown.heightAnchor.constraint(equalToConstant: 48),
            searchButton.heightAnchor.constraint(equalToConstant: 52),
            // Main
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
        ])
    }

    private func makeNavBar() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Search Property"
        title.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        title.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        title.translatesAutoresizingMaskIntoConstraints = false

        let helpBtn = UIButton(type: .system)
        helpBtn.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        helpBtn.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        helpBtn.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(title)
        container.addSubview(helpBtn)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 52),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            helpBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            helpBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            helpBtn.widthAnchor.constraint(equalToConstant: 40),
            helpBtn.heightAnchor.constraint(equalToConstant: 40),
        ])
        return container
    }

    private func makeModeChipsView() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Row 1: By Owner | By Property ID | By House No
        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.spacing = 6
        row1.distribution = .fillEqually
        row1.translatesAutoresizingMaskIntoConstraints = false

        for mode in ["By Owner", "By Property ID", "By House No"] {
            row1.addArrangedSubview(makeChipButton(mode))
        }

        // Row 2: spacer | By Location | By Mobile No | spacer
        let row2 = UIStackView()
        row2.axis = .horizontal
        row2.spacing = 6
        row2.translatesAutoresizingMaskIntoConstraints = false

        let spacer1 = UIView()
        spacer1.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let spacer2 = UIView()
        spacer2.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let locChip = makeChipButton("By Location")
        let mobChip = makeChipButton("By Mobile No")

        row2.addArrangedSubview(spacer1)
        row2.addArrangedSubview(locChip)
        row2.addArrangedSubview(mobChip)
        row2.addArrangedSubview(spacer2)

        // spacer1 == spacer2 width
        spacer1.widthAnchor.constraint(equalTo: spacer2.widthAnchor).isActive = true
        // chips equal width to row1 chips (1/3 each)
        locChip.widthAnchor.constraint(equalTo: mobChip.widthAnchor).isActive = true

        let outer = UIStackView(arrangedSubviews: [row1, row2])
        outer.axis = .vertical
        outer.spacing = 6
        outer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            outer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            outer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            outer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])
        return container
    }

    private func makeChipButton(_ title: String) -> UIButton {
        let b = UIButton(type: .custom)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = UIFont(name: "Poppins-SemiBold", size: 11) ?? .systemFont(ofSize: 11, weight: .semibold)
        b.layer.cornerRadius = 10
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 4, bottom: 10, right: 4)
        b.titleLabel?.adjustsFontSizeToFitWidth = true
        b.titleLabel?.minimumScaleFactor = 0.7
        b.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        chipButtons[title] = b
        return b
    }

    private func makeFieldLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont(name: "Poppins-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        l.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        return l
    }

    // MARK: - Chip appearance

    private func updateModeChips() {
        let orange = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        let fieldFill = UIColor(red: 0.973, green: 0.976, blue: 0.984, alpha: 1)
        for (mode, btn) in chipButtons {
            let selected = mode == viewModel.searchMode
            btn.backgroundColor = selected ? orange : fieldFill
            btn.setTitleColor(selected ? .white : UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1), for: .normal)
        }
    }

    // MARK: - Form body rebuild

    private func rebuildFormBody() {
        formBodyContainer.subviews.forEach { $0.removeFromSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        switch viewModel.searchMode {
        case "By Owner":
            stack.addArrangedSubview(makeFieldLabel("Owner Name"))
            let ownerTF = makeTextField(placeholder: "Enter owner name", tag: 1)
            stack.addArrangedSubview(ownerTF)
            stack.setCustomSpacing(16, after: ownerTF)
            stack.addArrangedSubview(makeFieldLabel("Father Name"))
            stack.addArrangedSubview(makeTextField(placeholder: "Enter father name", tag: 2))

        case "By Property ID":
            stack.addArrangedSubview(makeFieldLabel("Property ID"))
            stack.addArrangedSubview(makeTextField(placeholder: "Enter property ID", tag: 3))

        case "By House No":
            stack.addArrangedSubview(makeFieldLabel("Zone"))
            let zoneD = makeDropdownInForm(tag: 10, placeholder: viewModel.isLoadingZones ? "Loading Zones..." : (viewModel.selectedZone?.zoneName ?? "Choose Zone"), isSelected: viewModel.selectedZone != nil)
            stack.addArrangedSubview(zoneD)
            stack.setCustomSpacing(16, after: zoneD)
            stack.addArrangedSubview(makeFieldLabel("Ward"))
            let wardD = makeDropdownInForm(tag: 11, placeholder: viewModel.isLoadingWards ? "Loading Wards..." : (viewModel.selectedWard?.wardName ?? "Choose Ward"), isSelected: viewModel.selectedWard != nil)
            stack.addArrangedSubview(wardD)
            stack.setCustomSpacing(16, after: wardD)
            stack.addArrangedSubview(makeFieldLabel("House Number"))
            stack.addArrangedSubview(makeTextField(placeholder: "Enter house number", tag: 5))

        case "By Location":
            stack.addArrangedSubview(makeFieldLabel("Zone"))
            let zoneD = makeDropdownInForm(tag: 10, placeholder: viewModel.isLoadingZones ? "Loading Zones..." : (viewModel.selectedZone?.zoneName ?? "Choose Zone"), isSelected: viewModel.selectedZone != nil)
            stack.addArrangedSubview(zoneD)
            stack.setCustomSpacing(16, after: zoneD)
            stack.addArrangedSubview(makeFieldLabel("Ward"))
            let wardD = makeDropdownInForm(tag: 11, placeholder: viewModel.isLoadingWards ? "Loading Wards..." : (viewModel.selectedWard?.wardName ?? "Choose Ward"), isSelected: viewModel.selectedWard != nil)
            stack.addArrangedSubview(wardD)
            stack.setCustomSpacing(16, after: wardD)
            stack.addArrangedSubview(makeFieldLabel("Mohalla"))
            let mohallaD = makeDropdownInForm(tag: 12, placeholder: viewModel.isLoadingMohalles ? "Loading Mohallas..." : (viewModel.selectedMohalla?.mohallaName ?? "Choose Mohalla"), isSelected: viewModel.selectedMohalla != nil)
            stack.addArrangedSubview(mohallaD)
            stack.setCustomSpacing(16, after: mohallaD)
            stack.addArrangedSubview(makeFieldLabel("House Number"))
            stack.addArrangedSubview(makeTextField(placeholder: "Enter house number", tag: 5))

        case "By Mobile No":
            stack.addArrangedSubview(makeFieldLabel("Mobile Number"))
            stack.addArrangedSubview(makeTextField(placeholder: "Enter mobile number", tag: 6, isPhone: true))

        default: break
        }

        formBodyContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: formBodyContainer.topAnchor),
            stack.leadingAnchor.constraint(equalTo: formBodyContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: formBodyContainer.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: formBodyContainer.bottomAnchor),
        ])
    }

    private func makeTextField(placeholder: String, tag: Int, isPhone: Bool = false) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        tf.backgroundColor = UIColor(red: 0.973, green: 0.976, blue: 0.984, alpha: 1)
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1).cgColor
        tf.keyboardType = isPhone ? .phonePad : .default
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        tf.rightViewMode = .always
        tf.tag = tag
        tf.heightAnchor.constraint(equalToConstant: 48).isActive = true
        tf.delegate = self
        // Orange focus border handled via delegate
        return tf
    }

    private func makeDropdownInForm(tag: Int, placeholder: String, isSelected: Bool) -> DropdownField {
        let d = DropdownField()
        d.placeholder = placeholder
        d.isValueSelected = isSelected
        d.tag = tag
        d.heightAnchor.constraint(equalToConstant: 48).isActive = true
        d.addTarget(self, action: #selector(dropdownTapped(_:)), for: .touchUpInside)
        return d
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoadingUlbs.receive(on: DispatchQueue.main).sink { [weak self] loading in
            guard let self else { return }
            self.ulbDropdown.setLoading(loading,
                placeholder: self.viewModel.selectedUlb.map { "\($0.ulbName) (\($0.ulbType))" } ?? "Choose ULB",
                isSelected: self.viewModel.selectedUlb != nil)
        }.store(in: &cancellables)

        viewModel.$selectedUlb.receive(on: DispatchQueue.main).sink { [weak self] ulb in
            guard let self else { return }
            if let ulb {
                self.ulbDropdown.placeholder = "\(ulb.ulbName) (\(ulb.ulbType))"
                self.ulbDropdown.isValueSelected = true
            } else {
                self.ulbDropdown.placeholder = "Choose ULB"
                self.ulbDropdown.isValueSelected = false
            }
        }.store(in: &cancellables)

        Publishers.MergeMany(
            viewModel.$selectedZone.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$selectedWard.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$selectedMohalla.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$isLoadingZones.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$isLoadingWards.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$isLoadingMohalles.map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.rebuildFormBody() }
        .store(in: &cancellables)

        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.searchButton.setLoading(loading)
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            self?.errorLabel.text = msg
            self?.errorLabel.isHidden = msg == nil
        }.store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func chipTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        viewModel.searchMode = title
        viewModel.errorMessage = nil
        updateModeChips()
        rebuildFormBody()
        view.endEditing(true)
    }

    @objc private func ulbTapped() {
        guard !viewModel.isLoadingUlbs, !viewModel.ulbs.isEmpty else { return }
        showSelectionSheet(title: "Select ULB",
                           items: viewModel.ulbs.map { "\($0.ulbName) (\($0.ulbType))" }) { [weak self] idx in
            guard let self else { return }
            self.viewModel.selectUlb(self.viewModel.ulbs[idx])
        }
    }

    @objc private func dropdownTapped(_ sender: UIControl) {
        switch sender.tag {
        case 10: // Zone
            if viewModel.selectedUlb == nil {
                ENSSnackbar.show(in: view, message: "Please select ULB first", isError: true); return
            }
            guard !viewModel.isLoadingZones, !viewModel.zones.isEmpty else { return }
            showSelectionSheet(title: "Select Zone", items: viewModel.zones.map(\.zoneName)) { [weak self] idx in
                self?.viewModel.selectZone(self!.viewModel.zones[idx])
            }
        case 11: // Ward
            if viewModel.selectedZone == nil {
                ENSSnackbar.show(in: view, message: "Please select Zone first", isError: true); return
            }
            guard !viewModel.isLoadingWards, !viewModel.wards.isEmpty else { return }
            showSelectionSheet(title: "Select Ward", items: viewModel.wards.map(\.wardName)) { [weak self] idx in
                self?.viewModel.selectWard(self!.viewModel.wards[idx])
            }
        case 12: // Mohalla
            if viewModel.selectedWard == nil {
                ENSSnackbar.show(in: view, message: "Please select Ward first", isError: true); return
            }
            guard !viewModel.isLoadingMohalles, !viewModel.mohalles.isEmpty else { return }
            showSelectionSheet(title: "Select Mohalla", items: viewModel.mohalles.map(\.mohallaName)) { [weak self] idx in
                self?.viewModel.selectedMohalla = self?.viewModel.mohalles[idx]
            }
        default: break
        }
    }

    @objc private func searchTapped() {
        view.endEditing(true)
        // Collect text field values from form body
        collectFormValues()
        viewModel.search()
    }

    private func collectFormValues() {
        for sub in formBodyContainer.subviews {
            collectFromView(sub)
        }
    }

    private func collectFromView(_ view: UIView) {
        if let tf = view as? UITextField {
            switch tf.tag {
            case 1: viewModel.ownerName = tf.text ?? ""
            case 2: viewModel.fatherName = tf.text ?? ""
            case 3: viewModel.propertyId = tf.text ?? ""
            case 5: viewModel.houseNo = tf.text ?? ""
            case 6: viewModel.mobileNumber = tf.text ?? ""
            default: break
            }
        }
        for sub in view.subviews { collectFromView(sub) }
    }

    // MARK: - Selection bottom sheet

    private func showSelectionSheet(title: String, items: [String], onSelect: @escaping (Int) -> Void) {
        let sheet = SelectionSheetViewController(title: title, items: items, onSelect: onSelect)
        sheet.modalPresentationStyle = .pageSheet
        if let s = sheet.sheetPresentationController {
            s.detents = [.medium(), .large()]
            s.prefersGrabberVisible = true
            s.preferredCornerRadius = 24
        }
        present(sheet, animated: true)
    }

    // MARK: - Tour guide (first-run coach mark, see lib/tour_guides/search_property_tour.dart)
    // Note: Flutter re-runs a short 2-step tour every time the search mode tab
    // is switched (5 separate step sets, one per mode). To keep this native
    // port simple, a single walkthrough is shown once on first visit covering
    // the mode tabs, the ULB picker, the current form fields (defaulting to
    // "By Owner", the initial mode), and the Search button.

    private func presentTourIfNeeded() {
        guard !didPresentTour, !UserDefaultsService.shared.hasTourBeenSeen(.searchProperty) else { return }
        guard let modeChipsContainerView else { return }
        didPresentTour = true

        let steps: [TourStep] = [
            TourStep(target: modeChipsContainerView, icon: "slider.horizontal.3",
                     title: "5 Ways to Search",
                     description: "You can search property in 5 different ways. Each tab shows different input fields. Tap any tab to switch the search mode.",
                     edge: .bottom),
            TourStep(target: ulbDropdown, icon: "building.columns",
                     title: "Select ULB",
                     description: "Select your Urban Local Body first. This is mandatory for all 5 search options and loads the location data.",
                     edge: .bottom),
            TourStep(target: formBodyContainer, icon: "person.text.rectangle",
                     title: "Owner Search Fields",
                     description: "Enter Owner Name and Father Name here to search matching properties under that owner profile.",
                     edge: .bottom),
            TourStep(target: searchButton, icon: "magnifyingglass",
                     title: "Search Property",
                     description: "Once ULB and required fields are filled, tap Search. Matching properties will open on the next screen where you can select and save one.",
                     edge: .top),
        ]

        TourCoachMarkView.present(steps: steps) {
            UserDefaultsService.shared.markTourSeen(.searchProperty)
        }
    }
}

// MARK: - UITextFieldDelegate

extension SearchPropertyViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1).cgColor
        textField.layer.borderWidth = 1.5
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1).cgColor
        textField.layer.borderWidth = 1
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder(); return true
    }
}

// MARK: - DropdownField

final class DropdownField: UIControl {
    private let label = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
    private let spinner = UIActivityIndicatorView(style: .small)

    var placeholder: String = "" {
        didSet { label.text = placeholder }
    }
    var isValueSelected: Bool = false {
        didSet { updateStyle() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(red: 0.973, green: 0.976, blue: 0.984, alpha: 1)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1).cgColor

        label.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        chevron.tintColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        addSubview(label)
        addSubview(chevron)
        addSubview(spinner)
        NSLayoutConstraint.activate([
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 16),
            chevron.heightAnchor.constraint(equalToConstant: 16),
            spinner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        updateStyle()
    }

    func setLoading(_ loading: Bool, placeholder: String, isSelected: Bool) {
        self.placeholder = loading ? "Loading ULBs..." : placeholder
        isUserInteractionEnabled = !loading
        chevron.isHidden = loading
        if loading { spinner.startAnimating() } else { spinner.stopAnimating() }
        self.isValueSelected = isSelected
    }

    private func updateStyle() {
        if isValueSelected {
            label.textColor = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1)
            label.font = UIFont(name: "Poppins-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        } else {
            label.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
            label.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        }
    }
}

// MARK: - SelectionSheetViewController

final class SelectionSheetViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    private let sheetTitle: String
    private let allItems: [String]
    private var filtered: [String]
    private let onSelect: (Int) -> Void

    private let tableView = UITableView()
    private let searchBar = UISearchBar()

    init(title: String, items: [String], onSelect: @escaping (Int) -> Void) {
        self.sheetTitle = title
        self.allItems = items
        self.filtered = items
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // Title row
        let titleLabel = UILabel()
        titleLabel.text = sheetTitle
        titleLabel.font = UIFont(name: "Poppins-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        closeBtn.addTarget(self, action: #selector(dismiss(_:)), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false

        // Search bar
        searchBar.placeholder = "Search..."
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        // Table
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(closeBtn)
        view.addSubview(searchBar)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -8),
            closeBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            closeBtn.widthAnchor.constraint(equalToConstant: 36),
            closeBtn.heightAnchor.constraint(equalToConstant: 36),
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func dismiss(_ sender: Any) { dismiss(animated: true) }

    func tableView(_ tv: UITableView, numberOfRowsInSection s: Int) -> Int { filtered.count }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "Cell", for: ip)
        cell.textLabel?.text = filtered[ip.row]
        cell.textLabel?.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        return cell
    }

    func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        let item = filtered[ip.row]
        let originalIndex = allItems.firstIndex(of: item) ?? ip.row
        onSelect(originalIndex)
        dismiss(animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange text: String) {
        filtered = text.isEmpty ? allItems : allItems.filter { $0.localizedCaseInsensitiveContains(text) }
        tableView.reloadData()
    }
}
