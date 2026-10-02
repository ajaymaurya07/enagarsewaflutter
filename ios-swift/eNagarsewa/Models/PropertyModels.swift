import Foundation

// Ports of the location / property / bill models in lib/services/api_service.dart and the
// `PropertyEntity` row in lib/services/database_service.dart.

// MARK: - Location hierarchy

struct UlbData: Equatable {
    let ulbName: String?
    let ulbId: String?
    let ulbType: String?
    let districtId: String?
    let districtName: String?

    init(json: JSON) {
        ulbName = json["ulbName"].str
        ulbId = json["ulbId"].str
        ulbType = json["ulbType"].str
        districtId = json["districtId"].str
        districtName = json["districtName"].str
    }

    /// Dart `toString()` — used as the dropdown label.
    var displayName: String { "\(ulbName ?? "") (\(ulbType ?? ""))" }
}

struct UlbLanguageResponse {
    let success: Bool
    let message: String
    let responseCode: Int?
    let language: String?

    init(json: JSON) {
        success = json["success"].isTrue
        message = json["message"].strOrEmpty
        responseCode = json["responseCode"].int
        language = json["data"].str
    }
}

struct ZoneData: Equatable {
    let zoneName: String
    let zoneId: String

    init(zoneName: String, zoneId: String) {
        self.zoneName = zoneName
        self.zoneId = zoneId
    }

    init(json: JSON) {
        zoneName = json["zoneName"].strOrEmpty
        zoneId = json["zoneId"].strOrEmpty
    }
}

struct WardData: Equatable {
    let wardName: String
    let wardId: String

    init(wardName: String, wardId: String) {
        self.wardName = wardName
        self.wardId = wardId
    }

    init(json: JSON) {
        wardName = json["wardName"].strOrEmpty
        wardId = json["wardId"].strOrEmpty
    }
}

struct MohallaData: Equatable {
    let mohallaName: String
    let mohallaId: String

    init(mohallaName: String, mohallaId: String) {
        self.mohallaName = mohallaName
        self.mohallaId = mohallaId
    }

    init(json: JSON) {
        mohallaName = json["mohallaName"].strOrEmpty
        mohallaId = json["mohallaId"].strOrEmpty
    }
}

// MARK: - Property search

struct PropertyData {
    let oldPropertyId: String?
    let address: String?
    let ownerName: String?
    let totalArv: Double?
    let propertyType: String?
    let fatherHusbandName: String?
    let finYear: String?
    let houseNo: String?
    let chukNo: String?
    let propertyId: String?
    let billNo: String?
    let totalArea: String?
    let ulbLang: String?

    init(json: JSON) {
        oldPropertyId = json["oldPropertyId"].str
        address = json["address"].str
        ownerName = json["ownerName"].str
        totalArv = (json["totalArv"]?.isNumber ?? false) ? json["totalArv"].double : nil
        propertyType = json["propertyType"].str
        fatherHusbandName = json["fatherHusbandName"].str
        finYear = json["finYear"].str
        houseNo = json["houseNo"].str
        chukNo = json["chukNo"].str
        propertyId = json["propertyId"].str
        billNo = json["billNo"].str
        totalArea = json["totalArea"].str
        ulbLang = json["ulbLang"].str
    }
}

// MARK: - Property details

struct PropertyDetailsResponse {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let data: PropertyDetailsData?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        data = (json["data"]?.isNull ?? true) ? nil : PropertyDetailsData(json: json["data"]!)
    }
}

struct PropertyDetailsData {
    let billDetails: BillDetails?
    let ownerDetails: OwnerDetails?
    let propertyDetailsInfo: PropertyInfo?
    let currReceiptDetails: [ReceiptDetailsItem]?
    let prevReceiptDetails: [ReceiptDetailsItem]?

