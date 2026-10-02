import UIKit

/// Step 1 — port of lib/property_tax_assessment_screen.dart.
final class PropertyTaxAssessmentViewController: AssessmentFlowViewController {

    private var ulbId: String?
    private var zoneList: [ZoneData] = [], wardList: [WardData] = [], mohallaList: [MohallaData] = []
    private var selectedZone: ZoneData?, selectedWard: WardData?, selectedMohalla: MohallaData?

    private let nameField = AssessmentUI.textField("Full Name", required: true)
    private let fatherField = AssessmentUI.textField("Father/Husband Name", required: true)
    private let mobileField = AssessmentUI.textField("Mobile Number", required: true, keyboard: .phonePad)
    private let emailField = AssessmentUI.textField("Email ID", keyboard: .emailAddress)
    private let oldIdField = AssessmentUI.textField("Old Property ID (if any)")
    private let houseField = AssessmentUI.textField("House Number", required: true)
    private let areaField = AssessmentUI.textField("Total Area (sq. ft.)", required: true, keyboard: .numberPad, digitsOnly: true)
    private let addressField = AssessmentUI.textField("Address", required: true, lines: 2)
    private let landmarkField = AssessmentUI.textField("Landmark", required: true)
    private let popularField = AssessmentUI.textField("Popular Property Name")
    private let zoneField = AssessmentUI.selectField("Select Zone")
    private let wardField = AssessmentUI.selectField("Select Ward")
    private let mohallaField = AssessmentUI.selectField("Select Mohalla")
    private let continueButton = AssessmentUI.actionButton("Continue")

    init() { super.init(title: "Property Tax Assessment", step: 1, total: 4) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let bar = installBottomButton(continueButton)
        installScrollStack(below: progressView, above: bar)
        let s = contentStack
        s.add(AssessmentUI.sectionTitle("Personal Details"))
        s.addSpacer(12)
        for f in [nameField, fatherField, mobileField, emailField, oldIdField] { s.add(f); s.addSpacer(12) }
        s.addSpacer(12)
        s.add(AssessmentUI.sectionTitle("Location Details"))
        s.addSpacer(12)
        s.add(AssessmentUI.labeled("Zone", zoneField)); s.addSpacer(16)
        s.add(AssessmentUI.labeled("Ward", wardField)); s.addSpacer(16)
        s.add(AssessmentUI.labeled("Mohalla", mohallaField)); s.addSpacer(16)
        for f in [houseField, areaField, addressField, landmarkField, popularField] { s.add(f); s.addSpacer(12) }

        zoneField.loadingText = "Loading Zones..."
        wardField.loadingText = "Loading Wards..."
        mohallaField.loadingText = "Loading Mohallas..."
        zoneField.placeholderOverride = "Loading..."
        zoneField.onTap = { [weak self] in self?.pickZone() }
        wardField.onTap = { [weak self] in self?.pickWard() }
        mohallaField.onTap = { [weak self] in self?.pickMohalla() }
        continueButton.onEvent { [weak self] in self?.handleContinue() }

        ulbId = StorageService.ulbCache
        if let ulbId, !ulbId.isEmpty {
            zoneField.placeholderOverride = nil
            Task { await fetchZones(ulbId) }
        } else {
            zoneField.placeholderOverride = "ULB not found. Please open Dashboard first."
        }
    }

    private func fetchZones(_ ulbId: String) async {
        zoneField.isLoading = true
        zoneList = (try? await APIService.shared.getZoneData(ulbId: ulbId)) ?? zoneList
        zoneField.isLoading = false
    }

    private func pickZone() {
        guard let ulbId, !ulbId.isEmpty, !zoneField.isLoading else { return }
        OptionPickerSheet.present(on: self, title: "Select Zone", options: zoneList.map(\.zoneName), selected: nil,
                                  searchable: true) { [weak self] i in
            guard let self else { return }
            let zone = self.zoneList[i]
            self.selectedZone = zone
            self.zoneField.value = zone.zoneName
            self.selectedWard = nil; self.wardField.value = nil; self.wardList = []
            self.selectedMohalla = nil; self.mohallaField.value = nil; self.mohallaList = []
            Task {
                self.wardField.isLoading = true
                if let w = try? await APIService.shared.getWardData(ulbId: ulbId, zoneId: zone.zoneId) { self.wardList = w }
                self.wardField.isLoading = false
            }
        }
    }

