import Foundation

// Ports of the water & sewerage connection and property mutation models in
// lib/services/api_service.dart.

// MARK: - Water & sewerage

struct PipeSizeResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    /// Pipe size in mm (e.g. "15"), or nil when the backend could not derive one.
    let data: String?

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        let size = json["data"].str?.trimmingCharacters(in: .whitespacesAndNewlines)
        data = (size?.isEmpty ?? true) ? nil : size
    }
}

struct SubmitConnectionResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    /// Acknowledgement number (e.g. "WC05620262703550"), absent on failure.
    let ackNo: String?

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        let ack = json["data"]?.objectValue != nil ? json["data"]?["ackNo"].str : nil
        ackNo = (ack?.isEmpty ?? true) ? nil : ack
    }
}

struct WaterConnectionListItem {
    let id: String
    let ackNo: String
    let propertyId: String
    let applicantName: String
    let mobileNo: String
    let connectionType: String
    let connectionRequirement: String
    let connectionCategory: String
    let pipeSize: String
    let status: String
    let createdAt: String

    init(json: JSON) {
        id = json["id"].strOrEmpty
        ackNo = json["ack_no"].strOrEmpty
        propertyId = json["property_id"].strOrEmpty
        applicantName = json["applicant_name"].strOrEmpty
        mobileNo = json["mobile_no"].strOrEmpty
        connectionType = json["connection_type"].strOrEmpty
        connectionRequirement = json["connection_requirement"].strOrEmpty
        connectionCategory = json["connection_category"].strOrEmpty
        pipeSize = json["pipe_size"].strOrEmpty
        status = json["status"].strOrEmpty
        createdAt = json["created_at"].strOrEmpty
    }
}

struct WaterConnectionListResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    let data: [WaterConnectionListItem]

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        data = json["data"].objects(WaterConnectionListItem.init(json:))
    }
}

/// A short-lived signed link to one of the uploaded application documents.
struct WaterConnectionDocument {
    let url: String
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() > expiresAt
    }

    static func from(_ json: JSON?) -> WaterConnectionDocument? {
        guard let json, json.objectValue != nil,
              let url = json["url"].str, !url.isEmpty else { return nil }
        return WaterConnectionDocument(url: url, expiresAt: DateParsing.iso8601(json["expiresAt"].str))
    }
}

struct WaterConnectionDetails {
    let id: String
    let ackNo: String
    let propertyId: String
    let applicantName: String
    let relationType: String
    let fatherHusbandName: String
    let mobileNo: String
    let newZoneId: String
    let newWardId: String
    let newMohallaId: String
    let newPlotNo: String
    let newStreet: String
    let newLandmark: String
    let corrZoneId: String
    let corrWardId: String
    let corrMohallaId: String
    let corrPlotNo: String
    let corrStreet: String
    let corrLandmark: String
    let connectionType: String
    let connectionRequirement: String
    let plotArea: String
    let connectionCategory: String
    let pipeSize: String
    let idProofType: String
    let propertyProofType: String
    let status: String
    let responseMessage: String
    let createdAt: String
    let updatedAt: String
    let selfPhoto: WaterConnectionDocument?
    let idProofDocument: WaterConnectionDocument?
    let propertyProofDocument: WaterConnectionDocument?

    init(json: JSON) {
        id = json["id"].strOrEmpty
        ackNo = json["ack_no"].strOrEmpty
        propertyId = json["property_id"].strOrEmpty
        applicantName = json["applicant_name"].strOrEmpty
        relationType = json["relation_type"].strOrEmpty
        fatherHusbandName = json["father_husband_name"].strOrEmpty
        mobileNo = json["mobile_no"].strOrEmpty
        newZoneId = json["new_zone_id"].strOrEmpty
        newWardId = json["new_ward_id"].strOrEmpty
        newMohallaId = json["new_mohalla_id"].strOrEmpty
        newPlotNo = json["new_plot_no"].strOrEmpty
        newStreet = json["new_street"].strOrEmpty
        newLandmark = json["new_landmark"].strOrEmpty
        corrZoneId = json["corr_zone_id"].strOrEmpty
        corrWardId = json["corr_ward_id"].strOrEmpty
        corrMohallaId = json["corr_mohalla_id"].strOrEmpty
        corrPlotNo = json["corr_plot_no"].strOrEmpty
        corrStreet = json["corr_street"].strOrEmpty
        corrLandmark = json["corr_landmark"].strOrEmpty
        connectionType = json["connection_type"].strOrEmpty
        connectionRequirement = json["connection_requirement"].strOrEmpty
        plotArea = json["plot_area"].strOrEmpty
        connectionCategory = json["connection_category"].strOrEmpty
        pipeSize = json["pipe_size"].strOrEmpty
        idProofType = json["id_proof_type"].strOrEmpty
        propertyProofType = json["property_proof_type"].strOrEmpty
        status = json["status"].strOrEmpty
        responseMessage = json["response_message"].strOrEmpty
        createdAt = json["created_at"].strOrEmpty
        updatedAt = json["updated_at"].strOrEmpty
        let documents = json["documents"]
        selfPhoto = WaterConnectionDocument.from(documents?["selfPhoto"])
        idProofDocument = WaterConnectionDocument.from(documents?["idProofDocument"])
        propertyProofDocument = WaterConnectionDocument.from(documents?["propertyProofDocument"])
    }
}

struct WaterConnectionDetailsResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    let data: WaterConnectionDetails?

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        data = json["data"].object != nil ? WaterConnectionDetails(json: json["data"]!) : nil
    }
}

// MARK: - Property mutation

