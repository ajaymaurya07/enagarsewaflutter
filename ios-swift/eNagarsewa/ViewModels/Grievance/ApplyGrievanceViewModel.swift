import Foundation
import UIKit

@MainActor
final class ApplyGrievanceViewModel: ObservableObject {

    @Published var categories: [GrievanceCategory] = []
    @Published var selectedCategory: GrievanceCategory?
    @Published var selectedSubCategory: GrievanceSubCategory?
    @Published var description: String = ""
    @Published var selectedImage: UIImage?
    @Published var mobileNumber: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var submittedGrievanceId: String?
    @Published var requiresOtp: Bool = false
    @Published var otp: String = ""

    let property: PropertyEntity?
    private let api = APIService.shared
    weak var coordinator: (AnyObject & GrievanceCoordinatorProtocol)?

    init(property: PropertyEntity?) {
        self.property = property
    }

    func onViewAppear() {
        Task { await loadCategories() }
    }

    private func loadCategories() async {
        do {
            categories = try await api.fetchGrievanceCategories().data
        } catch { errorMessage = message(error) }
    }

    // MARK: - Submit

    func submit() {
        guard let cat = selectedCategory, let sub = selectedSubCategory else {
            errorMessage = "Please select a category and sub-category."; return
        }
        guard !description.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please describe your grievance."; return
        }

        isLoading = true; errorMessage = nil

        Task {
            defer { isLoading = false }
            var fields: [String: String] = [
                "serviceCode":    cat.serviceCode,
                "serviceName":    cat.serviceName,
                "subCategoryCode": sub.subCategoryCode,
                "description":    description,
                "mobileNo":       mobileNumber,
            ]
            if let p = property {
                fields["propertyId"] = p.propertyId
                fields["ulbId"]      = p.ulbId
            }

            let imageData = selectedImage.flatMap { $0.jpegData(compressionQuality: 0.7) }
            do {
                let r = try await api.saveGrievance(fields: fields, imageData: imageData)
                if r.success {
                    submittedGrievanceId = r.grievanceId
                    requiresOtp = r.requiresOtp ?? false
                    if !requiresOtp { coordinator?.grievanceSubmitted() }
                } else {
                    errorMessage = r.message
                }
            } catch { errorMessage = message(error) }
        }
    }

    func verifyOtp() {
        guard let id = submittedGrievanceId else { return }
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                let r = try await api.registerGrievanceAfterOtp(
                    RegisterGrievanceAfterOtpRequest(grievanceId: id, otp: otp)
                )
                if r.success { coordinator?.grievanceSubmitted() }
                else { errorMessage = r.message }
            } catch { errorMessage = message(error) }
        }
    }

    private func message(_ e: Error) -> String {
        (e as? NetworkError)?.errorDescription ?? e.localizedDescription
    }
}

protocol GrievanceCoordinatorProtocol: AnyObject {
    func grievanceSubmitted()
}
extension GrievanceCoordinator: GrievanceCoordinatorProtocol {}