    private func pickWard() {
        guard let ulbId, let zone = selectedZone, !wardField.isLoading else { return }
        OptionPickerSheet.present(on: self, title: "Select Ward", options: wardList.map(\.wardName), selected: nil,
                                  searchable: true) { [weak self] i in
            guard let self else { return }
            let ward = self.wardList[i]
            self.selectedWard = ward
            self.wardField.value = ward.wardName
            self.selectedMohalla = nil; self.mohallaField.value = nil; self.mohallaList = []
            Task {
                self.mohallaField.isLoading = true
                if let m = try? await APIService.shared.getMohallaData(ulbId: ulbId, zoneId: zone.zoneId, wardId: ward.wardId) {
                    self.mohallaList = m
                }
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

    private func handleContinue() {
        view.endEditing(true)
        let fields = [nameField, fatherField, mobileField, emailField, oldIdField, houseField, areaField, addressField,
                      landmarkField, popularField]
        guard !fields.map({ $0.validate() }).contains(false) else { return }
        guard let zone = selectedZone, let ward = selectedWard, let mohalla = selectedMohalla else {
            snack("Please select Zone, Ward and Mohalla", duration: 4)
            return
        }
        continueButton.isLoading = true
        let mobile = mobileField.trimmedText
        let areaText = areaField.trimmedText
        let totalArea = Int(areaText) ?? Int((Double(areaText) ?? 0).rounded())
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: "", mobileNo: mobile, responseCode: { $0.responseCode }) {
                    try await APIService.shared.submitAssessmentStep1(
                        zoneId: Int(zone.zoneId) ?? 0, wardId: Int(ward.wardId) ?? 0, mohallaId: Int(mohalla.mohallaId) ?? 0,
                        oldPropertyId: self.oldIdField.trimmedText.isEmpty ? "0" : self.oldIdField.trimmedText,
                        totalArea: totalArea, ownerName: self.nameField.trimmedText,
                        fatherHusbandName: self.fatherField.trimmedText, email: self.emailField.trimmedText,
                        mobile: mobile, houseNo: self.houseField.trimmedText, address: self.addressField.trimmedText,
                        landmark: self.landmarkField.trimmedText, popularPropertyName: self.popularField.trimmedText)
                }
                continueButton.isLoading = false
                guard response.success == true, let data = response.data else {
                    snack("\(response.message ?? "Failed to submit assessment")\n(zone: \(zone.zoneName)/\(zone.zoneId), ward: \(ward.wardName)/\(ward.wardId), mohalla: \(mohalla.mohallaName)/\(mohalla.mohallaId))",
                          duration: 8)
                    return
                }
                guard let ackNo = data.ackNo else {
                    snack("Assessment saved but no Ack No. was returned", duration: 4)
                    return
                }
                push(AssessmentStep2ViewController(ackNo: ackNo, roadLocationList: data.roadLocationList,
                                                   propertyTypeList: data.propertyTypeList, propertyUsesList: data.propertyUsesList,
                                                   propertyId: "", mobileNo: mobile))
            } catch {
                continueButton.isLoading = false
                snack(APIError.userMessage(error, fallback: "Unable to submit assessment. Please try again."), duration: 4)
            }
        }
    }
}

/// Step 2 — port of lib/assessment_step2_screen.dart (also the re-assessment resume point).
final class AssessmentStep2ViewController: AssessmentFlowViewController {

    private let ackNo: String
    private let roadLocationList: OptionList
    private let propertyTypeList: OptionList
    private let propertyUsesList: OptionList
    private let propertyId: String
    private let mobileNo: String
    private let isReassessment: Bool
    private var roadId: String?, typeId: String?, usesId: String?

