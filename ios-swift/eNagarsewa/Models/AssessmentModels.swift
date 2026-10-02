import Foundation

// Ports of the property tax assessment / reassessment models in lib/services/api_service.dart.

typealias OptionList = [(key: String, value: String)]

struct RebateType: Equatable {
    let rebateId: Int?
    let rebateName: String?
    let rebatePercentage: Double?

    init(json: JSON) {
        rebateId = json["rebateId"].int
        rebateName = json["rebateName"].str
        rebatePercentage = json["rebatePercentage"].double
    }
}

struct FloorType: Equatable {
    let id: Int?
    let name: String?

    init(json: JSON) {
        id = json["id"].int
        name = json["name"].str
    }
}

struct RebateTypeListResponse {
    let responseCode: Int?
    let data: [RebateType]
    let message: String?
}

struct FloorTypeListResponse {
    let responseCode: Int?
    let data: [FloorType]
    let message: String?
}

// MARK: - Step 1

struct AssessmentStep1Response {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let data: AssessmentStep1Data?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        data = json["data"].object != nil ? AssessmentStep1Data(json: json["data"]!) : nil
    }
}

struct AssessmentStep1Data {
    let ulbId: String?
    let zoneId: String?
    let wardId: String?
    let mohallaId: String?
    let oldPropertyId: String?
    let totalArea: String?
    let ownerName: String?
    let fatherHusbandName: String?
    let email: String?
    let mobile: String?
    let houseNo: String?
    let address: String?
    let landmark: String?
    let popularPropertyName: String?
    let zoneName: String?
    let wardName: String?
    let mohallaName: String?
    let ackNo: String?
    let assessmentDate: String?
    let propertyTypeList: OptionList
    let roadLocationList: OptionList
    let propertyUsesList: OptionList

    init(json: JSON) {
        ulbId = json["ulbId"].str
        zoneId = json["zoneId"].str
        wardId = json["wardId"].str
        mohallaId = json["mohallaId"].str
        oldPropertyId = json["oldPropertyId"].str
        totalArea = json["totalArea"].str
        ownerName = json["ownerName"].str
        fatherHusbandName = json["fatherHusbandName"].str
        email = json["email"].str
        mobile = json["mobile"].str
        houseNo = json["houseNo"].str
        address = json["address"].str
        landmark = json["landmark"].str
        popularPropertyName = json["popularPropertyName"].str
        zoneName = json["zoneName"].str
        wardName = json["wardName"].str
        mohallaName = json["mohallaName"].str
        ackNo = json["ackNo"].str
        assessmentDate = json["assessmentDate"].str
        propertyTypeList = json["propertyTypeList"].stringMap
        roadLocationList = json["roadLocationList"].stringMap
        propertyUsesList = json["propertyUseasList"].stringMap
    }
}

// MARK: - Step 2 / floor config

struct AssessmentStep2Response {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let data: AssessmentStep2Data?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        data = json["data"].object != nil ? AssessmentStep2Data(json: json["data"]!) : nil
    }
}

struct AssessmentStep2Data {
    let propertyId: String?
    let ackNo: String?
    let floorNoList: OptionList
    let floorUsageList: OptionList
    let constructionTypeList: OptionList

    init(json: JSON) {
        propertyId = json["propertyId"].str
        ackNo = json["ackNo"].str
        floorNoList = json["floorNoList"].stringMap
        floorUsageList = json["floorUsageList"].stringMap
        constructionTypeList = json["constructionTypeList"].stringMap
    }
}

// MARK: - Step 3 floors

struct SaveFloorResponse {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let data: SaveFloorData?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        data = json["data"].object != nil ? SaveFloorData(json: json["data"]!) : nil
    }
}

struct SaveFloorData {
    let ackNo: String?
    let totalArv: Double?
    let floorList: [FloorDetailItem]
    let rebateFinancialYearList: OptionList

    init(json: JSON) {
        ackNo = json["ackNo"].str
        totalArv = json["totalArv"].double
        floorList = json["floorList"].objects(FloorDetailItem.init(json:))
        rebateFinancialYearList = json["rebateFinancialYearList"].stringMap
    }
}