    init(json: JSON) {
        billDetails = json["billDetails"].object != nil ? BillDetails(json: json["billDetails"]!) : nil
        ownerDetails = json["ownerDetails"].object != nil ? OwnerDetails(json: json["ownerDetails"]!) : nil
        propertyDetailsInfo = json["propertyDetails"].object != nil ? PropertyInfo(json: json["propertyDetails"]!) : nil
        currReceiptDetails = json["currReceiptDetails"].array.map { $0.map(ReceiptDetailsItem.init(json:)) }
        prevReceiptDetails = json["prevReceiptDetails"].array.map { $0.map(ReceiptDetailsItem.init(json:)) }
    }
}

struct BillDetails {
    let sewerTaxArrear: String?
    let otherTaxMonthlyInterest: String?
    let houseTaxDiscount: String?
    let waterChargeAdvance: String?
    let houseTaxAdvance: String?
    let finYear: String?
    let othertaxNetAmount: String?
    let sewerTaxDiscount: String?
    let sewerTaxAdvance: String?
    let waterChargeMonthlyInterest: String?
    let houseTaxArrear: String?
    let sewerTaxInterest: String?
    let waterTaxMonthlyInterest: String?
    let waterTaxArrear: String?
    let otherTaxArrear: String?
    let houseCurrentTax: String?
    let waterCurrentTax: String?
    let waterTaxInterest: String?
    let netPayble: String?
    let netDemand: String?
    let otherCurrentTax: String?
    let otherTaxInterest: String?
    let sewerTaxMonthlyInterest: String?
    let billNo: String?
    let waterChargeDiscount: String?
    let waterTaxAdvance: String?
    let otherTaxAdvance: String?
    let waterTaxNetAmount: String?
    let waterTaxDiscount: String?
    let sewerTaxNetAmount: String?
    let billDate: String?
    let waterChargeArrear: String?
    let waterChargeNetAmount: String?
    let houseTaxMonthlyInterest: String?
    let houseTaxInterest: String?
    let sewerCurrentTax: String?
    let houseTaxNetAmount: String?
    let otherTaxDiscount: String?
    let waterChargeInterest: String?
    let waterChargeCurrent: String?
    let houseTaxPayable: String?
    let waterTaxPayable: String?
    let sewerTaxPayable: String?
    let otherTaxPayable: String?
    let waterChargePayable: String?

    init(json: JSON) {
        sewerTaxArrear = json["sewerTaxArrear"].str
        otherTaxMonthlyInterest = json["otherTaxMonthlyInterest"].str
        houseTaxDiscount = json["houseTaxDiscount"].str
        waterChargeAdvance = json["waterChargeAdvance"].str
        houseTaxAdvance = json["houseTaxAdvance"].str
        finYear = json["finYear"].str
        othertaxNetAmount = json["othertaxNetAmount"].str
        sewerTaxDiscount = json["sewerTaxDiscount"].str
        sewerTaxAdvance = json["sewerTaxAdvance"].str
        waterChargeMonthlyInterest = json["waterChargeMonthlyInterest"].str
        houseTaxArrear = json["houseTaxArrear"].str
        sewerTaxInterest = json["sewerTaxInterest"].str
        waterTaxMonthlyInterest = json["waterTaxMonthlyInterest"].str
        waterTaxArrear = json["waterTaxArrear"].str
        otherTaxArrear = json["otherTaxArrear"].str
        houseCurrentTax = json["houseCurrentTax"].str
        waterCurrentTax = json["waterCurrentTax"].str
        waterTaxInterest = json["waterTaxInterest"].str
        netPayble = json["netPayble"].str
        netDemand = json["netDemand"].str
        otherCurrentTax = json["otherCurrentTax"].str
        otherTaxInterest = json["otherTaxInterest"].str
        sewerTaxMonthlyInterest = json["sewerTaxMonthlyInterest"].str
        billNo = json["billNo"].str
        waterChargeDiscount = json["waterChargeDiscount"].str
        waterTaxAdvance = json["waterTaxAdvance"].str
        otherTaxAdvance = json["otherTaxAdvance"].str
        waterTaxNetAmount = json["waterTaxNetAmount"].str
        waterTaxDiscount = json["waterTaxDiscount"].str
        sewerTaxNetAmount = json["sewerTaxNetAmount"].str
        billDate = json["billDate"].str
        waterChargeArrear = json["waterChargeArrear"].str
        waterChargeNetAmount = json["waterChargeNetAmount"].str
        houseTaxMonthlyInterest = json["houseTaxMonthlyInterest"].str
        houseTaxInterest = json["houseTaxInterest"].str
        sewerCurrentTax = json["sewerCurrentTax"].str
        houseTaxNetAmount = json["houseTaxNetAmount"].str
        otherTaxDiscount = json["otherTaxDiscount"].str
        waterChargeInterest = json["waterChargeInterest"].str
        waterChargeCurrent = json["waterChargeCurrent"].str
        houseTaxPayable = json["houseTaxPayable"].str
        waterTaxPayable = json["waterTaxPayable"].str
        sewerTaxPayable = json["sewerTaxPayable"].str
        otherTaxPayable = json["otherTaxPayable"].str
        waterChargePayable = json["waterChargePayable"].str
    }
}