    private let fileNoField: ENSTextField = {
        let f = AssessmentUI.textField("File No.", keyboard: .numberPad, hint: "Enter File No.", floating: false)
        f.validator = { $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Please enter File No." : nil }
        return f
    }()
    private let roadField = AssessmentUI.selectField("Select Road Location")
    private let typeField = AssessmentUI.selectField("Select Property Type")
    private let usesField = AssessmentUI.selectField("Select Property Uses")
    private let continueButton = AssessmentUI.actionButton("Continue")

    init(ackNo: String, roadLocationList: OptionList = [], propertyTypeList: OptionList = [], propertyUsesList: OptionList = [],
         propertyId: String, mobileNo: String, isReassessment: Bool = false) {
        self.ackNo = ackNo
        self.roadLocationList = roadLocationList
        self.propertyTypeList = propertyTypeList
        self.propertyUsesList = propertyUsesList
        self.propertyId = propertyId
        self.mobileNo = mobileNo
        self.isReassessment = isReassessment
        super.init(title: isReassessment ? "Property Tax Re-Assessment" : "Property Tax Assessment", step: 2,
                   total: isReassessment ? 3 : 4)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let bar = installBottomButton(continueButton)
        installScrollStack(below: progressView, above: bar)
        let s = contentStack
        if isReassessment {
            s.add(AssessmentUI.sectionTitle("Property ID")); s.addSpacer(12)
            s.add(AssessmentUI.readOnlyBox(propertyId.isEmpty ? "-" : propertyId)); s.addSpacer(24)
        }
        s.add(AssessmentUI.sectionTitle("Ack No.")); s.addSpacer(12)
        s.add(AssessmentUI.readOnlyBox(ackNo)); s.addSpacer(24)
        s.add(AssessmentUI.sectionTitle("File No.")); s.addSpacer(12)
        s.add(fileNoField)
        if !isReassessment {
            s.addSpacer(24); s.add(AssessmentUI.sectionTitle("Road Location")); s.addSpacer(12); s.add(roadField)
            s.addSpacer(24); s.add(AssessmentUI.sectionTitle("Property Type")); s.addSpacer(12); s.add(typeField)
            s.addSpacer(24); s.add(AssessmentUI.sectionTitle("Property Uses")); s.addSpacer(12); s.add(usesField)
        }
        s.addSpacer(32)
        bind(roadField, "Select Road Location", roadLocationList) { [weak self] value in self?.roadId = value }
        bind(typeField, "Select Property Type", propertyTypeList) { [weak self] value in self?.typeId = value }
        bind(usesField, "Select Property Uses", propertyUsesList) { [weak self] value in self?.usesId = value }
        continueButton.onEvent { [weak self] in self?.handleContinue() }
    }

    private func bind(_ field: SelectField, _ title: String, _ list: OptionList, _ set: @escaping (String) -> Void) {
        field.onTap = { [weak self] in
            guard let self, !list.isEmpty else { return }
            OptionPickerSheet.present(on: self, title: title, options: list.map(\.value), selected: nil, searchable: true) { i in
                set(list[i].key)
                field.value = list[i].value
            }
        }
    }

    private func handleContinue() {
        view.endEditing(true)
        guard fileNoField.validate() else { return }
        if !isReassessment && (roadId == nil || typeId == nil || usesId == nil) {
            snack("Please select Road Location, Property Type and Property Uses")
            return
        }
        continueButton.isLoading = true
        let fileNo = fileNoField.trimmedText
        Task {
            do {
                if isReassessment {
                    let response = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: mobileNo,
                                                                      responseCode: { $0.responseCode }) {
                        try await APIService.shared.fetchReassessmentFloorConfig(propertyId: self.propertyId, ackNo: self.ackNo, fileNo: fileNo)
                    }
                    continueButton.isLoading = false
                    guard response.success == true, let data = response.data else {
                        snack(response.message ?? "Failed to fetch floor configuration")
                        return
                    }
                    push(AssessmentStep3ViewController(ackNo: data.ackNo ?? ackNo, floorNoList: data.floorNoList,
                                                       floorUsageList: data.floorUsageList,
                                                       constructionTypeList: data.constructionTypeList, isReassessment: true,
                                                       propertyId: data.propertyId ?? propertyId, mobileNo: mobileNo))
                } else {
                    let response = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: mobileNo,
                                                                      responseCode: { $0.responseCode }) {
                        try await APIService.shared.submitAssessmentStep2(
                            ackNo: self.ackNo, fileNo: fileNo, roadLocationId: Int(self.roadId ?? "") ?? 0,
                            propertyTypeId: Int(self.typeId ?? "") ?? 0, propertyUseasId: Int(self.usesId ?? "") ?? 0)
                    }
                    continueButton.isLoading = false
                    guard response.success == true, let data = response.data else {
                        snack(response.message ?? "Failed to submit assessment")
                        return
                    }
                    push(AssessmentStep3ViewController(ackNo: data.ackNo ?? ackNo, floorNoList: data.floorNoList,
                                                       floorUsageList: data.floorUsageList,
                                                       constructionTypeList: data.constructionTypeList,
                                                       propertyId: propertyId, mobileNo: mobileNo))
                }
            } catch {
                continueButton.isLoading = false
                snack(APIError.userMessage(error, fallback: isReassessment
                    ? "Unable to fetch floor configuration. Please try again."
                    : "Unable to submit assessment. Please try again."))
            }
        }
    }
}

/// Step 3 — port of lib/assessment_step3_screen.dart (floors, rebate, final tax summary).
final class AssessmentStep3ViewController: AssessmentFlowViewController {

    private let ackNo: String
    private let floorNoList: OptionList
    private let floorUsageList: OptionList
    private let constructionTypeList: OptionList
    private let isReassessment: Bool
    private let propertyId: String
    private let mobileNo: String

    private var floorNumberKey: String?, floorUsageCode: String?, constructionTypeId: String?
    private var areaEnterMode = "MR"
    private var floorTypes: [FloorType] = []
    private var selectedFloorType: FloorType?
    private var floors: [FloorDetailItem] = []
    private var totalArv: Double?
    private var rebateYears: OptionList = []
    private var rebateYearKey: String?
    private var rebateTypes: [RebateType] = []
    private var isLoadingRebateTypes = false
    private var selectedRebateType: RebateType?
    private var deletingFloor: Int?
    private var finalResult: AssessmentStep3Data?
    private let isRebateClaimed = "Y"

    private let floorNoField = AssessmentUI.selectField("Select Floor Number")
    private let usageField = AssessmentUI.selectField("Select Floor Usage")
    private let floorTypeField = AssessmentUI.selectField("Select Floor Type")
    private let constructionField = AssessmentUI.selectField("Select Construction Type")
    private let dateField: ENSTextField = {
        let f = AssessmentUI.textField("Construction Date", required: true)
        f.textField?.isUserInteractionEnabled = false
        return f
    }()
    private let modeField = AssessmentUI.selectField("Measure by Room")
    private let modeHint = UILabel(nil, font: .poppins(11.5), color: .grey500, lines: 0)
    private let carpetField = AssessmentUI.textField("Carpet Area (sq. ft.)", required: true, keyboard: .numberPad, digitsOnly: true)
    private let roomsField = AssessmentUI.textField("Rooms & Porch Area (sq. ft.)", required: true, keyboard: .numberPad, digitsOnly: true)
    private let kitchenField = AssessmentUI.textField("Kitchen, Balcony, Corridor & Store Area (sq. ft.)", keyboard: .numberPad, digitsOnly: true)
    private let garageField = AssessmentUI.textField("Garage Area (sq. ft.)", keyboard: .numberPad, digitsOnly: true)
    private let areaFieldsStack = UIStackView.v(12, [])
    private let saveFloorButton = AssessmentUI.actionButton("Save Floor", icon: "plus")
    private let rebateYearField = AssessmentUI.selectField("Select Financial Year")
    private let rebateTypeField = AssessmentUI.selectField("Select Rebate Type")
    private let finalizeButton = AssessmentUI.actionButton("Finalize Assessment")
    private var addFloorCard: UIView!

