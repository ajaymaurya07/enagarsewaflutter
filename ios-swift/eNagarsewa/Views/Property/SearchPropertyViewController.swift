import UIKit

/// Port of lib/search_property_screen.dart.
final class SearchPropertyViewController: BaseViewController {

    override var hidesNavigationBar: Bool { true }

    private enum Mode: String, CaseIterable {
        case owner = "By Owner", propertyId = "By Property ID", houseNo = "By House No",
             location = "By Location", mobile = "By Mobile No"

        var searchType: String {
            switch self {
            case .owner: return "OWNER"
            case .propertyId: return "PROPERTY"
            case .houseNo: return "HOUSE"
            case .location: return "LOCATION"
            case .mobile: return "MOBILE"
            }
        }
    }

    private var mode = Mode.owner
    private var ulbList: [UlbData] = []
    private var selectedUlb: UlbData?
    private var zoneList: [ZoneData] = []
    private var selectedZone: ZoneData?
    private var wardList: [WardData] = []
    private var selectedWard: WardData?
    private var mohallaList: [MohallaData] = []
    private var selectedMohalla: MohallaData?
    private var isLoadingUlbs = true
    private var isLoadingZones = false
    private var isLoadingWards = false
    private var isLoadingMohallas = false
    private var isLoggingOut = false

    // Language gate (loader / retry)
    private let gateView = UIView()