struct OwnerDetails {
    let ownerName: String?
    let fatherName: String?
    let mobileNo: String?

    init(json: JSON) {
        ownerName = json["ownerName"].str
        fatherName = json["fatherName"].str
        mobileNo = json["mobileNo"].str
    }
}

struct PropertyInfo {
    let address: String?
    let houseNo: String?
    let wardName: String?
    let zoneName: String?
    let mohallaName: String?
    let totalArea: String?
    let chukNo: String?
    let propertyUseAs: String?
    let propertyType: String?
    let ulbName: String?
    /// 14-digit legacy property id ("पुरानी प्रापर्टी आईडी0" on the bill).
    let oldPropertyId: String?
    /// The ULB's own pre-migration id ("पुरानी आईडी0" on the bill).
    let existingPropertyId: String?
    let dateOfAssessment: String?
    let arv: String?

    init(json: JSON) {
        address = json["address"].str
        houseNo = json["houseNo"].str
        wardName = json["wardName"].str
        zoneName = json["zoneName"].str
        mohallaName = json["mohallaName"].str
        totalArea = json["totalArea"].str
        chukNo = json["chukNo"].str
        propertyUseAs = json["propertyUseAs"].str
        ulbName = json["ulbName"].str
        propertyType = json["propertyType"].str
        oldPropertyId = json["oldPropertyId"].str
        existingPropertyId = json["existingPropertyId"].str
        dateOfAssessment = json["dateOfAssessment"].str
        arv = json["arv"].str
    }
}

struct ReceiptDetailsItem {
    let receiptNo: String?
    let billNo: String?
    let receiptDate: String?
    let paymentMode: String?
    let paymentDate: String?
    let challanId: String?
    let chequeNo: String?
    let propertyTaxNetAmount: String?
    let propertyTaxPaidAmount: String?
    let waterTaxPaidAmount: String?
    let sewerTaxPaidAmount: String?
    let otherTaxPaidAmount: String?
    let waterChargePaidAmount: String?
    /// Manual receipt book the payment was entered from ("बुक संख्या").
    let bookNo: String?

    init(json: JSON) {
        receiptNo = json["receiptNo"].str
        billNo = json["billNo"].str
        receiptDate = json["receiptDate"].str
        paymentMode = json["paymentMode"].str
        paymentDate = json["paymentDate"].str
        challanId = json["challanId"].str
        chequeNo = json["chequeNo"].str
        propertyTaxNetAmount = json["propertyTaxNetAmount"].str
        propertyTaxPaidAmount = json["propertyTaxPaidAmount"].str
        waterTaxPaidAmount = json["waterTaxPaidAmount"].str
        sewerTaxPaidAmount = json["sewerTaxPaidAmount"].str
        otherTaxPaidAmount = json["otherTaxPaidAmount"].str
        waterChargePaidAmount = json["waterChargePaidAmount"].str
        bookNo = json["bookNo"].str
    }
}