    init(ackNo: String, floorNoList: OptionList, floorUsageList: OptionList, constructionTypeList: OptionList,
         isReassessment: Bool = false, propertyId: String, mobileNo: String) {
        self.ackNo = ackNo
        self.floorNoList = floorNoList
        self.floorUsageList = floorUsageList
        self.constructionTypeList = constructionTypeList
        self.isReassessment = isReassessment
        self.propertyId = propertyId
        self.mobileNo = mobileNo
        super.init(title: isReassessment ? "Property Tax Re-Assessment" : "Property Tax Assessment",
                   step: isReassessment ? 2 : 3, total: isReassessment ? 3 : 4)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        installScrollStack(below: progressView)
        buildAddFloorCard()
        floorTypeField.loadingText = "Loading Floor Types..."
        rebateTypeField.loadingText = "Loading Rebate Types..."
        floorNoField.onTap = { [weak self] in
            guard let self, !self.floorNoList.isEmpty else { return }
            self.pick("Select Floor Number", self.floorNoList.map(\.value)) { i in
                self.floorNumberKey = self.floorNoList[i].key
                self.floorNoField.value = self.floorNoList[i].value
            }
        }
        usageField.onTap = { [weak self] in
            guard let self, !self.floorUsageList.isEmpty else { return }
            self.pick("Select Floor Usage", self.floorUsageList.map(\.value)) { i in
                self.usageField.value = self.floorUsageList[i].value
                self.onFloorUsageSelected(self.floorUsageList[i].key)
            }
        }
        floorTypeField.onTap = { [weak self] in
            guard let self, self.floorUsageCode != nil, !self.floorTypes.isEmpty else { return }
            self.pick("Select Floor Type", self.floorTypes.map { $0.name ?? "-" }) { i in
                self.selectedFloorType = self.floorTypes[i]
                self.floorTypeField.value = self.floorTypes[i].name
            }
        }
        constructionField.onTap = { [weak self] in
            guard let self, !self.constructionTypeList.isEmpty else { return }
            self.pick("Select Construction Type", self.constructionTypeList.map(\.value)) { i in
                self.constructionTypeId = self.constructionTypeList[i].key
                self.constructionField.value = self.constructionTypeList[i].value
            }
        }
        dateField.onTap { [weak self] in self?.pickConstructionDate() }
        modeField.onTap = { [weak self] in
            self?.pick("Select Area Entry Mode", ["Carpet Area", "Measure by Room"]) { i in self?.setAreaMode(i == 0 ? "CA" : "MR") }
        }
        rebateYearField.onTap = { [weak self] in
            guard let self, !self.rebateYears.isEmpty else { return }
            self.pick("Select Financial Year", self.rebateYears.map(\.value)) { i in
                self.rebateYearKey = self.rebateYears[i].key
                self.rebateYearField.value = self.rebateYears[i].value
            }
        }
        rebateTypeField.onTap = { [weak self] in
            guard let self, !self.isLoadingRebateTypes, !self.rebateTypes.isEmpty else { return }
            self.pick("Select Rebate Type", self.rebateTypes.map { $0.rebateName ?? "-" }) { i in
                self.selectedRebateType = self.rebateTypes[i]
                self.rebateTypeField.value = self.rebateTypes[i].rebateName
            }
        }
        saveFloorButton.onEvent { [weak self] in self?.handleSaveFloor() }
        finalizeButton.onEvent { [weak self] in self?.handleFinalize() }
        setAreaMode("MR")
        render()
    }

    private func pick(_ title: String, _ options: [String], _ onSelect: @escaping (Int) -> Void) {
        view.endEditing(true)
        OptionPickerSheet.present(on: self, title: title, options: options, selected: nil, searchable: true, onSelect: onSelect)
    }

