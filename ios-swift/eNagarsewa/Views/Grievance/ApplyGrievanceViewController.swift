import UIKit

/// Port of lib/apply_grievance_screen.dart.
final class ApplyGrievanceViewController: BaseViewController {

    static let propertyTaxCategoryName = "Property Tax (House, Water and Sewerage)"
    static let assessmentSubCategoryName = "Regarding Assessment"

    override var screenBackground: UIColor { .appFieldFill }

    private static let border = UIColor(argb: 0xFFE4E8F0)
    private static let hint = UIColor(argb: 0xFF6B7280)
    private static let textPrimary = UIColor(argb: 0xFF111827)

    private let preselectedPropertyId: String?
    private let preselectedCategoryName: String?
    private let preselectedSubCategoryName: String?

    private var savedProperties: [PropertyEntity] = []
    private var selectedProperty: PropertyEntity?
    private var ulbs: [UlbData]?
    private var ulbWaiters: [CheckedContinuation<[UlbData], Never>] = []
    private var selectedUlb: UlbData?
    private var zoneList: [ZoneData] = [], wardList: [WardData] = [], mohallaList: [MohallaData] = []
    private var selectedZone: ZoneData?, selectedWard: WardData?, selectedMohalla: MohallaData?
    private var categories: [GrievanceCategory] = []
    private var selectedCategory: GrievanceCategory?
    private var selectedSubCategory: GrievanceSubCategory?
    private var isLoadingCategories = true
    private var selectedImage: PickedFile?