// MARK: - ARV change history

struct ArvChangeHistoryResponse {
    let success: Bool?
    let responseCode: Int?
    let message: String?
    let data: [ArvChangeHistoryItem]?

    init(json: JSON) {
        success = json["success"].bool
        responseCode = json["responseCode"].int
        message = json["message"].str
        data = json["data"].array.map { $0.map(ArvChangeHistoryItem.init(json:)) }
    }
}

struct ArvChangeHistoryItem {
    let ulbId: Int?
    let propertyId: String?
    let ownerName: String?
    let fatherHusbandName: String?
    let houseNo: String?
    let oldPropertyId: String?
    let address: String?
    let oldArv: Double?
    let currentArv: Double?
    /// Dart `'${item.oldArv ?? 0}'` text (keeps int vs double formatting).
    let oldArvText: String
    let currentArvText: String
    let ulbLanguage: String?
    let arvChangeDate: String?

    init(json: JSON) {
        ulbId = json["ulbId"].int
        propertyId = json["propertyId"].str
        ownerName = json["ownerName"].str
        fatherHusbandName = json["fatherHusbandName"].str
        houseNo = json["houseNo"].str
        oldPropertyId = json["oldPropertyId"].str
        address = json["address"].str
        oldArv = json["oldArv"].double
        currentArv = json["currentArv"].double
        oldArvText = json["oldArv"].str ?? "0"
        currentArvText = json["currentArv"].str ?? "0"
        ulbLanguage = json["ulbLanguage"].str
        arvChangeDate = json["arvChangeDate"].str
    }
}

// MARK: - Local DB row (property_table, schema v9)

struct PropertyEntity: Equatable {
    var propertyId: String
    var ownerName: String
    var ward: String
    var mohalla: String
    var phoneNumber: String
    var email: String?
    var userType: String?
    var ulbId: String?
    var arvValue: String?
    var userId: String?
    var fatherName: String?
    var address: String?
    var zone: String?
    var houseNo: String?
    var totalArea: String?
    /// propertysearch API's `oldPropertyId` — the "पुरानी प्रापर्टी आईडी0" row on the bill.
    var oldPropertyId: String?
    /// Bill due date (`dd-mm-yyyy`) cached from propertydetails `billDetails.billDate`.
    var billDate: String?
    /// Outstanding amount cached from propertydetails `billDetails.netPayble` ("0" = paid).
    var netPayable: String?
    /// propertysearch `ulbLang` — "English" or "Krutidev"; decides the owner/address font.
    var ulbLang: String?

    init(propertyId: String, ownerName: String, ward: String, mohalla: String, phoneNumber: String,
         email: String? = nil, userType: String? = nil, ulbId: String? = nil, arvValue: String? = nil,
         userId: String? = nil, fatherName: String? = nil, address: String? = nil, zone: String? = nil,
         houseNo: String? = nil, totalArea: String? = nil, oldPropertyId: String? = nil,
         billDate: String? = nil, netPayable: String? = nil, ulbLang: String? = nil) {
        self.propertyId = propertyId
        self.ownerName = ownerName
        self.ward = ward
        self.mohalla = mohalla
        self.phoneNumber = phoneNumber
        self.email = email
        self.userType = userType
        self.ulbId = ulbId
        self.arvValue = arvValue
        self.userId = userId
        self.fatherName = fatherName
        self.address = address
        self.zone = zone
        self.houseNo = houseNo
        self.totalArea = totalArea
        self.oldPropertyId = oldPropertyId
        self.billDate = billDate
        self.netPayable = netPayable
        self.ulbLang = ulbLang
    }
}
