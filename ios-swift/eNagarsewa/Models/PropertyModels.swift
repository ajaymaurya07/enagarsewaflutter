import Foundation

// MARK: - Location hierarchy

struct UlbData: Decodable, Identifiable {
    let ulbId: String
    let ulbName: String
    let ulbType: String
    let districtId: String
    let districtName: String
    var id: String { ulbId }
}

struct UlbDataResponse: Decodable {
    let success: Bool
    let data: [UlbData]
}

struct ZoneData: Decodable, Identifiable {
    let zoneId: String
    let zoneName: String
    var id: String { zoneId }
}

struct ZoneDataResponse: Decodable {
    let success: Bool
    let data: [ZoneData]
}

struct WardData: Decodable, Identifiable {
    let wardId: String
    let wardName: String
    var id: String { wardId }
}

struct WardDataResponse: Decodable {
    let success: Bool
    let data: [WardData]
}

struct MohallaData: Decodable, Identifiable {
    let mohallaId: String
    let mohallaName: String
    var id: String { mohallaId }
}

struct MohallaDataResponse: Decodable {
    let success: Bool
    let data: [MohallaData]
}

// MARK: - Property search

struct PropertySearchRequest: Encodable {
    let ulbId: String
    let zoneId: String?
    let wardId: String?
    let mohallaId: String?
    let propertyId: String?
    let ownerName: String?
    let fatherName: String?
    let mobileNumber: String?
    let houseNo: String?
    let chukNo: String?
}

struct PropertySearchResponse: Decodable {
    let success: Bool
    let data: [PropertyData]
}

struct PropertyData: Decodable, Identifiable {
    let propertyId: String
    let ownerName: String
    let address: String
    let totalArv: String?
    let propertyType: String?
    let houseNo: String?
    let chukNo: String?
    let billNo: String?
    let totalArea: String?
    let finYear: String?
    var id: String { propertyId }
}

// MARK: - Property details

struct PropertyDetailsRequest: Encodable {
    let propertyId: String
    let ulbId: String
}

struct PropertyDetailsResponse: Decodable {
    let success: Bool
    let data: PropertyDetailsData?
}

struct PropertyDetailsData: Decodable {
    let billDetails: BillDetails?
    let ownerDetails: OwnerDetails?
    let propertyDetailsInfo: PropertyInfo?
    let currReceiptDetails: [ReceiptItem]?
    let prevReceiptDetails: [ReceiptItem]?
}

struct BillDetails: Decodable {
    let billNo: String?
    let propertyId: String?
    let finYear: String?
    let totalArv: String?
    let generalTax: String?
    let waterTax: String?
    let sewerageTax: String?
    let lightTax: String?
    let conservancyTax: String?
    let fireServiceTax: String?
    let educationCess: String?
    let totalTax: String?
    let totalDiscount: String?
    let totalInterest: String?
    let totalPenalty: String?
    let totalCharge: String?
    let netPayable: String?
    let advance: String?
    let netDemand: String?
    // Additional fields from Flutter's 40+ field BillDetails
    let wardName: String?
    let mohallaName: String?
    let zoneName: String?
    let ulbName: String?
    let ownerName: String?
    let address: String?
    let propertyType: String?
    let constructionType: String?
    let occupancyType: String?
    let floorCount: String?
    let totalArea: String?
    let arvPerSqFt: String?
}

struct OwnerDetails: Decodable {
    let ownerName: String?
    let fatherName: String?
    let mobileNo: String?
    let email: String?
    let address: String?
}

struct PropertyInfo: Decodable {
    let propertyId: String?
    let houseNo: String?
    let chukNo: String?
    let roadWidth: String?
    let constructionYear: String?
    let plotArea: String?
    let builtUpArea: String?
}

struct ReceiptItem: Decodable, Identifiable {
    let receiptNo: String?
    let billNo: String?
    let date: String?
    let mode: String?
    let amount: String?
    var id: String { receiptNo ?? UUID().uuidString }
}

// MARK: - Local DB entity

struct PropertyEntity {
    let propertyId: String
    let ownerName: String
    let ward: String
    let mohalla: String
    let phoneNumber: String
    let email: String
    let userType: String
    let ulbId: String
    let arvValue: String
    let userId: String
    let fatherName: String
    let address: String
}