    // Fields
    private let propertyField = ApplyGrievanceViewController.selectField("Select Property ID")
    private lazy var nameField = readOnlyField("Full Name")
    private lazy var mobileField = readOnlyField("Mobile Number")
    private lazy var fatherField = readOnlyField("Father/Husband Name")
    private lazy var addressField = readOnlyField("Address", lines: 2)
    private let ownerEmail = ""   // property's stored email (hidden in the form)
    private var propertyEmail = ""
    private lazy var emailField: ENSTextField = {
        let f = editableField("Email Address", keyboard: .emailAddress)
        f.validator = { v in
            let t = v.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return "Please enter Email Address" }
            return t.range(of: #"^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$"#, options: .regularExpression) == nil
                ? "Please enter a valid Email Address" : nil
        }
        return f
    }()
    private let ulbField = ApplyGrievanceViewController.selectField("Select ULB")
    private let zoneField = ApplyGrievanceViewController.selectField("Select Zone")
    private let wardField = ApplyGrievanceViewController.selectField("Select Ward")
    private let mohallaField = ApplyGrievanceViewController.selectField("Select Mohalla")
    private lazy var landmarkField: ENSTextField = {
        let f = editableField("Enter Landmark", maxLength: 200, help: (ApplyGrievanceHelp.landmarkTitle, ApplyGrievanceHelp.landmarkMessage))
        f.validator = { $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Please enter Enter Landmark" : nil }
        return f
    }()
    private let categoryField = ApplyGrievanceViewController.selectField("Select Category")
    private let subCategoryField = ApplyGrievanceViewController.selectField("Select Category First")
    private lazy var descriptionField: ENSTextField = {
        let f = editableField("Grievance Description", lines: 4, maxLength: 500,
                              help: (ApplyGrievanceHelp.descriptionTitle, ApplyGrievanceHelp.descriptionMessage))
        f.validator = { $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Please enter Grievance Description" : nil }
        return f
    }()
    private let photoBox = UIView()
    private let submitButton = PrimaryButton("Submit Grievance", height: 56, radius: 16)

    // Tour targets
    private var personalTitle: UIView!
    private var locationTitle: UIView!
    private var grievanceTitle: UIView!

    init(preselectedPropertyId: String? = nil, preselectedCategoryName: String? = nil,
         preselectedSubCategoryName: String? = nil) {
        self.preselectedPropertyId = preselectedPropertyId
        self.preselectedCategoryName = preselectedCategoryName
        self.preselectedSubCategoryName = preselectedSubCategoryName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Field factories

    private static func selectField(_ placeholder: String) -> SelectField {
        let f = SelectField(placeholder: placeholder, fill: .white)
        f.borderColor = border
        f.placeholderColor = hint
        f.valueColor = textPrimary
        return f
    }

    private func readOnlyField(_ label: String, lines: Int = 1) -> ENSTextField {
        var c = ENSTextField.Config()
        c.placeholder = label
        c.floatingLabel = true
        c.lines = lines
        c.fill = UIColor(argb: 0xFFF3F4F6)
        c.borderColor = Self.border
        c.labelColor = Self.hint
        c.textColor = Self.hint
        let f = ENSTextField(c)
        f.isEnabled = false
        f.alpha = 1
        return f
    }

    private func editableField(_ label: String, keyboard: UIKeyboardType = .default, lines: Int = 1,
                               maxLength: Int? = nil, help: (String, String)? = nil) -> ENSTextField {
        var c = ENSTextField.Config()
        c.placeholder = label
        c.floatingLabel = true
        c.lines = lines
        c.keyboard = keyboard
        c.maxLength = maxLength
        c.deny = "[<>]"
        c.fill = .white
        c.borderColor = Self.border
        c.labelColor = Self.hint
        c.textColor = Self.textPrimary
        let f = ENSTextField(c)
        if let help {
            f.setTrailing(iconButton("info.circle", color: .appPrimary, size: 16) { [weak self] in
                guard let self else { return }
                AppDialog.show(on: self, icon: "info.circle", iconSize: 20, title: help.0, message: help.1,
                               actions: [.init(title: "OK")])
            })
        }
        return f
    }

    private func sectionTitle(_ title: String, help: (String, String)? = nil) -> UIView {
        let label = UILabel(title, font: .poppins(16, .bold), color: .appPrimary)
        var views: [UIView] = [label]
        if let help {
            let icon = UIImageView(symbol: "info.circle", size: 15, color: .appPrimary)
            icon.onTap { [weak self] in
                guard let self else { return }
                AppDialog.show(on: self, icon: "info.circle", iconSize: 20, title: help.0, message: help.1,
                               actions: [.init(title: "OK")])
            }
            views.append(icon)
        }
        views.append(FlexSpacer())
        return UIStackView.h(6, views)
    }

    private func labeled(_ label: String, _ field: UIView) -> UIView {
        UIStackView.v(6, [UILabel(label, font: .poppins(13), color: .grey700), field])
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Apply Grievance", titleColor: .appPrimary,
                     rightItems: [helpItem { [weak self] in self?.startTour() }])
        buildForm()
        Task { await fetchUlbs() }
        Task { await fetchCategories() }
        Task { await loadSavedProperties() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        TourGuide.autoStartIfFirstVisit(.applyGrievance) { startTour() }
    }

    private func buildForm() {
        installScrollStack(insets: UIEdgeInsets(top: 20, left: 20, bottom: 40, right: 20))
        let s = contentStack
        s.add(sectionTitle("Property Information", help: (ApplyGrievanceHelp.propertyInfoTitle, ApplyGrievanceHelp.propertyInfoMessage)))
        s.addSpacer(12)
        s.add(propertyField)
        s.addSpacer(24)
        personalTitle = sectionTitle("Personal Information")
        s.add(personalTitle)
        s.addSpacer(12)
        for f in [nameField, mobileField, fatherField, addressField, emailField] {
            s.add(f)
            s.addSpacer(16)
        }
        s.addSpacer(8)
        locationTitle = sectionTitle("Location Details", help: (ApplyGrievanceHelp.locationDetailsTitle, ApplyGrievanceHelp.locationDetailsMessage))
        s.add(locationTitle)
        s.addSpacer(12)
        s.add(labeled("ULB", ulbField)); s.addSpacer(16)
        s.add(labeled("Zone", zoneField)); s.addSpacer(16)
        s.add(labeled("Ward", wardField)); s.addSpacer(16)
        s.add(labeled("Mohalla", mohallaField)); s.addSpacer(16)
        s.add(landmarkField)
        s.addSpacer(40)
        grievanceTitle = sectionTitle("Grievance Details", help: (ApplyGrievanceHelp.grievanceDetailsTitle, ApplyGrievanceHelp.grievanceDetailsMessage))
        s.add(grievanceTitle)
        s.addSpacer(12)
        s.add(categoryField); s.addSpacer(16)
        s.add(subCategoryField); s.addSpacer(16)
        s.add(descriptionField); s.addSpacer(32)
        s.add(sectionTitle("Upload Related Photo", help: (ApplyGrievanceHelp.photoTitle, ApplyGrievanceHelp.photoMessage)))
        s.addSpacer(12)
        photoBox.backgroundColor = .white
        photoBox.layer.cornerRadius = 12
        photoBox.addBorder(color: Self.border)
        photoBox.onTap { [weak self] in self?.showImageSource() }
        s.add(photoBox)
        s.addSpacer(32)
        s.add(submitButton)
        renderPhoto()

        ulbField.isLoading = true
        ulbField.loadingText = "Loading ULBs..."
        zoneField.loadingText = "Loading Zones..."
        wardField.loadingText = "Loading Wards..."
        mohallaField.loadingText = "Loading Mohallas..."
        categoryField.loadingText = "Loading Categories..."
        categoryField.isLoading = true
        subCategoryField.isEnabled = true
        [ulbField, zoneField, wardField, mohallaField, categoryField, subCategoryField, propertyField].forEach { $0.alpha = 1 }

        propertyField.onTap = { [weak self] in self?.pickProperty() }
        zoneField.onTap = { [weak self] in self?.pickZone() }
        wardField.onTap = { [weak self] in self?.pickWard() }
        mohallaField.onTap = { [weak self] in self?.pickMohalla() }
        categoryField.onTap = { [weak self] in self?.pickCategory() }
        subCategoryField.onTap = { [weak self] in self?.pickSubCategory() }
        submitButton.onEvent { [weak self] in self?.submit() }
    }

    private func renderPhoto() {
        photoBox.subviews.forEach { $0.removeFromSuperview() }
        if let image = selectedImage?.image {
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 8
            iv.setSize(height: 200)
            photoBox.addSubview(iv)
            iv.pinToEdges(of: photoBox, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
            let remove = iconTile("xmark", color: .white, background: .mRed, size: 28, iconSize: 14, radius: 14)
            remove.onTap { [weak self] in
                self?.selectedImage = nil
                self?.renderPhoto()
            }
            photoBox.addSubview(remove)
            remove.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                remove.topAnchor.constraint(equalTo: iv.topAnchor, constant: 8),
                remove.trailingAnchor.constraint(equalTo: iv.trailingAnchor, constant: -8),
            ])
        } else {
            let stack = UIStackView.v(0, alignment: .center, [
                UIImageView(symbol: "camera", size: 34, color: Self.hint),
                UILabel("Upload Related Photo", font: .poppins(14), color: Self.hint),
                UILabel("(Optional)", font: .poppins(12), color: Self.hint.withAlphaComponent(0.8)),
            ])
            stack.setCustomSpacing(8, after: stack.arrangedSubviews[0])
            stack.setCustomSpacing(4, after: stack.arrangedSubviews[1])
            photoBox.addSubview(stack)
            stack.pinToEdges(of: photoBox, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        }
    }

    // MARK: - Data

    private func fetchUlbs() async {
        let list = (try? await APIService.shared.getUlbData()) ?? []
        ulbField.isLoading = false
        ulbs = list
        ulbWaiters.forEach { $0.resume(returning: list) }
        ulbWaiters.removeAll()
    }

    /// `_ulbsCompleter.future`
    private func waitForUlbs() async -> [UlbData] {
        if let ulbs { return ulbs }
        return await withCheckedContinuation { ulbWaiters.append($0) }
    }

    private func fetchCategories() async {
        categories = (try? await APIService.shared.getGrievanceCategories()) ?? []
        isLoadingCategories = false
        categoryField.isLoading = false
        applyPreselectedGrievanceType()
    }

    private func applyPreselectedGrievanceType() {
        guard let name = preselectedCategoryName, !categories.isEmpty,
              let category = Self.matchByName(categories, name, { $0.serviceName }) else { return }
        let sub = preselectedSubCategoryName.flatMap { Self.matchByName(category.subCategories ?? [], $0, { $0.subName }) }
        setCategory(category, sub: sub)
    }

    /// Exact → contains → best word-overlap match (Dart `_matchByName`).
    static func matchByName<T>(_ items: [T], _ target: String, _ nameOf: (T) -> String?) -> T? {
        func normalize(_ v: String) -> String { v.lowercased().replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression) }
        func words(_ v: String) -> Set<String> {
            Set(v.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty && $0 != "and" })
        }
        let t = normalize(target)
        guard !t.isEmpty else { return nil }
        if let exact = items.first(where: { normalize(nameOf($0) ?? "") == t }) { return exact }
        if let partial = items.first(where: {
            let n = normalize(nameOf($0) ?? "")
            return !n.isEmpty && (n.contains(t) || t.contains(n))
        }) { return partial }
        let targetWords = words(target)
        guard !targetWords.isEmpty else { return nil }
        var best: T?
        var bestScore = 1
        for item in items {
            let score = words(nameOf(item) ?? "").intersection(targetWords).count
            if score > bestScore { bestScore = score; best = item }
        }
        return best
    }

    private func loadSavedProperties() async {
        savedProperties = await DatabaseService.shared.getAllProperties()
        if let pid = preselectedPropertyId {
            if let match = savedProperties.first(where: { $0.propertyId == pid }) { onPropertySelected(match) }
        } else if savedProperties.count == 1 {
            onPropertySelected(savedProperties[0])
        }
    }

    private func onPropertySelected(_ p: PropertyEntity) {
        selectedProperty = p
        propertyField.value = p.propertyId
        let krutidev = UlbLanguageHelper.isKrutidevValue(p.ulbLang)
        nameField.text = p.ownerName
        mobileField.text = p.phoneNumber
        propertyEmail = p.email ?? ""
        fatherField.text = p.fatherName ?? "N/A"
        addressField.text = p.address ?? "N/A"
        for f in [nameField, fatherField, addressField] {
            let font: UIFont = krutidev ? .krutidev(14) : .poppins(14)
            f.textField?.font = font
            f.textView?.font = font
        }
        Task { await autoFillLocation(p) }
    }

    private func autoFillLocation(_ p: PropertyEntity) async {
        guard let ulbId = p.ulbId, !ulbId.isEmpty else { return }
        let ulbs = await waitForUlbs()
        guard let ulb = ulbs.first(where: { $0.ulbId == ulbId }) else { return }
        zoneField.isLoading = true
        guard let zones = try? await APIService.shared.getZoneData(ulbId: ulbId) else { zoneField.isLoading = false; return }
        let zone = zones.first { $0.zoneName == p.zone }
        selectedUlb = ulb
        ulbField.value = ulb.displayName
        zoneList = zones
        zoneField.isLoading = false
        setZone(zone)
        guard let zone else { return }
        wardField.isLoading = true
        guard let wards = try? await APIService.shared.getWardData(ulbId: ulbId, zoneId: zone.zoneId) else { wardField.isLoading = false; return }
        let ward = wards.first { $0.wardName == p.ward }
        wardList = wards
        wardField.isLoading = false
        setWard(ward)
        guard let ward else { return }
        mohallaField.isLoading = true
        guard let mohallas = try? await APIService.shared.getMohallaData(ulbId: ulbId, zoneId: zone.zoneId, wardId: ward.wardId) else {
            mohallaField.isLoading = false; return
        }
        mohallaList = mohallas
        mohallaField.isLoading = false
        selectedMohalla = mohallas.first { $0.mohallaName == p.mohalla }
        mohallaField.value = selectedMohalla?.mohallaName
    }

    private func setZone(_ zone: ZoneData?) {
        selectedZone = zone
        zoneField.value = zone?.zoneName
        selectedWard = nil; wardField.value = nil; wardList = []
        selectedMohalla = nil; mohallaField.value = nil; mohallaList = []
    }

    private func setWard(_ ward: WardData?) {
        selectedWard = ward
        wardField.value = ward?.wardName
        selectedMohalla = nil; mohallaField.value = nil; mohallaList = []
    }

    private func setCategory(_ category: GrievanceCategory, sub: GrievanceSubCategory?) {
        selectedCategory = category
        categoryField.value = category.serviceName
        selectedSubCategory = sub
        subCategoryField.placeholderOverride = "Select Sub Category"
        subCategoryField.value = sub?.subName
    }

    // MARK: - Pickers

    private func pickProperty() {
        guard !savedProperties.isEmpty else { return }
        OptionPickerSheet.present(on: self, title: "Select Property", options: savedProperties.map(\.propertyId),
                                  selected: nil, searchable: true) { [weak self] i in
            guard let self else { return }
            self.onPropertySelected(self.savedProperties[i])
        }
    }

    private func pickZone() {
        guard let ulb = selectedUlb, !zoneField.isLoading else { return }
        OptionPickerSheet.present(on: self, title: "Select Zone", options: zoneList.map(\.zoneName), selected: nil,
                                  searchable: true) { [weak self] i in
            guard let self else { return }
            self.setZone(self.zoneList[i])
            Task {
                self.wardField.isLoading = true
                self.wardList = (try? await APIService.shared.getWardData(ulbId: ulb.ulbId ?? "", zoneId: self.zoneList[i].zoneId)) ?? []
                self.wardField.isLoading = false
            }
        }
    }

    private func pickWard() {
        guard let ulb = selectedUlb, let zone = selectedZone, !wardField.isLoading else { return }
        OptionPickerSheet.present(on: self, title: "Select Ward", options: wardList.map(\.wardName), selected: nil,
                                  searchable: true) { [weak self] i in
            guard let self else { return }
            self.setWard(self.wardList[i])
            Task {
                self.mohallaField.isLoading = true
                self.mohallaList = (try? await APIService.shared.getMohallaData(ulbId: ulb.ulbId ?? "", zoneId: zone.zoneId,
                                                                                 wardId: self.wardList[i].wardId)) ?? []
                self.mohallaField.isLoading = false
            }
        }
    }

    private func pickMohalla() {
        guard selectedWard != nil, !mohallaField.isLoading else { return }
        OptionPickerSheet.present(on: self, title: "Select Mohalla", options: mohallaList.map(\.mohallaName), selected: nil,
                                  searchable: true) { [weak self] i in
            guard let self else { return }
            self.selectedMohalla = self.mohallaList[i]
            self.mohallaField.value = self.mohallaList[i].mohallaName
        }
    }

    private func pickCategory() {
        guard !isLoadingCategories else { return }
        OptionPickerSheet.present(on: self, title: "Select Category", options: categories.map { $0.serviceName ?? "" },
                                  selected: nil, searchable: true) { [weak self] i in
            guard let self else { return }
            self.setCategory(self.categories[i], sub: nil)
        }
    }

    private func pickSubCategory() {
        guard let category = selectedCategory else { return }
        let subs = category.subCategories ?? []
        OptionPickerSheet.present(on: self, title: "Select Sub Category", options: subs.map { $0.subName ?? "" },
                                  selected: nil, searchable: true) { [weak self] i in
            guard let self else { return }
            self.selectedSubCategory = subs[i]
            self.subCategoryField.value = subs[i].subName
        }
    }

    // MARK: - Photo

    private func showImageSource() {
        present(ImageSourceSheet { [weak self] source in
            guard let self else { return }
            Task {
                guard let file = await MediaPicker.pickImage(from: self, source: source, quality: 80) else { return }
                if file.sizeInBytes > 200 * 1024 {
                    let kb = String(format: "%.1f", Double(file.sizeInBytes) / 1024)
                    AppDialog.show(on: self, icon: "exclamationmark.circle", iconColor: .mRed, iconSize: 28,
                                   title: "Image Too Large",
                                   message: "Selected image size is \(kb)KB which exceeds the 200KB limit.\n\nPlease select a smaller image.",
                                   actions: [.init(title: "OK")])
                    return
                }
                self.selectedImage = file
                self.renderPhoto()
            }
        }, animated: true)
    }

    // MARK: - Submit

    private func submit() {
        let valid = [emailField, landmarkField, descriptionField].map { $0.validate() }
        guard !valid.contains(false) else { return }
        let error: String?
        if selectedProperty == nil { error = "Please select Property ID" }
        else if selectedUlb == nil { error = "Please select ULB" }
        else if selectedZone == nil { error = "Please select Zone" }
        else if selectedWard == nil { error = "Please select Ward" }
        else if selectedMohalla == nil { error = "Please select Mohalla" }
        else if selectedCategory == nil { error = "Please select Category" }
        else if selectedSubCategory == nil { error = "Please select Sub Category" }
        else { error = nil }
        if let error { snack(error, .error); return }

        guard let property = selectedProperty, let ulb = selectedUlb, let zone = selectedZone, let ward = selectedWard,
              let mohalla = selectedMohalla, let category = selectedCategory, let sub = selectedSubCategory else { return }
        submitButton.isLoading = true
        LoadingOverlay.show(on: self)
        let mobile = mobileField.trimmedText
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: property.propertyId, mobileNo: mobile,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.saveGrievance(
                        ulbId: ulb.ulbId ?? "", zoneId: zone.zoneId, wardId: ward.wardId, mohallaId: mohalla.mohallaId,
                        categoryId: category.serviceCode.map(String.init) ?? "null",
                        subCategoryId: sub.subCatCode.map(String.init) ?? "null",
                        landmark: self.landmarkField.trimmedText, description: self.descriptionField.trimmedText,
                        name: self.nameField.trimmedText, fatherName: self.fatherField.trimmedText, mobileNo: mobile,
                        email: self.propertyEmail.trimmingCharacters(in: .whitespaces),
                        address: self.addressField.trimmedText, propertyId: property.propertyId,
                        emailAddress: self.emailField.trimmedText, image: self.selectedImage?.upload)
                }
                await LoadingOverlay.hideAsync()
                submitButton.isLoading = false
                if response.success, let id = response.data {
                    showSuccess(response.message.isEmpty ? "Grievance Registered Successfully!" : response.message, id: id)
                } else {
                    snack(response.message, .error)
                }
            } catch {
                await LoadingOverlay.hideAsync()
                submitButton.isLoading = false
                snack(APIError.userMessage(error, fallback: "Unable to submit grievance right now. Please try again."), .error)
            }
        }
    }

    private func showSuccess(_ message: String, id: String) {
        let content = UIStackView.v(0, [
            UILabel(message, font: .poppins(14), color: .black87, lines: 0),
            UIView().setSize(height: 12),
            UILabel("Grievance ID:", font: .poppins(14, .bold), color: .black87),
            UILabel(id, font: .poppins(18, .bold), color: .appPrimary, lines: 0),
        ])
        AppDialog.show(on: self, icon: "checkmark.circle", iconColor: .mGreen, iconSize: 28, title: "Success",
                       content: content, actions: [
            .init(title: "OK", color: UIColor.Scheme.primary) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            },
        ], dismissible: false)
    }

    // MARK: - Tour

    private func startTour() {
        guard !TourCoachMarkView.isActive else { return }
        TourCoachMarkView.present(steps: [
            TourStep(target: propertyField, icon: "building.2", title: "Select Property",
                     description: "Tap here to choose your saved property. Your name, mobile, and address will be auto-filled."),
            TourStep(target: personalTitle, icon: "person", title: "Personal Information",
                     description: "These fields are auto-filled from the selected property and cannot be edited."),
            TourStep(target: locationTitle, icon: "mappin.and.ellipse", title: "Location Details",
                     description: "Select your ULB, Zone, Ward, and Mohalla in order. Then enter a landmark near the issue."),
            TourStep(target: grievanceTitle, icon: "exclamationmark.bubble", title: "Grievance Details",
                     description: "Choose a category, then a sub-category, and describe your grievance clearly."),
            TourStep(target: photoBox, icon: "camera", title: "Upload Photo (Optional)",
                     description: "Attach a photo of the issue from your camera or gallery. Max size: 200 KB.", edge: .top),
            TourStep(target: submitButton, icon: "paperplane", title: "Submit Grievance",
                     description: "Once all fields are filled, tap here to submit. You will receive an OTP on your mobile to confirm.",
                     shape: .roundedRect(radius: 14), edge: .top),
        ], scrollContainer: scrollView)
    }
}