    // Form
    private let ownerField = ENSTextField(placeholder: "Enter owner name")
    private let fatherField = ENSTextField(placeholder: "Enter father name")
    private let propertyIdField = ENSTextField(placeholder: "Enter property ID")
    private let houseNoField = ENSTextField(placeholder: "Enter house number")
    private let mobileField = ENSTextField(placeholder: "Enter mobile number", keyboard: .phonePad)
    private let ulbField = SelectField(placeholder: "Choose ULB")
    private let zoneField = SelectField(placeholder: "Choose Zone")
    private let wardField = SelectField(placeholder: "Choose Ward")
    private let mohallaField = SelectField(placeholder: "Choose Mohalla")
    private let errorLabel = UILabel(nil, font: .poppins(12), color: .mRed600, lines: 0)
    private let searchButton = PrimaryButton("Search")
    private let modeFieldsContainer = UIStackView.v(0, [])
    private var modeChips: [Mode: UIView] = [:]
    private let tabsView = UIStackView.v(6, [])
    private var logoutButton: UIButton!
    private let logoutSpinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        buildForm()
        [ulbField, zoneField, wardField, mohallaField].forEach { $0.valueFont = .poppins(13, .medium) }
        ulbField.loadingText = "Loading ULBs..."
        zoneField.loadingText = "Loading Zones..."
        wardField.loadingText = "Loading Wards..."
        mohallaField.loadingText = "Loading Mohallas..."
        view.addSubview(gateView)
        gateView.backgroundColor = .white
        gateView.pinToEdges(of: view)
        Task { await loadUlbData() }
        Task { await loadUlbLanguage() }
    }

    // MARK: - Language gate

    private func showGate(loading: Bool) {
        gateView.subviews.forEach { $0.removeFromSuperview() }
        gateView.isHidden = false
        let content: UIView
        if loading {
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = .appPrimary
            spinner.startAnimating()
            content = UIStackView.v(16, alignment: .center, [spinner, UILabel("Please wait...", font: .poppins(14), color: .grey600)])
        } else {
            let retry = PrimaryButton("Retry", height: 46, fontSize: 15, weight: .semibold)
            retry.setSize(width: 160)
            retry.onEvent { [weak self] in
                self?.showGate(loading: true)
                Task { await self?.loadUlbLanguage() }
            }
            let stack = UIStackView.v(0, alignment: .center, [
                UIImageView(symbol: "wifi.slash", size: 52, color: .appPrimary),
                UILabel("No internet connection", font: .poppins(16, .semibold), color: .appTextDark),
                UILabel("Please check your connection and try again.", font: .poppins(13), color: .grey600, lines: 0, alignment: .center),
                retry,
            ])
            stack.setCustomSpacing(16, after: stack.arrangedSubviews[0])
            stack.setCustomSpacing(8, after: stack.arrangedSubviews[1])
            stack.setCustomSpacing(24, after: stack.arrangedSubviews[2])
            content = stack
        }
        gateView.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: gateView.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: gateView.centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: gateView.leadingAnchor, constant: 32),
        ])
    }

    /// ULB language is fetched only here (once, then cached) — the form waits for it.
    private func loadUlbLanguage() async {
        showGate(loading: true)
        do {
            if (StorageService.languageCache ?? "").isEmpty {
                let response = try await APIService.shared.getUlbLanguage()
                guard response.success, let language = response.language, !language.isEmpty else {
                    throw APIError.message(response.message)
                }
                StorageService.saveLanguageCache(language)
            }
            gateView.isHidden = true
            DispatchQueue.main.async { [weak self] in
                TourGuide.autoStartIfFirstVisit(.searchProperty) { self?.startTour() }
            }
        } catch {
            showGate(loading: false)
        }
    }

    // MARK: - Layout

    private func buildForm() {
        logoutSpinner.color = .appPrimary
        logoutSpinner.hidesWhenStopped = true
        logoutButton = iconButton("rectangle.portrait.and.arrow.right", color: .appPrimary, size: 20) { [weak self] in
            self?.handleLogout()
        }
        let logoutBox = UIView()
        logoutBox.setSize(width: 44, height: 44)
        logoutBox.addSubview(logoutButton)
        logoutBox.addSubview(logoutSpinner)
        logoutButton.center(in: logoutBox)
        logoutSpinner.center(in: logoutBox)
        let header = UIStackView.h(0, [
            UILabel("Search Property", font: .poppins(18, .bold), color: .appTextDark), FlexSpacer(),
            iconButton("questionmark.circle", color: .appPrimary) { [weak self] in self?.startTour() },
            logoutBox,
        ])
        view.addSubview(header)
        header.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ])

        // Mode tabs: 3 on the first row, 2 centred on the second (flex 1:5:5:1).
        let row1 = UIStackView.h(6, alignment: .fill, [chip(.owner), chip(.propertyId), chip(.houseNo)])
        row1.distribution = .fillEqually
        let row2Inner = UIStackView.h(6, alignment: .fill, [chip(.location), chip(.mobile)])
        row2Inner.distribution = .fillEqually
        let row2 = UIView()
        row2.addSubview(row2Inner)
        row2Inner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row2Inner.topAnchor.constraint(equalTo: row2.topAnchor),
            row2Inner.bottomAnchor.constraint(equalTo: row2.bottomAnchor),
            row2Inner.centerXAnchor.constraint(equalTo: row2.centerXAnchor),
            row2Inner.widthAnchor.constraint(equalTo: row2.widthAnchor, multiplier: 10.0 / 12.0),
        ])
        tabsView.add(row1, row2)

        let card = CardView(radius: 20, padding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
                            shadowOpacity: 0.06, shadowBlur: 20, shadowY: 8)
        let s = card.stack
        s.add(InfoLabel("Select ULB", helpTitle: SearchPropertyHelp.ulbTitle, helpMessage: SearchPropertyHelp.ulbMessage))
        s.addSpacer(8)
        s.add(ulbField)
        errorLabel.isHidden = true
        s.add(errorLabel)
        s.setCustomSpacing(8, after: ulbField)
        s.addSpacer(16)
        s.add(modeFieldsContainer)
        s.addSpacer(28)
        s.add(searchButton)

        installScrollStack(insets: UIEdgeInsets(top: 8, left: 16, bottom: 32, right: 16), below: header)
        contentStack.add(tabsView.padded(6))
        contentStack.addSpacer(20)
        contentStack.add(card)

        ulbField.onTap = { [weak self] in self?.showUlbSelection() }
        zoneField.onTap = { [weak self] in self?.showZoneSelection() }
        wardField.onTap = { [weak self] in self?.showWardSelection() }
        mohallaField.onTap = { [weak self] in self?.showMohallaSelection() }
        searchButton.onEvent { [weak self] in self?.handleSearch() }
        ulbField.isLoading = true
        renderMode()
    }

    private func chip(_ m: Mode) -> UIView {
        let v = UIView()
        v.layer.cornerRadius = 10
        let label = UILabel(m.rawValue, font: .poppins(11, .semibold), alignment: .center)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.tag = 1
        v.addSubview(label)
        label.pinToEdges(of: v, insets: UIEdgeInsets(top: 10, left: 4, bottom: 10, right: 4))
        v.onTap { [weak self] in
            guard !TourCoachMarkView.isActive else { return }
            self?.setMode(m)
        }
        modeChips[m] = v
        return v
    }

    private func setMode(_ m: Mode) {
        mode = m
        renderMode()
    }

    private func renderMode() {
        for (m, v) in modeChips {
            let selected = m == mode
            v.backgroundColor = selected ? .appPrimary : .appFieldFill
            (v.viewWithTag(1) as? UILabel)?.textColor = selected ? .white : .grey400
        }
        modeFieldsContainer.removeAllArranged()
        func add(_ label: InfoLabel, _ field: UIView, last: Bool = false) {
            modeFieldsContainer.add(label)
            modeFieldsContainer.addSpacer(8)
            modeFieldsContainer.add(field)
            if !last { modeFieldsContainer.addSpacer(16) }
        }
        let zone = InfoLabel("Zone", helpTitle: SearchPropertyHelp.zoneTitle, helpMessage: SearchPropertyHelp.zoneMessage)
        let ward = InfoLabel("Ward", helpTitle: SearchPropertyHelp.wardTitle, helpMessage: SearchPropertyHelp.wardMessage)
        let house = InfoLabel("House Number", helpTitle: SearchPropertyHelp.houseNumberTitle, helpMessage: SearchPropertyHelp.houseNumberMessage)
        switch mode {
        case .owner:
            add(InfoLabel("Owner Name", helpTitle: SearchPropertyHelp.ownerNameTitle, helpMessage: SearchPropertyHelp.ownerNameMessage), ownerField)
            add(InfoLabel("Father Name", helpTitle: SearchPropertyHelp.fatherNameTitle, helpMessage: SearchPropertyHelp.fatherNameMessage), fatherField, last: true)
        case .propertyId:
            add(InfoLabel("Property ID", helpTitle: SearchPropertyHelp.propertyIdTitle, helpMessage: SearchPropertyHelp.propertyIdMessage), propertyIdField, last: true)
        case .houseNo:
            add(zone, zoneField)
            add(ward, wardField)
            add(house, houseNoField, last: true)
        case .location:
            add(zone, zoneField)
            add(ward, wardField)
            add(InfoLabel("Mohalla", helpTitle: SearchPropertyHelp.mohallaTitle, helpMessage: SearchPropertyHelp.mohallaMessage), mohallaField)
            add(house, houseNoField, last: true)
        case .mobile:
            add(InfoLabel("Mobile Number", helpTitle: SearchPropertyHelp.mobileNumberTitle, helpMessage: SearchPropertyHelp.mobileNumberMessage), mobileField, last: true)
        }
        view.layoutIfNeeded()
    }

    private func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
    }

    // MARK: - Data loading

    private func loadUlbData() async {
        isLoadingUlbs = true
        ulbField.isLoading = true
        setError(nil)
        do {
            ulbList = try await APIService.shared.getUlbData()
            isLoadingUlbs = false
            ulbField.isLoading = false
            await preselectLoginUlb()
        } catch {
            isLoadingUlbs = false
            ulbField.isLoading = false
            setError(APIError.userMessage(error, fallback: "Unable to load ULB data right now. Please try again."))
        }
    }

    /// Selects the ULB from the OTP-login response by default (never overrides a manual pick).
    private func preselectLoginUlb() async {
        guard selectedUlb == nil, !ulbList.isEmpty,
              let loginUlbId = StorageService.ulbCache?.trimmingCharacters(in: .whitespaces), !loginUlbId.isEmpty,
              let match = ulbList.first(where: { ($0.ulbId ?? "").trimmingCharacters(in: .whitespaces) == loginUlbId })
        else { return }
        selectedUlb = match
        ulbField.value = match.ulbName
        await loadZoneData(loginUlbId)
    }

    private func loadZoneData(_ ulbId: String) async {
        isLoadingZones = true
        zoneField.isLoading = true
        zoneList = []; selectedZone = nil; zoneField.value = nil
        wardList = []; selectedWard = nil; wardField.value = nil
        mohallaList = []; selectedMohalla = nil; mohallaField.value = nil
        do {
            zoneList = try await APIService.shared.getZoneData(ulbId: ulbId)
        } catch {
            setError("Failed to load zones")
        }
        isLoadingZones = false
        zoneField.isLoading = false
    }

    private func loadWardData(_ ulbId: String, _ zoneId: String) async {
        isLoadingWards = true
        wardField.isLoading = true
        wardList = []; selectedWard = nil; wardField.value = nil
        mohallaList = []; selectedMohalla = nil; mohallaField.value = nil
        do {
            wardList = try await APIService.shared.getWardData(ulbId: ulbId, zoneId: zoneId)
        } catch {
            setError("Failed to load wards")
        }
        isLoadingWards = false
        wardField.isLoading = false
    }

    private func loadMohallaData(_ ulbId: String, _ zoneId: String, _ wardId: String) async {
        isLoadingMohallas = true
        mohallaField.isLoading = true
        mohallaList = []; selectedMohalla = nil; mohallaField.value = nil
        do {
            mohallaList = try await APIService.shared.getMohallaData(ulbId: ulbId, zoneId: zoneId, wardId: wardId)
        } catch {
            setError("Failed to load mohallas")
        }
        isLoadingMohallas = false
        mohallaField.isLoading = false
    }

    // MARK: - Pickers

    private func showUlbSelection() {
        guard !isLoadingUlbs else { return }
        OptionPickerSheet.present(on: self, title: "Select ULB",
                                  options: ulbList.map { "\($0.ulbName ?? "") (\($0.ulbType ?? ""))" },
                                  selected: nil, searchable: true) { [weak self] i in
            guard let self else { return }
            self.selectedUlb = self.ulbList[i]
            self.ulbField.value = self.ulbList[i].ulbName
            Task { await self.loadZoneData(self.ulbList[i].ulbId ?? "") }
        }
    }

    private func showZoneSelection() {
        guard selectedUlb != nil else { snack("Please select ULB first"); return }
        guard !isLoadingZones else { return }
        OptionPickerSheet.present(on: self, title: "Select Zone", options: zoneList.map(\.zoneName),
                                  selected: nil, searchable: true) { [weak self] i in
            guard let self, let ulb = self.selectedUlb else { return }
            self.selectedZone = self.zoneList[i]
            self.zoneField.value = self.zoneList[i].zoneName
            Task { await self.loadWardData(ulb.ulbId ?? "", self.zoneList[i].zoneId) }
        }
    }

    private func showWardSelection() {
        guard selectedZone != nil else { snack("Please select Zone first"); return }
        guard !isLoadingWards else { return }
        OptionPickerSheet.present(on: self, title: "Select Ward", options: wardList.map(\.wardName),
                                  selected: nil, searchable: true) { [weak self] i in
            guard let self, let ulb = self.selectedUlb, let zone = self.selectedZone else { return }
            self.selectedWard = self.wardList[i]
            self.wardField.value = self.wardList[i].wardName
            Task { await self.loadMohallaData(ulb.ulbId ?? "", zone.zoneId, self.wardList[i].wardId) }
        }
    }

    private func showMohallaSelection() {
        guard selectedWard != nil else { snack("Please select Ward first"); return }
        guard !isLoadingMohallas else { return }
        OptionPickerSheet.present(on: self, title: "Select Mohalla", options: mohallaList.map(\.mohallaName),
                                  selected: nil, searchable: true) { [weak self] i in
            guard let self else { return }
            self.selectedMohalla = self.mohallaList[i]
            self.mohallaField.value = self.mohallaList[i].mohallaName
        }
    }

    // MARK: - Search

    private func handleSearch() {
        guard let ulb = selectedUlb else { snack("Please select ULB first"); return }
        guard !searchButton.isLoading else { return }
        view.endEditing(true)
        searchButton.isLoading = true
        Task {
            do {
                let properties = try await APIService.shared.searchProperty(
                    ulbId: ulb.ulbId ?? "", searchType: mode.searchType,
                    propertyId: propertyIdField.trimmedText, ownerName: ownerField.trimmedText,
                    fatherName: fatherField.trimmedText, mobileNo: mobileField.trimmedText,
                    zoneId: selectedZone?.zoneId ?? "", wardId: selectedWard?.wardId ?? "",
                    mohallaId: selectedMohalla?.mohallaId ?? "", houseNo: houseNoField.trimmedText)
                searchButton.isLoading = false
                if properties.isEmpty {
                    snack("No properties found")
                    return
                }
                StorageService.saveUlbId(ulb.ulbId ?? "")
                if let arv = properties.first?.totalArv {
                    StorageService.saveTotalArv(JSON.dartDoubleString(arv))
                }
                push(PropertySelectionViewController(properties: properties))
            } catch {
                searchButton.isLoading = false
                snack(APIError.userMessage(error, fallback: "Unable to search properties right now. Please try again."))
            }
        }
    }

    // MARK: - Logout

    private func handleLogout() {
        guard !isLoggingOut else { return }
        AppDialog.show(on: self, title: "Logout", message: "Are you sure you want to logout?", actions: [
            .init(title: "Cancel", style: .cancel, color: .grey700),
            .init(title: "Logout", style: .destructive, color: .mRed600) { [weak self] in self?.performLogout() },
        ])
    }

    private func performLogout() {
        isLoggingOut = true
        logoutButton.isHidden = true
        logoutSpinner.startAnimating()
        Task {
            await SessionActions.logout()
            AppRouter.shared.showOtpLogin()
        }
    }

    // MARK: - Tour

    private func startTour() {
        guard !TourCoachMarkView.isActive, gateView.isHidden else { return }
        setMode(.owner)
        func modeSteps(_ m: Mode, icon: String, title: String, body: String, fieldIcon: String,
                       fieldTitle: String, fieldBody: String) -> [TourStep] {
            let prepare: () -> Void = { [weak self] in self?.setMode(m) }
            return [
                TourStep(target: modeChips[m]!, icon: icon, title: title, description: body,
                         shape: .roundedRect(radius: 10), prepare: prepare),
                TourStep(target: modeFieldsContainer, icon: fieldIcon, title: fieldTitle, description: fieldBody,
                         prepare: prepare),
            ]
        }
        var steps: [TourStep] = [
            TourStep(target: tabsView, icon: "slider.horizontal.3", title: "5 Ways to Search",
                     description: "You can search property in 5 different ways. Each tab shows different input fields. Tap any tab to switch the search mode."),
            TourStep(target: ulbField, icon: "building.columns", title: "Select ULB",
                     description: "Select your Urban Local Body first. This is mandatory for all 5 search options and loads the location data."),
        ]
        steps += modeSteps(.owner, icon: "person.crop.circle.badge.magnifyingglass", title: "By Owner Name",
                           body: "Search by entering the property owner's name and their father's name. Useful when you know the owner but not the property ID.",
                           fieldIcon: "person.text.rectangle", fieldTitle: "Owner Search Fields",
                           fieldBody: "Enter Owner Name and Father Name here to search matching properties under that owner profile.")
        steps += modeSteps(.propertyId, icon: "number", title: "By Property ID",
                           body: "Enter the unique Property ID directly. This is the fastest way if you already have the property ID on hand.",
                           fieldIcon: "number.square", fieldTitle: "Property ID Field",
                           fieldBody: "Type the exact Property ID here to open the property quickly without searching through multiple results.")
        steps += modeSteps(.houseNo, icon: "house", title: "By House Number",
                           body: "Search using house number. Select Zone and Ward first, then enter the house number to narrow down results.",
                           fieldIcon: "house.and.flag", fieldTitle: "House Number Search Fields",
                           fieldBody: "Choose Zone, then Ward, and then enter the house number. This narrows the search inside the selected area.")
        steps += modeSteps(.location, icon: "mappin.and.ellipse", title: "By Location",
                           body: "Search by full address. Select Zone -> Ward -> Mohalla in order, then optionally add a house number to get precise results.",
                           fieldIcon: "building.2", fieldTitle: "Location Search Fields",
                           fieldBody: "Select Zone, Ward, and Mohalla here. You can also add House Number to make the location search more accurate.")
        steps += modeSteps(.mobile, icon: "phone", title: "By Mobile Number",
                           body: "Enter the 10-digit mobile number registered with the property. All properties linked to that number will appear.",
                           fieldIcon: "iphone", fieldTitle: "Mobile Search Field",
                           fieldBody: "Enter the registered mobile number here. This is useful when the owner has more than one linked property.")
        steps.append(TourStep(target: searchButton, icon: "magnifyingglass", title: "Search Property",
                              description: "Once ULB and required fields are filled, tap Search. Matching properties will open on the next screen where you can select and save one.",
                              shape: .roundedRect(radius: 14), edge: .top, prepare: { [weak self] in self?.setMode(.mobile) }))
        TourCoachMarkView.present(steps: steps, scrollContainer: scrollView)
    }
}

