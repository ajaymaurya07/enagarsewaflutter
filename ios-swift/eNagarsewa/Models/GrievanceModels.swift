import Foundation

// Ports of the grievance models in lib/services/api_service.dart.

struct SaveGrievanceResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    /// The grievance ID (e.g. "PG14452552"), or nil when the API returns no data.
    let data: String?

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        if case .string(let s)? = json["data"], !s.isEmpty { data = s } else { data = nil }
    }
}

struct GrievanceSubCategory: Equatable {
    let subCatCode: Int?
    let subName: String?

    init(json: JSON) {
        subCatCode = json["subCatCode"].int
        subName = json["subName"].str
    }
}

struct GrievanceCategory: Equatable {
    let serviceCode: Int?
    let serviceName: String?
    let subCategories: [GrievanceSubCategory]?

    init(json: JSON) {
        serviceCode = json["serviceCode"].int
        serviceName = json["serviceName"].str
        subCategories = json["subCategories"].array.map { $0.map(GrievanceSubCategory.init(json:)) }
    }
}

struct GrievanceDetailsResponse {
    let success: Bool?
    let message: String?
    let data: [GrievanceDetails]?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        data = json["data"].array.map { $0.map(GrievanceDetails.init(json:)) }
    }
}

struct GrievanceDetails {
    let grievanceNo: String?
    let description: String?
    let name: String?
    let fatherName: String?
    let mobileNo: String?
    let email: String?
    let updatedAt: String?
    let categoryName: String?
    let subcategoryName: String?

    init(json: JSON) {
        grievanceNo = json["grievance_no"].str
        description = json["description"].str
        name = json["name"].str
        fatherName = json["father_name"].str
        mobileNo = json["mobile_no"].str
        email = json["email"].str
        updatedAt = json["updated_at"].str
        categoryName = json["category_name"].str
        subcategoryName = json["subcategory_name"].str
    }
}

struct GrievanceStatusResponse {
    let success: Bool
    let responseCode: Int
    let message: String
    let data: [GrievanceStatusData]

    init(json: JSON) {
        success = json["success"].isTrue
        responseCode = json["responseCode"].int ?? 0
        message = json["message"].strOrEmpty
        data = (json["data"].array ?? []).map(GrievanceStatusData.init(json:))
    }
}

struct GrievanceStatusData {
    let ulbName: String?
    let mohallaName: String?
    let zoneName: String?
    let wardName: String?
    let complaintId: String?
    let complaintDate: String?
    let categoryName: String?
    let subCategoryName: String?
    let landmark: String?
    let complaintDesc: String?
    let name: String?
    let fatherHusbandName: String?
    let mobile: String?
    let email: String?
    let address1: String?
    let address2: String?
    let assignedEmpName: String?
    let assignedEmpMobile: String?
    let assignedEmpPost: String?
    let assignedOffName: String?
    let assignedOffMobile: String?
    let assignedOffPost: String?
    let status: String?
    let closeDate: String?
    let closeRemark: String?
    let complaintTime: String?
    let closeTime: String?
    let reComplain: Int?
    let dueDate: String?

    init(json: JSON) {
        ulbName = json["ulbName"].str
        mohallaName = json["mohallaName"].str
        zoneName = json["zoneName"].str
        wardName = json["wardName"].str
        complaintId = json["complaintId"].str
        complaintDate = json["complaintDate"].str
        categoryName = json["categoryName"].str
        subCategoryName = json["subCategoryName"].str
        landmark = json["landmark"].str
        complaintDesc = json["complaintDesc"].str
        name = json["name"].str
        fatherHusbandName = json["fatherHusbandName"].str
        mobile = json["mobile"].str
        email = json["email"].str
        address1 = json["address1"].str
        address2 = json["address2"].str
        assignedEmpName = json["assignedEmpName"].str
        assignedEmpMobile = json["assignedEmpMobile"].str
        assignedEmpPost = json["assignedEmpPost"].str
        assignedOffName = json["assignedOffName"].str
        assignedOffMobile = json["assignedOffMobile"].str
        assignedOffPost = json["assignedOffPost"].str
        status = json["status"].str
        closeDate = json["closeDate"].str
        closeRemark = json["closeRemark"].str
        complaintTime = json["complaintTime"].str
        closeTime = json["closeTime"].str
        reComplain = json["reComplain"].int
        dueDate = json["dueDate"].str
    }
}