    private func subLabel(_ text: String) -> UIView {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: text.uppercased(), attributes: [
            .font: UIFont.poppins(11, .bold), .foregroundColor: UIColor.grey500, .kern: 0.4])
        return l
    }

    private func formDivider() -> UIView { divider(color: .grey200).padded(UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)) }

    private func formCard(_ views: [UIView]) -> UIView {
        let card = CardView(radius: 16, padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12), shadowOpacity: 0.03,
                            shadowBlur: 14, shadowY: 4, border: .grey200)
        views.forEach { card.stack.addArrangedSubview($0) }
        return card
    }

    private func buildAddFloorCard() {
        let views: [UIView] = [
            subLabel("Floor Information"), UIView().setSize(height: 12),
            AssessmentUI.labeled("Floor Number", floorNoField), UIView().setSize(height: 12),
            AssessmentUI.labeled("Floor Usage", usageField), UIView().setSize(height: 12),
            AssessmentUI.labeled("Floor Type", floorTypeField), UIView().setSize(height: 12),
            AssessmentUI.labeled("Construction Type", constructionField),
            formDivider(), subLabel("Construction Date"), UIView().setSize(height: 12), dateField,
            formDivider(), subLabel("Area Details"), UIView().setSize(height: 12),
            AssessmentUI.labeled("How do you want to enter the area?", modeField), UIView().setSize(height: 6), modeHint,
            UIView().setSize(height: 12), areaFieldsStack, UIView().setSize(height: 24), saveFloorButton,
        ]
        addFloorCard = formCard(views)
    }

    private func setAreaMode(_ mode: String) {
        areaEnterMode = mode
        if mode == "CA" {
            roomsField.text = ""; kitchenField.text = ""; garageField.text = ""
        } else {
            carpetField.text = ""
        }
        modeField.value = mode == "CA" ? "Carpet Area" : "Measure by Room"
        modeHint.text = mode == "CA"
            ? "Enter the total carpet area of the floor directly."
            : "Enter the area of each part of the floor separately — rooms/porch is required, kitchen/balcony and garage are optional."
        areaFieldsStack.arrangedSubviews.forEach { areaFieldsStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        if mode == "CA" { areaFieldsStack.add(carpetField) } else { areaFieldsStack.add(roomsField, kitchenField, garageField) }
    }

    private func render() {
        let s = contentStack
        s.arrangedSubviews.forEach { s.removeArrangedSubview($0); $0.removeFromSuperview() }
        if let final = finalResult {
            renderFinalSummary(final)
            return
        }
        if !floors.isEmpty {
            s.add(AssessmentUI.sectionTitle("Saved Floors", icon: "square.stack.3d.up")); s.addSpacer(12)
            for f in floors { s.add(floorCard(f)); s.addSpacer(10) }
            if let totalArv {
                s.add(UILabel("Total ARV: ₹\(String(format: "%.2f", totalArv))", font: .poppins(14, .semibold), color: .appPrimary))
            }
            s.addSpacer(24)
        }
        s.add(AssessmentUI.sectionTitle("Add Floor", icon: "house.and.flag")); s.addSpacer(12)
        s.add(addFloorCard)
        if !floors.isEmpty {
            s.addSpacer(28)
            s.add(AssessmentUI.sectionTitle("Rebate Details", icon: "percent")); s.addSpacer(12)
            s.add(formCard([AssessmentUI.labeled("Rebate Financial Year", rebateYearField), UIView().setSize(height: 16),
                            AssessmentUI.labeled("Rebate Type", rebateTypeField), UIView().setSize(height: 20), finalizeButton]))
        }
        s.addSpacer(32)
    }

    private func floorCard(_ f: FloorDetailItem) -> UIView {
        let card = CardView(radius: 12, padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10), shadowOpacity: 0, border: .grey300)
        let area = f.carpetArea.map(JSON.dartDoubleString) ?? "-"
        let arv = f.arv.map { String(format: "%.2f", $0) } ?? "-"
        let texts = UIStackView.v(2, [
            UILabel(f.floorName ?? "Floor \(f.floorNumber.map(String.init) ?? "")", font: .poppins(14, .semibold), color: .black87),
            UILabel("\(f.floorTypeName ?? "-") • \(f.constructionTypeName ?? "-")", font: .poppins(12), color: .grey600, lines: 0),
            UILabel("Area: \(area) sq.ft. • ARV: ₹\(arv)", font: .poppins(12), color: .grey600, lines: 0),
        ])
        let trailing: UIView
        if deletingFloor != nil && deletingFloor == f.floorNumber {
            let sp = UIActivityIndicatorView(style: .medium)
            sp.color = .appPrimary
            sp.startAnimating()
            trailing = sp
        } else {
            trailing = iconButton("trash", color: UIColor(argb: 0xFFFF5252), size: 20) { [weak self] in
                guard let n = f.floorNumber else { return }
                self?.handleDeleteFloor(n)
            }
        }
        card.stack.add(UIStackView.h(8, [texts, FlexSpacer(), trailing]))
        return card
    }

    private func renderFinalSummary(_ d: AssessmentStep3Data) {
        let s = contentStack
        let header = UIStackView.v(4, [
            UILabel("Ack No: \(d.acknowledgementId ?? "-")", font: .poppins(15, .bold), color: .black87),
            UILabel("Total ARV: ₹\(d.totalArv.map { String(format: "%.2f", $0) } ?? "-")", font: .poppins(13), color: .grey800),
            UILabel("Rebate: \(d.taxRebateTypeName ?? "-") (\(d.rebateFinancialYear ?? "-"))", font: .poppins(13), color: .grey800, lines: 0),
        ]).padded(16)
        header.backgroundColor = AssessmentUI.softPrimary
        header.layer.cornerRadius = 12
        header.addBorder(color: .appPrimary)
        s.add(header); s.addSpacer(20)
        s.add(AssessmentUI.sectionTitle("Tax Breakdown")); s.addSpacer(12)
        for pws in d.pwsList {
            let card = CardView(radius: 12, shadowOpacity: 0, border: .grey300)
            card.stack.add(UILabel("FY \(pws.finYear ?? "-")", font: .poppins(14, .bold), color: .black87))
            card.stack.addSpacer(8)
            func row(_ l: String, _ v: Double?, bold: Bool = false) {
                card.stack.add(UIStackView.h(8, [
                    UILabel(l, font: .poppins(13, bold ? .bold : .regular), color: .grey800), FlexSpacer(),
                    UILabel("₹\(String(format: "%.2f", v ?? 0))", font: .poppins(13, bold ? .bold : .medium),
                            color: bold ? .appPrimary : .grey900),
                ]).padded(UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)))
            }
            row("Property Tax", pws.propertyTax); row("Water Tax", pws.waterTax)
            row("Sewerage Tax", pws.sewerageTax); row("Other Tax", pws.otherTax)
            card.stack.add(divider(color: .grey300, thickness: 0.5).padded(UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)))
            row("Grand Total", pws.grandTotal, bold: true)
            s.add(card); s.addSpacer(12)
        }
        let upload = AssessmentUI.actionButton("Upload Document & Finish")
        upload.onEvent { [weak self] in
            guard let self else { return }
            self.push(AssessmentDocumentUploadViewController(ackNo: d.acknowledgementId ?? self.ackNo,
                                                             isReassessment: self.isReassessment,
                                                             propertyId: self.propertyId, mobileNo: self.mobileNo))
        }
        s.add(upload)
    }

    // MARK: - Actions

    private func onFloorUsageSelected(_ code: String) {
        floorUsageCode = code
        selectedFloorType = nil
        floorTypeField.value = nil
        floorTypes = []
        floorTypeField.isLoading = true
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: mobileNo,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.getFloorTypeList(floorUsageId: code)
                }
                floorTypes = response.data
            } catch {
                snack(APIError.userMessage(error, fallback: "Unable to load floor types."))
            }
            floorTypeField.isLoading = false
        }
    }

    private func pickConstructionDate() {
        view.endEditing(true)
        DatePickerSheet.present(on: self, initial: Date(), minimum: Calendar.current.date(from: DateComponents(year: 1950, month: 1, day: 1)),
                                maximum: Date()) { [weak self] date in
            let f = DateFormatter()
            f.dateFormat = "dd-MM-yyyy"
            self?.dateField.text = f.string(from: date)
            self?.dateField.setError(nil)
        }
    }

    private func handleSaveFloor() {
        view.endEditing(true)
        let required = areaEnterMode == "CA" ? [dateField, carpetField] : [dateField, roomsField]
        guard !required.map({ $0.validate() }).contains(false) else { return }
        guard let floorKey = floorNumberKey else { snack("Please select Floor Number"); return }
        guard let usage = floorUsageCode else { snack("Please select Floor Usage"); return }
        guard let floorType = selectedFloorType else { snack("Please select Floor Type"); return }
        guard let construction = constructionTypeId else { snack("Please select Construction Type"); return }
        let input = FloorInput(floorNumber: Int(floorKey) ?? 0, floorUsageCode: usage, floorTypeId: floorType.id ?? 0,
                               constructionTypeId: Int(construction) ?? 0, constructionDate: dateField.trimmedText,
                               carpetArea: Int(carpetField.trimmedText) ?? 0, roomsPorchArea: Int(roomsField.trimmedText) ?? 0,
                               kitchenBalconyArea: Int(kitchenField.trimmedText) ?? 0, garageArea: Int(garageField.trimmedText) ?? 0,
                               areaEnterMode: areaEnterMode)
        saveFloorButton.isLoading = true
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: mobileNo,
                                                                  responseCode: { $0.responseCode }) {
                    if self.isReassessment { return try await APIService.shared.saveReassessmentFloor(ackNo: self.ackNo, floor: input) }
                    return try await APIService.shared.saveFloorDetails(ackNo: self.ackNo, floor: input)
                }
                saveFloorButton.isLoading = false
                guard response.success == true, let data = response.data else {
                    snack(response.message ?? "Failed to save floor details")
                    return
                }
                floors = data.floorList
                totalArv = data.totalArv
                rebateYears = data.rebateFinancialYearList
                floorNumberKey = nil; floorNoField.value = nil
                floorUsageCode = nil; usageField.value = nil
                selectedFloorType = nil; floorTypeField.value = nil; floorTypes = []
                constructionTypeId = nil; constructionField.value = nil
                [dateField, carpetField, roomsField, kitchenField, garageField].forEach { $0.text = "" }
                render()
                loadRebateTypes()
                snack(response.message ?? "Floor details saved successfully")
            } catch {
                saveFloorButton.isLoading = false
                snack(APIError.userMessage(error, fallback: "Unable to save floor details. Please try again."))
            }
        }
    }

    private func handleDeleteFloor(_ number: Int) {
        deletingFloor = number
        render()
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: mobileNo,
                                                                  responseCode: { $0.responseCode }) {
                    if self.isReassessment { return try await APIService.shared.deleteReassessmentFloor(ackNo: self.ackNo, floorNumber: number) }
                    return try await APIService.shared.deleteFloorDetails(ackNo: self.ackNo, floorNumber: number)
                }
                deletingFloor = nil
                if response.success == true {
                    floors.removeAll { $0.floorNumber == number }
                    snack(response.message ?? "Floor deleted successfully")
                } else {
                    snack(response.message ?? "Failed to delete floor")
                }
            } catch {
                deletingFloor = nil
                snack(APIError.userMessage(error, fallback: "Unable to delete floor. Please try again."))
            }
            render()
        }
    }

    private func loadRebateTypes() {
        guard rebateTypes.isEmpty, !isLoadingRebateTypes else { return }
        isLoadingRebateTypes = true
        rebateTypeField.isLoading = true
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: mobileNo,
                                                                  responseCode: { $0.responseCode }) {
                    try await APIService.shared.getRebateTypeList()
                }
                rebateTypes = response.data
            } catch {
                snack(APIError.userMessage(error, fallback: "Unable to load rebate types."))
            }
            isLoadingRebateTypes = false
            rebateTypeField.isLoading = false
        }
    }

    private func handleFinalize() {
        view.endEditing(true)
        guard !floors.isEmpty else { snack("Please add at least one floor before finalizing"); return }
        guard let yearKey = rebateYearKey, let year = rebateYears.first(where: { $0.key == yearKey })?.value else {
            snack("Please select a Rebate Financial Year")
            return
        }
        guard let rebate = selectedRebateType else { snack("Please select a Rebate Type"); return }
        finalizeButton.isLoading = true
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: mobileNo,
                                                                  responseCode: { $0.responseCode }) {
                    if self.isReassessment {
                        return try await APIService.shared.submitReassessmentStep3(
                            ackNo: self.ackNo, propertyId: self.propertyId, rebateFinyear: year,
                            isRebateClaimed: self.isRebateClaimed, rebateTypeId: rebate.rebateId)
                    }
                    return try await APIService.shared.submitAssessmentStep3(
                        ackNo: self.ackNo, rebateFinyear: year, isRebateClaimed: self.isRebateClaimed, rebateTypeId: rebate.rebateId)
                }
                finalizeButton.isLoading = false
                guard response.success == true, let data = response.data else {
                    snack(response.message ?? "Failed to finalize assessment")
                    return
                }
                finalResult = data
                render()
            } catch {
                finalizeButton.isLoading = false
                snack(APIError.userMessage(error, fallback: "Unable to finalize assessment. Please try again."))
            }
        }
    }
}