/// lib/help/apply_grievance_help.dart
enum ApplyGrievanceHelp {
    static let propertyInfoTitle = "Property Information"
    static let propertyInfoMessage = "Select the property for which you want to file a grievance.\n\nOnly properties linked to your account are shown. If your property is not listed, please search and add it from the home screen first."
    static let locationDetailsTitle = "Location Details"
    static let locationDetailsMessage = "Provide the exact location of the issue:\n\n• ULB — Urban Local Body (municipal authority)\n• Zone — large administrative division\n• Ward — subdivision within a zone\n• Mohalla — your specific locality\n• Landmark — a nearby reference point\n\nAccurate location helps in faster grievance assignment."
    static let grievanceDetailsTitle = "Grievance Details"
    static let grievanceDetailsMessage = "Describe your grievance in this section:\n\n• Category — broad type of issue (e.g., Property Tax, Water)\n• Sub Category — specific issue type\n• Description — detailed explanation of the problem\n\nThe more detail you provide, the faster it will be resolved."
    static let photoTitle = "Upload Related Photo"
    static let photoMessage = "Upload a photo that supports your grievance (optional but recommended).\n\nA clear image helps the concerned department understand the issue better and speeds up the resolution process.\n\n⚠️ Maximum file size: 200KB\n\nTap the area to pick from gallery or take a new photo."
    static let landmarkTitle = "Enter Landmark"
    static let landmarkMessage = "Enter a nearby landmark to help identify your property location.\n\nExample: Near City Hospital, Opposite Main Market."
    static let descriptionTitle = "Grievance Description"
    static let descriptionMessage = "Describe your grievance clearly and in detail.\n\nInclude:\n• What the problem is\n• Since when it is occurring\n• Any prior complaints filed (if applicable)\n\nA clear description helps in faster resolution."
}