struct FloorDetailItem {
    let floorNumber: Int?
    let floorName: String?
    let carpetArea: Double?
    let floorTypeName: String?
    let constructionTypeName: String?
    let constructionDate: String?
    let mrate: Double?
    let multiplier: Double?
    let rentalValue: Double?
    let arv: Double?
    let arvAfterRebate: Double?

    init(json: JSON) {
        floorNumber = json["floorNumber"].int
        floorName = json["floorName"].str
        carpetArea = json["carpetArea"].double
        floorTypeName = json["floorTypeName"].str
        constructionTypeName = json["constructionTypeName"].str
        constructionDate = json["constructionDate"].str
        mrate = json["mrate"].double
        multiplier = json["multiplier"].double
        rentalValue = json["rentalValue"].double
        arv = json["arv"].double
        arvAfterRebate = json["arvAfterRebate"].double
    }
}

/// Shared `{success, message, responseCode}` response (delete floor, step 4, …).
struct DeleteFloorResponse {
    let success: Bool?
    let message: String?
    let responseCode: Int?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
    }
}

typealias AssessmentDeleteResponse = DeleteFloorResponse

struct AssessmentStep3Response {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let data: AssessmentStep3Data?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        data = json["data"].object != nil ? AssessmentStep3Data(json: json["data"]!) : nil
    }
}

struct AssessmentStep3Data {
    let pwsList: [PwsItem]
    let propertyId: String?
    let ulbId: Int?
    let acknowledgementId: String?
    let totalArea: Double?
    let ownerName: String?
    let fatherName: String?
    let houseNo: String?
    let address: String?
    let zoneId: Int?
    let wardId: Int?
    let mohallaId: Int?
    let mobile: String?
    let assessmentType: String?
    let fileNo: String?
    let propertyUse: String?
    let roadLocation: String?
    let propertyType: Int?
    let assessmentDate: String?
    let oldArv: String?
    let existingPropertyId: String?
    let totalArv: Double?
    let rebateFinancialYear: String?
    let taxRebateTypeName: String?

    init(json: JSON) {
        pwsList = json["pwsList"].objects(PwsItem.init(json:))
        propertyId = json["propertyId"].str
        ulbId = json["ulbId"].int
        acknowledgementId = json["acknowledgementId"].str
        totalArea = json["totalArea"].double
        ownerName = json["ownerName"].str
        fatherName = json["fatherName"].str
        houseNo = json["houseNo"].str
        address = json["address"].str
        zoneId = json["zoneId"].int
        wardId = json["wardId"].int
        mohallaId = json["mohallaId"].int
        mobile = json["mobile"].str
        assessmentType = json["assessmentType"].str
        fileNo = json["fileNo"].str
        propertyUse = json["propertyUse"].str
        roadLocation = json["roadLocation"].str
        propertyType = json["propertyType"].int
        assessmentDate = json["assessmentDate"].str
        oldArv = json["oldArv"].str
        existingPropertyId = json["existingPropertyId"].str
        totalArv = json["totalArv"].double
        rebateFinancialYear = json["rebateFinancialYear"].str
        taxRebateTypeName = json["taxRebateTypeName"].str
    }
}

struct PwsItem {
    let finYear: String?
    let propertyTax: Double?
    let propertyArrear: Double?
    let propertyInterest: Double?
    let waterTax: Double?
    let waterArrear: Double?
    let waterInterest: Double?
    let sewerageTax: Double?
    let sewerageArrear: Double?
    let sewerageInterest: Double?
    let otherTax: Double?
    let otherArrear: Double?
    let otherInterest: Double?
    let waterCharge: Double?
    let waterChargeArrear: Double?
    let waterChargeInterest: Double?
    let totalTax: Double?
    let totalInterest: Double?
    let grandTotal: Double?