/// Step 4 — port of lib/assessment_document_upload_screen.dart.
final class AssessmentDocumentUploadViewController: AssessmentFlowViewController {

    private let ackNo: String
    private let isReassessment: Bool
    private let propertyId: String
    private let mobileNo: String
    private var selectedFile: PickedFile?
    private var isSuccess = false
    private var successMessage: String?
    private let submitButton = AssessmentUI.actionButton("Submit & Finalize")

    init(ackNo: String, isReassessment: Bool = false, propertyId: String, mobileNo: String) {
        self.ackNo = ackNo
        self.isReassessment = isReassessment
        self.propertyId = propertyId
        self.mobileNo = mobileNo
        let total = isReassessment ? 3 : 4
        super.init(title: isReassessment ? "Finalize Re-Assessment" : "Finalize Assessment", step: total, total: total)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        installScrollStack(below: progressView)
        submitButton.onEvent { [weak self] in self?.handleSubmit() }
        render()
    }

    private func render() {
        let s = contentStack
        s.arrangedSubviews.forEach { s.removeArrangedSubview($0); $0.removeFromSuperview() }
        if isSuccess {
            // Success: no back chevron, no progress bar, back allowed (`canPop: _isSuccess`).
            interceptsBack = false
            navigationItem.leftBarButtonItems = []
            progressView?.isHidden = true
            let done = AssessmentUI.actionButton("Done")
            done.onEvent { [weak self] in self?.navigationController?.popToRootViewController(animated: true) }
            let stack = UIStackView.v(0, alignment: .center, [
                iconTile("checkmark.circle.fill", color: .mGreen, background: AssessmentUI.softPrimary, size: 104, iconSize: 60, radius: 52),
                UILabel(isReassessment ? "Re-Assessment Submitted" : "Assessment Submitted", font: .poppins(18, .bold),
                        color: AssessmentUI.textColor, lines: 0, alignment: .center),
                UILabel(successMessage ?? "Your application has been submitted successfully.", font: .poppins(14),
                        color: .grey700, lines: 0, alignment: .center),
                done,
            ])
            stack.setCustomSpacing(20, after: stack.arrangedSubviews[0])
            stack.setCustomSpacing(10, after: stack.arrangedSubviews[1])
            stack.setCustomSpacing(28, after: stack.arrangedSubviews[2])
            done.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            s.add(stack.padded(UIEdgeInsets(top: 100, left: 8, bottom: 0, right: 8)))
            return
        }
        let info = UIStackView.v(4, [
            UILabel("Ack No: \(ackNo)", font: .poppins(15, .bold), color: .black87),
            UILabel("Upload the supporting document to complete your \(isReassessment ? "re-assessment" : "assessment") application.",
                    font: .poppins(13), color: .grey800, lines: 0),
        ]).padded(16)
        info.backgroundColor = AssessmentUI.softPrimary
        info.layer.cornerRadius = 12
        info.addBorder(color: .appPrimary)
        s.add(info); s.addSpacer(24)
        s.add(UILabel("Supporting Document", font: .poppins(16, .bold), color: AssessmentUI.textColor)); s.addSpacer(6)
        s.add(UILabel("Only JPEG images are supported. Maximum file size 200 KB.", font: .poppins(12), color: .grey600, lines: 0))
        s.addSpacer(14)

        let box = UIView()
        box.layer.cornerRadius = 14
        box.clipsToBounds = true
        if let image = selectedFile?.image {
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFill
            box.addSubview(iv)
            iv.pinToEdges(of: box)
            box.setSize(height: 220)
            let close = iconTile("xmark", color: .white, background: .black54, size: 30, iconSize: 14, radius: 15)
            close.onTap { [weak self] in
                self?.selectedFile = nil
                self?.render()
            }
            box.addSubview(close)
            close.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([close.topAnchor.constraint(equalTo: box.topAnchor, constant: 8),
                                         close.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8)])
        } else {
            box.backgroundColor = .white
            box.layer.borderWidth = 1.4
            box.layer.borderColor = UIColor.appPrimary.withAlphaComponent(0.5).cgColor
            box.setSize(height: 160)
            let stack = UIStackView.v(10, alignment: .center, [
                UIImageView(symbol: "icloud.and.arrow.up", size: 32, color: .appPrimary),
                UILabel("Tap to attach document", font: .poppins(14, .semibold), color: .appPrimary),
            ])
            box.addSubview(stack)
            stack.center(in: box)
        }
        box.onTap { [weak self] in self?.showImageSource() }
        s.add(box)
        if selectedFile != nil {
            s.addSpacer(12)
            let replace = UIButton(type: .system)
            replace.setTitle("Replace Document", for: .normal)
            replace.setImage(.symbol("arrow.clockwise", size: 15, weight: .semibold), for: .normal)
            replace.tintColor = .appPrimary
            replace.titleLabel?.font = .poppins(13, .semibold)
            replace.onEvent { [weak self] in self?.showImageSource() }
            s.add(UIStackView.h(0, [replace, FlexSpacer()]))
        }
        s.addSpacer(28)
        s.add(submitButton)
        s.addSpacer(20)
    }

    private func showImageSource() {
        present(ImageSourceSheet(title: "Attach Document") { [weak self] source in
            guard let self else { return }
            Task {
                guard let file = await MediaPicker.pickImage(from: self, source: source, quality: 80) else { return }
                if file.sizeInBytes > 200 * 1024 {
                    let kb = String(format: "%.1f", Double(file.sizeInBytes) / 1024)
                    AppDialog.show(on: self, icon: "exclamationmark.circle", iconColor: .mRed, iconSize: 28, title: "File Too Large",
                                   message: "Selected file size is \(kb)KB which exceeds the 200KB limit.\n\nPlease select a smaller file.",
                                   actions: [.init(title: "OK")])
                    return
                }
                self.selectedFile = file
                self.render()
            }
        }, animated: true)
    }

    private func handleSubmit() {
        guard let file = selectedFile else { snack("Please attach a supporting document"); return }
        submitButton.isLoading = true
        Task {
            do {
                let response = try await OtpGateService.guardCall(propertyId: propertyId, mobileNo: mobileNo,
                                                                  responseCode: { $0.responseCode }) {
                    if self.isReassessment {
                        return try await APIService.shared.finalizeReassessment(ackNo: self.ackNo, applicationFile: file.upload)
                    }
                    return try await APIService.shared.finalizeAssessment(ackNo: self.ackNo, applicationFile: file.upload)
                }
                submitButton.isLoading = false
                guard response.success == true else {
                    snack(response.message ?? "Failed to finalize. Please try again.")
                    return
                }
                isSuccess = true
                successMessage = response.message
                render()
            } catch {
                submitButton.isLoading = false
                snack(APIError.userMessage(error, fallback: "Unable to submit document. Please try again."))
            }
        }
    }
}

/// `showDatePicker` equivalent — inline calendar in a bottom sheet.
final class DatePickerSheet: BottomSheetController {
    private let picker = UIDatePicker()
    private let onPick: (Date) -> Void

    init(initial: Date, minimum: Date?, maximum: Date?, onPick: @escaping (Date) -> Void) {
        self.onPick = onPick
        super.init()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.tintColor = .appPrimary
        picker.minimumDate = minimum
        picker.maximumDate = maximum
        picker.date = initial
        contentInsets = UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func buildContent() {
        contentStack.add(picker)
        let cancel = textButton("Cancel", color: .grey700, size: 14) { [weak self] in self?.close() }
        let ok = textButton("OK", size: 14) { [weak self] in
            guard let self else { return }
            let date = self.picker.date
            self.close { [onPick = self.onPick] in onPick(date) }
        }
        contentStack.add(UIStackView.h(16, [FlexSpacer(), cancel, ok]).padded(UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)))
    }

    static func present(on vc: UIViewController, initial: Date, minimum: Date? = nil, maximum: Date? = nil,
                        onPick: @escaping (Date) -> Void) {
        vc.topPresented.present(DatePickerSheet(initial: initial, minimum: minimum, maximum: maximum, onPick: onPick), animated: true)
    }
}