/// Shared logout used by Search Property and Account (API logout best-effort, then local wipe).
enum SessionActions {
    static func logout() async {
        _ = try? await APIService.shared.logout()
        await DatabaseService.shared.clearDatabase()
        StorageService.logout()
    }
}

/// lib/help/search_property_help.dart
enum SearchPropertyHelp {
    static let ulbTitle = "Select ULB"
    static let ulbMessage = "Select the Urban Local Body (ULB) — the municipality or town council under which your property is registered.\n\nIf you are unsure, contact your local municipal office."
    static let ownerNameTitle = "Owner Name"
    static let ownerNameMessage = "Enter the full name of the property owner as registered in the municipal records.\n\nPartial names are also accepted."
    static let fatherNameTitle = "Father Name"
    static let fatherNameMessage = "Enter the father's or husband's name of the property owner as recorded in municipal records.\n\nUsed to narrow down search results."
    static let propertyIdTitle = "Property ID"
    static let propertyIdMessage = "Enter the unique Property ID assigned to your property by the municipality.\n\nYou can find this ID on your previous tax receipts or municipal documents."
    static let zoneTitle = "Zone"
    static let zoneMessage = "Select the zone in which your property is located.\n\nZones are administrative divisions used by the municipality to manage property records."
    static let wardTitle = "Ward"
    static let wardMessage = "Select the ward number or name for your property area.\n\nWards are smaller divisions within a zone. Check your tax receipt or address documents for your ward."
    static let houseNumberTitle = "House Number"
    static let houseNumberMessage = "Enter the house/plot number as it appears on your property documents.\n\nExample: 12, 4B, or Plot-7."
    static let mohallaTitle = "Mohalla"
    static let mohallaMessage = "Select the mohalla (locality/neighbourhood) where your property is located.\n\nThis helps narrow down the search within the selected ward."
    static let mobileNumberTitle = "Mobile Number"
    static let mobileNumberMessage = "Enter the 10-digit mobile number registered with the municipality for your property.\n\nExample: 9876543210"
}