    init(json: JSON) {
        finYear = json["finYear"].str
        propertyTax = json["propertyTax"].double
        propertyArrear = json["propertyArrear"].double
        propertyInterest = json["propertyInterest"].double
        waterTax = json["waterTax"].double
        waterArrear = json["waterArrear"].double
        waterInterest = json["waterInterest"].double
        sewerageTax = json["sewerageTax"].double
        sewerageArrear = json["sewerageArrear"].double
        sewerageInterest = json["sewerageInterest"].double
        otherTax = json["otherTax"].double
        otherArrear = json["otherArrear"].double
        otherInterest = json["otherInterest"].double
        waterCharge = json["waterCharge"].double
        waterChargeArrear = json["waterChargeArrear"].double
        waterChargeInterest = json["waterChargeInterest"].double
        totalTax = json["totalTax"].double
        totalInterest = json["totalInterest"].double
        grandTotal = json["grandTotal"].double
    }
}

// MARK: - Reassessment

struct ReassessmentGetS1Response {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let data: ReassessmentGetS1Data?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        data = json["data"].object != nil ? ReassessmentGetS1Data(json: json["data"]!) : nil
    }
}

struct ReassessmentGetS1Data {
    let propertyId: String?
    let dateOfLastAssessment: String?
    let noOfFloor: Int?
    let ackNo: String?

    init(json: JSON) {
        propertyId = json["propertyId"].str
        dateOfLastAssessment = json["dateOfLastAssessment"].str
        noOfFloor = json["noOfFloor"].int
        ackNo = json["ackNo"].str?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ReassessmentListResponse {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let data: [ReassessmentListItem]

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        data = (json["data"].array ?? []).map(ReassessmentListItem.init(json:))
    }
}

struct ReassessmentListItem {
    let propertyId: String?
    let ackNo: String?
    let assessType: String?
    let assessDate: String?
    let ownerName: String?
    let fatherName: String?
    let houseNo: String?
    let address: String?
    let totalArv: String?
    let currentStage: Int?
    let isCompleted: String?
    let createdAt: String?
    let updatedAt: String?
    let nextStage: Int?

    var isCompletedFlag: Bool { (isCompleted ?? "").uppercased() == "YES" }

    init(json: JSON) {
        propertyId = json["property_id"].str
        ackNo = json["ack_no"].str
        assessType = json["assess_type"].str
        assessDate = json["assess_date"].str
        ownerName = json["owner_name"].str
        fatherName = json["father_name"].str
        houseNo = json["house_no"].str
        address = json["address"].str
        totalArv = json["total_arv"].str
        currentStage = json["current_stage"].int
        isCompleted = json["is_completed"].str
        createdAt = json["created_at"].str
        updatedAt = json["updated_at"].str
        nextStage = json["next_stage"].int
    }
}

struct ReassessmentStep1Response {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let data: ReassessmentStep1Data?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        data = json["data"].object != nil ? ReassessmentStep1Data(json: json["data"]!) : nil
    }
}

struct ReassessmentStep1Data {
    let assessType: String?
    let zoneId: Int?
    let wardId: Int?
    let mohallaId: Int?
    let zoneName: String?
    let wardName: String?
    let mohallaName: String?
    let roadLocationName: String?
    let propertyTypeName: String?
    let fileNo: String?
    let totalArea: Double?
    let ownerName: String?
    let fatherName: String?
    let houseNo: String?
    let address: String?
    let assessmentDate: String?
    let propertyId: String?
    let ackNo: String?
    let roadLocationId: String?
    let oldArv: String?

    init(json: JSON) {
        assessType = json["assessType"].str
        zoneId = json["zoneId"].int
        wardId = json["wardId"].int
        mohallaId = json["mohallaId"].int
        zoneName = json["zoneName"].str
        wardName = json["wardName"].str
        mohallaName = json["mohallaName"].str
        roadLocationName = json["roadLocationName"].str
        propertyTypeName = json["propertyTypeName"].str
        fileNo = json["fileNo"].str
        totalArea = json["totalArea"].double
        ownerName = json["ownerName"].str
        fatherName = json["fatherName"].str
        houseNo = json["houseNo"].str
        address = json["address"].str
        assessmentDate = json["assessmentDate"].str
        propertyId = json["propertyId"].str
        ackNo = json["ackNo"].str?.trimmingCharacters(in: .whitespacesAndNewlines)
        roadLocationId = json["roadLocationId"].str
        oldArv = json["oldArv"].str
    }
}

