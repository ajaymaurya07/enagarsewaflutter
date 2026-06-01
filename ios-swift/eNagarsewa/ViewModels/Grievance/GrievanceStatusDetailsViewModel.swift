import Foundation

@MainActor
final class GrievanceStatusDetailsViewModel: ObservableObject {

    let statusData: GrievanceStatusData

    init(statusData: GrievanceStatusData) {
        self.statusData = statusData
    }

    // Convenience display helpers

    var grievanceNumber: String { statusData.grievanceNo ?? "-" }
    var status: String          { statusData.status ?? "-" }
    var category: String        { statusData.serviceName ?? "-" }
    var subCategory: String     { statusData.subCategoryName ?? "-" }
    var registrationDate: String{ statusData.registrationDate ?? "-" }
    var description: String     { statusData.description ?? "-" }
    var assignedTo: String      { statusData.assignedTo ?? "Not assigned" }
    var department: String      { statusData.assignedDepartment ?? "-" }
    var remarks: String         { statusData.remarks ?? "-" }
    var ownerName: String       { statusData.ownerName ?? "-" }
    var address: String         { statusData.address ?? "-" }

    var statusColor: UIColor {
        switch statusData.status?.lowercased() {
        case "closed", "resolved": return .systemGreen
        case "pending":            return .systemOrange
        case "rejected":           return .systemRed
        default:                   return .systemBlue
        }
    }
}

import UIKit
