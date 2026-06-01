import Foundation

// MARK: - Categories

struct GrievanceCategoryResponse: Decodable {
    let success: Bool
    let data: [GrievanceCategory]
}

struct GrievanceCategory: Decodable, Identifiable {
    let serviceCode: String
    let serviceName: String
    let subCategories: [GrievanceSubCategory]
    var id: String { serviceCode }
}

struct GrievanceSubCategory: Decodable, Identifiable {
    let subCategoryCode: String
    let subCategoryName: String
    var id: String { subCategoryCode }
}

// MARK: - Submit grievance

struct SaveGrievanceResponse: Decodable {
    let success: Bool
    let responseCode: String?
    let message: String
    let grievanceId: String?
    let requiresOtp: Bool?
}

struct RegisterGrievanceAfterOtpRequest: Encodable {
    let grievanceId: String
    let otp: String
}

struct RegisterGrievanceAfterOtpResponse: Decodable {
    let success: Bool
    let message: String
}

// MARK: - Grievance list

struct GrievanceDetailsRequest: Encodable {
    let emailId: String
}

struct GrievanceDetailsResponse: Decodable {
    let success: Bool
    let data: [GrievanceData]
}

struct GrievanceData: Decodable, Identifiable {
    let grievanceId: String
    let grievanceNo: String?
    let serviceCode: String?
    let serviceName: String?
    let subCategoryCode: String?
    let subCategoryName: String?
    let status: String?
    let registrationDate: String?
    let description: String?
    let propertyId: String?
    var id: String { grievanceId }
}

// MARK: - Grievance status

struct GrievanceStatusRequest: Encodable {
    let grievanceNo: String
}

struct GrievanceStatusResponse: Decodable {
    let success: Bool
    let data: GrievanceStatusData?
}

struct GrievanceStatusData: Decodable {
    let grievanceId: String?
    let grievanceNo: String?
    let serviceCode: String?
    let serviceName: String?
    let subCategoryCode: String?
    let subCategoryName: String?
    let status: String?
    let registrationDate: String?
    let closureDate: String?
    let description: String?
    let assignedTo: String?
    let assignedDepartment: String?
    let remarks: String?
    let propertyId: String?
    let ownerName: String?
    let address: String?
    let wardName: String?
    let mohallaName: String?
    let zoneName: String?
    let ulbName: String?
    let applicantName: String?
    let applicantMobile: String?
    let applicantEmail: String?
    let imageUrl: String?
    let dueDate: String?
    let escalationLevel: String?
    let priorityLevel: String?
    let feedbackRating: String?
    let feedbackComment: String?
}