/// Basic property/owner details fetched before starting a mutation application, along with the
/// ULB-specific mutation-cause and ID-proof-type option lists (keyed by the id sent back).
struct MutationPropertyData {
    let propertyId: String
    let address: String
    let mobile: String
    let fatherName: String
    let ownerName: String
    let zoneId: String
    let wardId: String
    let zoneName: String
    let wardName: String
    let mohallaName: String
    let arv: String
    let causeList: OptionList
    let idList: OptionList

    init(json: JSON) {
        func value(_ key: String) -> String {
            json[key].str?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        propertyId = value("propertyId")
        address = value("address")
        mobile = value("mobile")
        fatherName = value("fatherName")
        ownerName = value("ownerName")
        zoneId = value("zoneId")
        wardId = value("wardId")
        zoneName = value("zoneName")
        wardName = value("wardName")
        mohallaName = value("mohallaName")
        arv = value("arv")
        causeList = json["causeList"].stringMap
        idList = json["idList"].stringMap
    }
}

struct MutationPropertyDataResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    let data: MutationPropertyData?

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        data = json["data"].object != nil ? MutationPropertyData(json: json["data"]!) : nil
    }
}

/// Mutation fee breakdown — `fees` is the total the applicant is asked to pay.
struct MutationFees {
    let mutationFees: String
    let lateFees: String
    let publicationFees: String
    let processingFees: String
    let ulbProcessingFees: String
    let discountRate: String
    let onlineDiscountAmount: String
    let evidence: String
    let fees: String

    init(json: JSON) {
        func value(_ key: String) -> String { json[key].str ?? "0" }
        mutationFees = value("mutationFees")
        lateFees = value("lateFees")
        publicationFees = value("publicationFees")
        processingFees = value("processingFees")
        ulbProcessingFees = value("ulbProcessingFees")
        discountRate = value("discountRate")
        onlineDiscountAmount = value("onlineDiscountAmount")
        evidence = json["evidence"].str ?? ""
        fees = value("fees")
    }
}

struct MutationFeesResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    let data: MutationFees?

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        data = json["data"].object != nil ? MutationFees(json: json["data"]!) : nil
    }
}

struct MutationApplyResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    let ackNo: String?
    let propertyId: String?
    let applicationDate: String?
    let totalFees: Double?
    let processingFees: Double?
    let residualFees: Double?

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        let data: JSON? = json["data"]?.objectValue != nil ? json["data"] : nil
        ackNo = data?["ackNo"].str
        propertyId = data?["propertyId"].str
        applicationDate = data?["applicationDate"].str
        totalFees = (data?["totalFees"]?.isNumber ?? false) ? data?["totalFees"].double : nil
        processingFees = (data?["processingFees"]?.isNumber ?? false) ? data?["processingFees"].double : nil
        residualFees = (data?["residualFees"]?.isNumber ?? false) ? data?["residualFees"].double : nil
    }
}

struct MutationApplicationDetail {
    let ackNo: String
    let ackDate: String
    let propertyId: String
    let oldOwnerName: String
    let oldFatherHusbandName: String
    let oldMobileNo: String
    let zoneName: String
    let wardName: String
    let mohallaName: String
    let oldAddress: String
    let currentArv: String
    let propertyOccupiedBy: String
    let propertyCost: String
    let registryDate: String
    let mutationCauseString: String
    let evidence: String
    let idProofType: String
    let mutationFees: String
    let lateFees: String
    let publicationFees: String
    let processingFees: String
    let ulbProcessingFees: String
    let residualFees: String
    let totalFees: String
    let amountToPayNow: String
    let occupierName: String
    let fatherHusbandName: String
    let mobileNo: String
    let alternateMobileNo: String
    let emailId: String
    let occPinCode: String
    let communicationAddress: String

    init(json: JSON) {
        func value(_ key: String) -> String { json[key].strOrEmpty }
        ackNo = value("ackNo")
        ackDate = value("ackDate")
        propertyId = value("propertyId")
        oldOwnerName = value("oldOwnerName")
        oldFatherHusbandName = value("oldFatherHusbandName")
        oldMobileNo = value("oldMobileNo")
        zoneName = value("zoneName")
        wardName = value("wardName")
        mohallaName = value("mohallaName")
        oldAddress = value("oldAddress")
        currentArv = value("currentArv")
        propertyOccupiedBy = value("propertyOccupiedBy")
        propertyCost = value("propertyCost")
        registryDate = value("registryDate")
        mutationCauseString = value("mutationCauseString")
        evidence = value("evidence")
        idProofType = value("idProofType")
        mutationFees = value("mutationFees")
        lateFees = value("lateFees")
        publicationFees = value("publicationFees")
        processingFees = value("processingFees")
        ulbProcessingFees = value("ulbProcessingFees")
        residualFees = value("residualFees")
        totalFees = value("totalFees")
        amountToPayNow = value("amountToPayNow")
        occupierName = value("occupierName")
        fatherHusbandName = value("fatherHusbandName")
        mobileNo = value("mobileNo")
        alternateMobileNo = value("alternateMobileNo")
        emailId = value("emailId")
        occPinCode = value("occPinCode")
        communicationAddress = value("communicationAddress")
    }
}

struct MutationApplicationDetailResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    let data: MutationApplicationDetail?

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        data = json["data"].object != nil ? MutationApplicationDetail(json: json["data"]!) : nil
    }
}

// MARK: - Date helpers

enum DateParsing {
    /// Lenient `DateTime.tryParse` for the ISO-8601 strings the API returns.
    static func iso8601(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: value) { return d }
        let plain = ISO8601DateFormatter()
        if let d = plain.date(from: value) { return d }
        // `yyyy-MM-dd HH:mm:ss` (no zone) — Dart parses it as local time.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let d = f.date(from: value) { return d }
        }
        return nil
    }
}