// MARK: - Application detail ("See Details")

struct AssessmentApplicationDetailResponse {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let data: AssessmentApplicationDetailData?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        data = json["data"].object != nil ? AssessmentApplicationDetailData(json: json["data"]!) : nil
    }
}

struct AssessmentApplicationDetailData {
    let ulbId: Int?
    let propertyId: String?
    let ackId: String?
    let totalArv: String?
    let netArv: String?
    let oldArv: String?
    let assessDate: String?
    let status: String?
    let assessType: String?
    let enteredTs: String?
    let enteredBy: String?
    let assessOrderNo: String?
    let assessOrderIssuedBy: String?
    let assessOrderTs: String?
    let rebateType: String?
    let rebateDate: String?
    let roadLocationName: String?
    let fileNo: String?
    let totalAreaOfProperty: String?
    let propertyTypeName: String?
    let natureHouseName: String?
    let detail: String?
    let ownerName: String?
    let fatherName: String?
    let mobile: String?
    let email: String?
    let houseNo: String?
    let address: String?
    let landmark: String?
    let popName: String?
    let zoneName: String?
    let wardName: String?
    let mohallaName: String?
    let currentTax: String?
    let arrear: String?
    let interest: String?
    let modifiedCurrentTax: String?
    let waterTax: String?
    let waterTaxArrear: String?
    let waterTaxInterest: String?
    let sewerageTax: String?
    let sewerageTaxArrear: String?
    let sewerageTaxInterest: String?
    let waterCharge: String?
    let waterChargeArrear: String?
    let waterChargeInterest: String?
    let garbageTax: String?
    let garbageTaxArrear: String?
    let garbageTaxInterest: String?

    /// Numeric value of a raw API string, nil for placeholders like '-' / 'NA'.
    static func asNumber(_ value: String?) -> Double? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: ""))
    }

    init(json: JSON) {
        ulbId = json["ulbId"].int
        propertyId = json["propertyId"].str
        ackId = json["ackId"].str
        totalArv = json["totalArv"].str
        netArv = json["netArv"].str
        oldArv = json["oldArv"].str
        assessDate = json["assessDate"].str
        status = json["status"].str
        assessType = json["assessType"].str
        enteredTs = json["enteredTs"].str
        enteredBy = json["enteredBy"].str
        assessOrderNo = json["assessOrderNo"].str
        assessOrderIssuedBy = json["assessOrderIssuedBy"].str
        assessOrderTs = json["assessOrderTs"].str
        rebateType = json["rebateType"].str
        rebateDate = json["rebateDate"].str
        roadLocationName = json["roadLocationName"].str
        fileNo = json["fileNo"].str
        totalAreaOfProperty = json["totalAreaOfProperty"].str
        propertyTypeName = json["propertyTypeName"].str
        natureHouseName = json["natureHouseName"].str
        detail = json["detail"].str
        ownerName = json["ownerName"].str
        fatherName = json["fatherName"].str
        mobile = json["mobile"].str
        email = json["email"].str
        houseNo = json["houseNo"].str
        address = json["address"].str
        landmark = json["landmark"].str
        popName = json["popName"].str
        zoneName = json["zoneName"].str
        wardName = json["wardName"].str
        mohallaName = json["mohallaName"].str
        currentTax = json["currentTax"].str
        arrear = json["arrear"].str
        interest = json["interest"].str
        modifiedCurrentTax = json["modifiedCurrentTax"].str
        waterTax = json["waterTax"].str
        waterTaxArrear = json["waterTaxArrear"].str
        waterTaxInterest = json["waterTaxInterest"].str
        sewerageTax = json["sewerageTax"].str
        sewerageTaxArrear = json["sewerageTaxArrear"].str
        sewerageTaxInterest = json["sewerageTaxInterest"].str
        waterCharge = json["waterCharge"].str
        waterChargeArrear = json["waterChargeArrear"].str
        waterChargeInterest = json["waterChargeInterest"].str
        garbageTax = json["garbageTax"].str
        garbageTaxArrear = json["garbageTaxArrear"].str
        garbageTaxInterest = json["garbageTaxInterest"].str
    }
}
