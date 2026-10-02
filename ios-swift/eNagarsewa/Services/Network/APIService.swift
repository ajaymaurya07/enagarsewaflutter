import Foundation

/// A file attached to a multipart request.
struct UploadFile {
    let data: Data
    let filename: String
}

/// Port of lib/services/api_service.dart: every endpoint, header set and request body matches
/// the Flutter app. Authenticated calls retry once after a token refresh on 403 and tear the
/// session down when that fails; payment calls carry an `X-Integrity-Token` and retry once on 412.
final class APIService {

    static let shared = APIService()
    private let network = NetworkService.shared
    private init() {}

    // MARK: - Headers

    private var appVersion: String { AppConstants.buildNumber }
    private var deviceId: String { DeviceSecurityService.shared.deviceId }

    /// Dart `_getHeaders()`.
    private func authHeaders() -> [String: String] {
        var headers = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-App-Version": appVersion,
            "X-Device-Id": deviceId,
            "device_id": deviceId,
        ]
        if let token = StorageService.accessToken { headers["Authorization"] = "Bearer \(token)" }
        return headers
    }

    /// Headers used by the unauthenticated auth/sign-up endpoints.
    private func publicHeaders(includeDeviceId: Bool = false) -> [String: String] {
        var headers = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-App-Version": appVersion,
        ]
        if includeDeviceId { headers["X-Device-Id"] = deviceId }
        return headers
    }

    // MARK: - Request policies

    /// Dart `_makeAuthenticatedRequest` / `_makeAuthenticatedMultipartRequest`.
    private func authorized(_ build: ([String: String]) -> URLRequest) async throws -> HTTPResult {
        var result = try await network.send(build(authHeaders()))
        guard result.statusCode == 403 else { return result }

        guard let refresh = StorageService.refreshToken else {
            await SessionManager.shared.expireSession()
            return result
        }
        do {
            let refreshed = try await refreshToken(refresh)
            if refreshed.status == true, let token = refreshed.accessToken {
                StorageService.updateAccessToken(token)
                result = try await network.send(build(authHeaders()))
                if result.statusCode == 403 { await SessionManager.shared.expireSession() }
            } else {
                await SessionManager.shared.expireSession()
            }
        } catch {
            await SessionManager.shared.expireSession()
        }
        return result
    }

    /// Dart `_makeIntegrityProtectedRequest`.
    private func integrityProtected(_ build: @escaping ([String: String]) -> URLRequest) async throws -> HTTPResult {
        let failure = APIError.message("Device integrity check failed. Payment cannot be processed on this device.")
        guard let token = await IntegrityService.shared.getValidToken() else { throw failure }

        func execute(_ integrityToken: String) async throws -> HTTPResult {
            try await authorized { headers in
                var headers = headers
                headers["X-Integrity-Token"] = integrityToken
                return build(headers)
            }
        }

        var result = try await execute(token)
        if isIntegrityTokenExpired(result) {
            guard let fresh = await IntegrityService.shared.refreshIntegrityToken() else { throw failure }
            result = try await execute(fresh)
        }
        return result
    }

    private func isIntegrityTokenExpired(_ result: HTTPResult) -> Bool {
        if result.statusCode == 412 { return true }
        return (try? result.json())?["status_code"].str == "412"
    }

    /// 200 → parsed body, anything else → `APIError.server`.
    private func ok(_ result: HTTPResult) throws -> JSON {
        guard result.statusCode == 200 else { throw APIError.server(result.statusCode) }
        return try result.json()
    }

    /// Dart `_userSafeException` wrapper.
    private func safe<T>(_ body: () async throws -> T) async throws -> T {
        do { return try await body() } catch { throw APIError.sanitized(error) }
    }

    private func get(_ path: String) async throws -> JSON {
        try ok(await authorized { network.getRequest(path, headers: $0) })
    }

    private func post(_ path: String, _ body: [String: Any]? = [:]) async throws -> JSON {
        try ok(await authorized { network.postRequest(path, headers: $0, json: body) })
    }

    private func multipart(_ path: String, _ parts: [MultipartPart]) async throws -> JSON {
        try ok(await authorized { network.multipartRequest(path, headers: $0, parts: parts) })
    }

    /// `{success, data: [...]}` list endpoints that throw the server message on failure.
    private func list<T>(_ json: JSON, failure: String?, _ make: (JSON) -> T) throws -> [T] {
        if json["success"].isTrue, let items = json["data"].array {
            return items.map(make)
        }
        if let failure { throw APIError.message(json["message"].str ?? failure) }
        return []
    }

    // MARK: - Grievance

    func saveGrievance(ulbId: String, zoneId: String, wardId: String, mohallaId: String,
                       categoryId: String, subCategoryId: String, landmark: String,
                       description: String, name: String, fatherName: String, mobileNo: String,
                       email: String, address: String, propertyId: String,
                       emailAddress: String? = nil, image: UploadFile?) async throws -> SaveGrievanceResponse {
        try await safe {
            var headers = ["Accept": "application/json", "X-App-Version": appVersion, "X-Device-Id": deviceId]
            if let token = StorageService.accessToken { headers["Authorization"] = "Bearer \(token)" }
            var parts: [MultipartPart] = [
                .field(name: "ulbId", value: ulbId), .field(name: "zoneId", value: zoneId),
                .field(name: "wardId", value: wardId), .field(name: "mohallaId", value: mohallaId),
                .field(name: "categoryId", value: categoryId), .field(name: "subCategoryId", value: subCategoryId),
                .field(name: "landmark", value: landmark), .field(name: "description", value: description),
                .field(name: "name", value: name), .field(name: "fatherName", value: fatherName),
                .field(name: "mobileNo", value: mobileNo), .field(name: "email", value: email),
                .field(name: "address", value: address), .field(name: "propertyId", value: propertyId),
            ]
            if let emailAddress { parts.append(.field(name: "email_address", value: emailAddress)) }
            if let image { parts.append(.file(name: "file", filename: image.filename, data: image.data)) }

            let result = try await network.send(network.multipartRequest("api/house_tax/saveGrievance",
                                                                        headers: headers, parts: parts))
            if result.statusCode == 403 {
                await SessionManager.shared.expireSession()
                throw APIError.message("Session expired. Please login again.")
            }
            return SaveGrievanceResponse(json: try ok(result))
        }
    }

    func getGrievanceCategories() async throws -> [GrievanceCategory] {
        try await safe {
            try list(await get("api/House_tax/grievanceCategory"), failure: "Failed to load categories",
                     GrievanceCategory.init(json:))
        }
    }

    func getGrievanceDetails(emailId: String) async throws -> GrievanceDetailsResponse {
        try await safe { GrievanceDetailsResponse(json: try await post("api/house_tax/getGrievanceDetails", ["email_id": emailId])) }
    }

    func getGrievanceStatus(grievanceNo: String) async throws -> GrievanceStatusResponse {
        try await safe { GrievanceStatusResponse(json: try await post("api/house_tax/getGrievanceStatus", ["grievanceNo": grievanceNo])) }
    }

    // MARK: - Assessment masters

    func getRebateTypeList() async throws -> RebateTypeListResponse {
        try await safe {
            let json = try await get("api/house_tax/getRebateTypeList")
            if json["success"].isTrue, let items = json["data"].array {
                return RebateTypeListResponse(responseCode: json["responseCode"].int,
                                              data: items.map(RebateType.init(json:)), message: nil)
            }
            return RebateTypeListResponse(responseCode: json["responseCode"].int, data: [], message: json["message"].str)
        }
    }

    func getFloorTypeList(floorUsageId: String) async throws -> FloorTypeListResponse {
        try await safe {
            let json = try await post("api/house_tax/getFloorTypeList", ["floorUsageId": floorUsageId])
            if json["success"].isTrue, let items = json["data"].array {
                return FloorTypeListResponse(responseCode: json["responseCode"].int,
                                             data: items.map(FloorType.init(json:)), message: nil)
            }
            return FloorTypeListResponse(responseCode: json["responseCode"].int, data: [], message: json["message"].str)
        }
    }

    func getPropertyTypeMultiplier(floorType: Int) async throws -> Double {
        try await safe {
            let json = try await post("api/house_tax/getPropertyTypeMultiplier", ["floorType": floorType])
            if json["success"].isTrue, let data = json["data"], !data.isNull {
                return Double(data.stringValue ?? "") ?? 0
            }
            throw APIError.message(json["message"].str ?? "Failed to load property type multiplier")
        }
    }

    // MARK: - Assessment (fresh)

    func submitAssessmentStep1(zoneId: Int, wardId: Int, mohallaId: Int, oldPropertyId: String,
                               totalArea: Int, ownerName: String, fatherHusbandName: String,
                               email: String, mobile: String, houseNo: String, address: String,
                               landmark: String, popularPropertyName: String) async throws -> AssessmentStep1Response {
        try await safe {
            AssessmentStep1Response(json: try await post("api/house_tax/assessmentSubmitS1", [
                "zoneId": zoneId, "wardId": wardId, "mohallaId": mohallaId, "oldPropertyId": oldPropertyId,
                "totalArea": totalArea, "ownerName": ownerName, "fatherHusbandName": fatherHusbandName,
                "email": email, "mobile": mobile, "houseNo": houseNo, "address": address,
                "landmark": landmark, "popularPropertyName": popularPropertyName,
            ]))
        }
    }

    func submitAssessmentStep2(ackNo: String, fileNo: String, roadLocationId: Int, propertyTypeId: Int,
                               propertyUseasId: Int) async throws -> AssessmentStep2Response {
        try await safe {
            AssessmentStep2Response(json: try await post("api/house_tax/assessmentSubmitS2", [
                "ackNo": ackNo, "fileNo": fileNo, "roadLocationId": roadLocationId,
                "propertyTypeId": propertyTypeId, "propertyUseasId": propertyUseasId,
            ]))
        }
    }

    private func floorBody(ackNo: String, floor: FloorInput) -> [String: Any] {
        [
            "ackNo": ackNo, "floorNumber": floor.floorNumber, "floorUsageCode": floor.floorUsageCode,
            "floorTypeId": floor.floorTypeId, "constructionTypeId": floor.constructionTypeId,
            "constructionDate": floor.constructionDate, "carpetArea": floor.carpetArea,
            "roomsPorchArea": floor.roomsPorchArea, "kitchenBalconyArea": floor.kitchenBalconyArea,
            "garageArea": floor.garageArea, "areaEnterMode": floor.areaEnterMode,
        ]
    }

    func saveFloorDetails(ackNo: String, floor: FloorInput) async throws -> SaveFloorResponse {
        try await safe { SaveFloorResponse(json: try await post("api/house_tax/assessmentSaveFloor", floorBody(ackNo: ackNo, floor: floor))) }
    }

    func deleteFloorDetails(ackNo: String, floorNumber: Int) async throws -> DeleteFloorResponse {
        try await safe {
            DeleteFloorResponse(json: try await post("api/house_tax/assessmentDeleteFloor",
                                                     ["ackNo": ackNo, "floorNumber": floorNumber]))
        }
    }

    func submitAssessmentStep3(ackNo: String, rebateFinyear: String, isRebateClaimed: String,
                               rebateTypeId: Int?) async throws -> AssessmentStep3Response {
        try await safe {
            AssessmentStep3Response(json: try await post("api/house_tax/assessmentSubmitS3", [
                "ackNo": ackNo, "rebateFinyear": rebateFinyear, "isRebateClaimed": isRebateClaimed,
                "rebateTypeId": rebateTypeId.map { $0 as Any } ?? NSNull(),
            ]))
        }
    }

    func finalizeAssessment(ackNo: String, applicationFile: UploadFile) async throws -> DeleteFloorResponse {
        try await safe {
            DeleteFloorResponse(json: try await multipart("api/house_tax/assessmentSubmitS4", [
                .field(name: "ackNo", value: ackNo),
                .file(name: "applicationFile", filename: applicationFile.filename, data: applicationFile.data),
            ]))
        }
    }

    func getAssessmentList() async throws -> ReassessmentListResponse {
        try await safe { ReassessmentListResponse(json: try await post("api/House_tax/getAssessmentList")) }
    }

    func getAssessmentApplicationDetail(ackNo: String) async throws -> AssessmentApplicationDetailResponse {
        try await safe {
            AssessmentApplicationDetailResponse(json: try await post("api/House_tax/assessmentApplicationDetail", ["ackNo": ackNo]))
        }
    }

    func deleteAssessment(ackNo: String) async throws -> AssessmentDeleteResponse {
        try await safe { AssessmentDeleteResponse(json: try await post("api/House_tax/assessmentDelete", ["ackNo": ackNo])) }
    }

    // MARK: - Reassessment

    func getReassessmentDetails(propertyId: String) async throws -> ReassessmentGetS1Response {
        try await safe { ReassessmentGetS1Response(json: try await post("api/house_tax/reassessmentGetS1", ["propertyId": propertyId])) }
    }

    func getReassessmentList() async throws -> ReassessmentListResponse {
        try await safe { ReassessmentListResponse(json: try await post("api/house_tax/getReassessmentList")) }
    }

    func initializeReassessment(propertyId: String, ackNo: String) async throws -> ReassessmentStep1Response {
        try await safe {
            ReassessmentStep1Response(json: try await post("api/house_tax/reassessmentSubmitS1",
                                                           ["propertyId": propertyId, "ackNo": ackNo]))
        }
    }

    func fetchReassessmentFloorConfig(propertyId: String, ackNo: String, fileNo: String) async throws -> AssessmentStep2Response {
        try await safe {
            AssessmentStep2Response(json: try await post("api/house_tax/reassessmentFetchFloorConfig",
                                                         ["propertyId": propertyId, "ackNo": ackNo, "fileNo": fileNo]))
        }
    }

    func saveReassessmentFloor(ackNo: String, floor: FloorInput) async throws -> SaveFloorResponse {
        try await safe { SaveFloorResponse(json: try await post("api/house_tax/reassessmentSaveFloor", floorBody(ackNo: ackNo, floor: floor))) }
    }

    func deleteReassessmentFloor(ackNo: String, floorNumber: Int) async throws -> DeleteFloorResponse {
        try await safe {
            DeleteFloorResponse(json: try await post("api/house_tax/reassessmentDeleteFloor",
                                                     ["ackNo": ackNo, "floorNumber": floorNumber]))
        }
    }

    func submitReassessmentStep3(ackNo: String, propertyId: String, rebateFinyear: String,
                                 isRebateClaimed: String, rebateTypeId: Int?) async throws -> AssessmentStep3Response {
        try await safe {
            AssessmentStep3Response(json: try await post("api/house_tax/reassessmentSubmitS3", [
                "ackNo": ackNo, "propertyId": propertyId, "rebateFinyear": rebateFinyear,
                "isRebateClaimed": isRebateClaimed, "rebateTypeId": rebateTypeId.map { $0 as Any } ?? NSNull(),
            ]))
        }
    }

    func finalizeReassessment(ackNo: String, applicationFile: UploadFile) async throws -> DeleteFloorResponse {
        try await safe {
            DeleteFloorResponse(json: try await multipart("api/house_tax/reassessmentSubmitS4", [
                .field(name: "ackNo", value: ackNo),
                .file(name: "applicationFile", filename: applicationFile.filename, data: applicationFile.data),
            ]))
        }
    }

    // MARK: - Locations

    func getUlbData() async throws -> [UlbData] {
        try await safe { try list(await get("api/House_tax/ulbdata"), failure: "Failed to load ULB data", UlbData.init(json:)) }
    }

    func getZoneData(ulbId: String) async throws -> [ZoneData] {
        try await safe { try list(await get("api/House_tax/zonedata/\(ulbId)"), failure: nil, ZoneData.init(json:)) }
    }

    func getUlbLanguage() async throws -> UlbLanguageResponse {
        try await safe { UlbLanguageResponse(json: try await get("api/House_tax/getUlbLanguage")) }
    }

    func getWardData(ulbId: String, zoneId: String) async throws -> [WardData] {
        try await safe { try list(await get("api/House_tax/warddata/\(ulbId)/\(zoneId)"), failure: nil, WardData.init(json:)) }
    }

    func getMohallaData(ulbId: String, zoneId: String, wardId: String) async throws -> [MohallaData] {
        try await safe {
            try list(await get("api/House_tax/mohalladata/\(ulbId)/\(zoneId)/\(wardId)"), failure: nil, MohallaData.init(json:))
        }
    }

    // MARK: - Water & sewerage

    func getPipeSize(categoryConnection: String, plotArea: String) async throws -> PipeSizeResponse {
        try await safe {
            PipeSizeResponse(json: try await post("api/House_tax/fetchPipeSize",
                                                  ["categoryConnection": categoryConnection, "plotArea": plotArea]))
        }
    }

    func submitConnection(fields: [(String, String)], selfPhoto: UploadFile, idProofDocument: UploadFile,
                          propertyProofDocument: UploadFile) async throws -> SubmitConnectionResponse {
        try await safe {
            var parts = fields.map { MultipartPart.field(name: $0.0, value: $0.1) }
            parts.append(.file(name: "selfPhoto", filename: selfPhoto.filename, data: selfPhoto.data))
            parts.append(.file(name: "idProofDocument", filename: idProofDocument.filename, data: idProofDocument.data))
            parts.append(.file(name: "propertyProofDocument", filename: propertyProofDocument.filename,
                               data: propertyProofDocument.data))
            return SubmitConnectionResponse(json: try await multipart("api/House_tax/submitWaterConnection", parts))
        }
    }

    func getWaterConnectionList() async throws -> WaterConnectionListResponse {
        try await safe { WaterConnectionListResponse(json: try await get("api/House_tax/getWaterConnectionList")) }
    }

    func getWaterConnectionDetails(id: String, ackNo: String) async throws -> WaterConnectionDetailsResponse {
        try await safe {
            let idValue: Any = Int(id) ?? id
            return WaterConnectionDetailsResponse(json: try await post("api/House_tax/getWaterConnectionDetails",
                                                                       ["id": idValue, "ackNo": ackNo]))
        }
    }

    /// Downloads a signed document link. Only https links on the API host are accepted so a
    /// tampered URL in the response cannot point the app at an arbitrary server.
    func downloadWaterConnectionDocument(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString), url.scheme == "https",
              url.host == URL(string: AppConstants.baseURL)?.host else {
            throw APIError.message("This document link is not supported.")
        }
        return try await safe {
            let result = try await network.send(URLRequest(url: url))
            if result.statusCode == 200 { return result.data }
            // 401/403 here means the signed link expired — not that the session is gone.
            throw APIError.message(result.statusCode == 401 || result.statusCode == 403
                ? "This document link has expired. Please try again."
                : "Could not download the document (\(result.statusCode)).")
        }
    }

    // MARK: - Mutation

    func getMutationPropertyData(propertyId: String) async throws -> MutationPropertyDataResponse {
        try await safe {
            MutationPropertyDataResponse(json: try await post("api/House_tax/mutation/get-property-data",
                                                              ["propertyId": propertyId]))
        }
    }

    func getMutationFees(ulbId: String, propertyCost: String, mutationCause: String, currentArv: String,
                         registryDate: String) async throws -> MutationFeesResponse {
        try await safe {
            MutationFeesResponse(json: try await post("api/House_tax/mutation/fees", [
                "ulbId": Self.intOrString(ulbId), "propertyCost": Self.numOrString(propertyCost),
                "mutationCause": Self.intOrString(mutationCause), "currentArv": Self.numOrString(currentArv),
                "registryDate": registryDate,
            ]))
        }
    }

    func applyMutation(data: [String: Any], files: [(field: String, file: UploadFile)]) async throws -> MutationApplyResponse {
        try await safe {
            let payload = try JSONSerialization.data(withJSONObject: data)
            var parts: [MultipartPart] = [.json(name: "data", data: payload)]
            parts += files.map { .file(name: $0.field, filename: $0.file.filename, data: $0.file.data) }
            return MutationApplyResponse(json: try await multipart("api/House_tax/mutation/apply", parts))
        }
    }

    func getMutationApplicationDetail(ackNo: String) async throws -> MutationApplicationDetailResponse {
        try await safe {
            let encoded = ackNo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ackNo
            return MutationApplicationDetailResponse(json: try await post("api/House_tax/mutation/app-details/\(encoded)", nil))
        }
    }

    static func intOrString(_ s: String) -> Any { Int(s) ?? s }
    static func numOrString(_ s: String) -> Any { Int(s).map { $0 as Any } ?? Double(s).map { $0 as Any } ?? s }

    // MARK: - Property

    func searchProperty(ulbId: String, searchType: String, propertyId: String = "", ownerName: String = "",
                        fatherName: String = "", mobileNo: String = "", zoneId: String = "",
                        wardId: String = "", mohallaId: String = "", chukNo: String = "",
                        houseNo: String = "") async throws -> [PropertyData] {
        try await safe {
            let json = try await post("api/House_tax/propertysearch", [
                "propertyId": propertyId, "ownerName": ownerName, "fatherName": fatherName,
                "mobileNo": mobileNo, "zoneId": zoneId, "wardId": wardId, "mohallaId": mohallaId,
                "chukNo": chukNo, "houseNo": houseNo, "ulbId": ulbId, "searchType": searchType,
            ])
            return try list(json, failure: nil, PropertyData.init(json:))
        }
    }

    func getPropertyDetails(propertyId: String) async throws -> PropertyDetailsResponse {
        try await safe { PropertyDetailsResponse(json: try await post("api/House_tax/propertydetails", ["propertyId": propertyId])) }
    }

    func getArvChangeHistory(propertyId: String) async throws -> ArvChangeHistoryResponse {
        try await safe { ArvChangeHistoryResponse(json: try await post("api/house_tax/getArvChangeHistory", ["propertyId": propertyId])) }
    }

    // MARK: - Property OTP

    func sendOtp(mobileNo: String, propertyId: String) async throws -> SendOtpResponse {
        try await safe { SendOtpResponse(json: try await post("api/house_tax/sendOtp", ["mobileNo": mobileNo, "propertyId": propertyId])) }
    }

    func verifyOtp(mobileNo: String, otp: String) async throws -> VerifyOtpResponse {
        try await safe { VerifyOtpResponse(json: try await post("api/house_tax/verifyOtp", ["mobileNo": mobileNo, "otp": otp])) }
    }

    // MARK: - Payment

    func initiateTransaction(_ request: InitiateTransactionRequest) async throws -> CreateTransactionResponse {
        try await safe {
            CreateTransactionResponse(json: try ok(await integrityProtected { [network] headers in
                network.postRequest("api/Payment/create_transaction", headers: headers, json: request.json)
            }))
        }
    }

    func createSbiTransaction(_ request: InitiateTransactionRequest) async throws -> CreateSbiTransactionResponse {
        try await safe {
            CreateSbiTransactionResponse(json: try ok(await integrityProtected { [network] headers in
                network.postRequest("api/Payment/create_sbi_transaction", headers: headers, json: request.json)
            }))
        }
    }

    /// Cross-verifies a PayU transaction after the SDK callback (multipart, no refresh retry).
    func getTransactionDetails(mobileTransactionId: String) async throws -> PayUTransactionDetailsResponse {
        try await safe {
            let result = try await network.send(network.multipartRequest(
                "api/payment/getTransactionDetails", headers: paymentVerifyHeaders(),
                parts: [.field(name: "mobile_transaction_id", value: mobileTransactionId)]))
            guard result.statusCode == 200 else { throw APIError.server(result.statusCode) }
            guard !result.data.isEmpty else { throw APIError.message("Empty response from server") }
            return PayUTransactionDetailsResponse(json: try result.json())
        }
    }

    func getSbiTransactionDetails(mobileTransactionId: String) async throws -> SbiTransactionDetailsResponse {
        try await safe {
            let result = try await network.send(network.multipartRequest(
                "api/Payment/getSbiTransactionDetails", headers: paymentVerifyHeaders(),
                parts: [.field(name: "mobile_transaction_id", value: mobileTransactionId)]))
            return SbiTransactionDetailsResponse(json: try ok(result))
        }
    }

    private func paymentVerifyHeaders() -> [String: String] {
        [
            "Authorization": StorageService.accessToken.map { "Bearer \($0)" } ?? "",
            "X-App-Version": appVersion,
            "X-Device-Id": deviceId,
        ]
    }

    /// PayU hash round trip (form-urlencoded `hashName` + `hashString`).
    func generateHash(hashName: String, hashString: String) async throws -> HashResponse {
        try await safe {
            let result = try await authorized { [network] headers in
                network.formRequest("api/Payment/generate_hash", headers: headers,
                                    fields: [("hashName", hashName), ("hashString", hashString)])
            }
            if result.statusCode == 403 {
                await SessionManager.shared.expireSession()
                throw APIError.message("Session expired. Please login again.")
            }
            return HashResponse(json: try ok(result))
        }
    }

    func getTransactionsByEmail(emailId: String) async throws -> TransactionsByEmailResponse {
        try await safe {
            TransactionsByEmailResponse(json: try await post("api/payment/get_transactions_by_email", ["email_id": emailId]))
        }
    }

    // MARK: - Auth: password login (secure challenge)

    func secureLogin(username: String, password: String) async throws -> LoginResponse {
        let headers = publicHeaders()
        let challengeResult = try await network.send(network.postRequest(
            "api/house_tax/get_challenge", headers: headers, json: ["username": username, "device_id": deviceId]))
        guard challengeResult.statusCode == 200 else { throw APIError.server(challengeResult.statusCode) }
        let challenge = try challengeResult.json()
        guard challenge["status"].isTrue else {
            throw APIError.message(challenge["message"].str ?? "Challenge generation failed")
        }
        let challengeId = challenge["data"]?["challenge_id"].strOrEmpty ?? ""
        let challengeText = challenge["data"]?["challenge"].strOrEmpty ?? ""
        let timestamp = challenge["data"]?["timestamp"].strOrEmpty ?? ""
        let nonce = Self.hexNonce(16)
        let finalHash = (password.sha512 + challengeText + timestamp + nonce).sha512

        let loginResult = try await network.send(network.postRequest("api/house_tax/login", headers: headers, json: [
            "username": username, "device_id": deviceId, "challenge_id": challengeId,
            "timestamp": timestamp, "nonce": nonce, "hash": finalHash,
        ]))
        guard loginResult.statusCode == 200 else { throw APIError.server(loginResult.statusCode) }
        let response = LoginResponse(json: try loginResult.json())
        if response.success, let data = response.data { StorageService.saveLoginData(data) }
        return response
    }

    private static func hexNonce(_ length: Int) -> String {
        let chars = Array("0123456789abcdef")
        return String((0..<length).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }

    // MARK: - Auth: OTP login

    func otpLoginSendOtp(mobileNo: String) async throws -> OtpLoginSendOtpResponse {
        let result = try await network.send(network.postRequest(
            "api/Otp_login/send_otp", headers: publicHeaders(includeDeviceId: true), json: ["mobile_no": mobileNo]))
        guard result.statusCode == 200 else { throw APIError.server(result.statusCode) }
        return OtpLoginSendOtpResponse(json: try result.json())
    }

    /// On success persists the session exactly like Dart (tokens, ULB cache, login mobile).
    func otpLoginVerifyOtp(mobileNo: String, otp: String) async throws -> OtpLoginVerifyOtpResponse {
        let result = try await network.send(network.postRequest(
            "api/Otp_login/verify_otp", headers: publicHeaders(includeDeviceId: true),
            json: ["mobile_no": mobileNo, "otp": otp]))
        guard result.statusCode == 200 else { throw APIError.server(result.statusCode) }
        let response = OtpLoginVerifyOtpResponse(json: try result.json())
        if response.status, let data = response.data {
            StorageService.saveLoginData(SignIn(accessToken: data.accessToken, refreshToken: data.refreshToken,
                                                emailId: data.emailId, userType: data.userType, userId: data.userId))
            if let ulbId = data.ulbId, !ulbId.isEmpty { StorageService.saveUlbCache(ulbId) }
            let loginMobile = data.mobile?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            StorageService.saveLoginMobile(loginMobile.isEmpty
                ? mobileNo.trimmingCharacters(in: .whitespacesAndNewlines) : loginMobile)
        }
        return response
    }

    // MARK: - Auth: forgot password

    func forgotPasswordSendOtp(username: String) async throws -> ForgotPasswordResponse {
        let result = try await network.send(network.postRequest(
            "api/house_tax/forgot_password_request", headers: publicHeaders(), json: ["username": username]))
        guard result.statusCode == 200 else { throw APIError.server(result.statusCode) }
        return ForgotPasswordResponse(json: try result.json())
    }

    func resetPassword(username: String, otp: String, newPassword: String) async throws -> VerifyForgotPasswordOtpResponse {
        let hashed = newPassword.sha512
        let result = try await network.send(network.postRequest(
            "api/house_tax/verify_forgot_password_otp", headers: publicHeaders(),
            json: ["username": username, "otp": otp, "new_password": hashed, "confirm_password": hashed]))
        guard result.statusCode == 200 else { throw APIError.server(result.statusCode) }
        return VerifyForgotPasswordOtpResponse(json: try result.json())
    }

    // MARK: - Citizen self-registration

    func getSignupCaptcha() async throws -> CaptchaResponse {
        try await safe {
            let result = try await network.send(network.getRequest("api/Signup_citizen/captcha", headers: publicHeaders()))
            let json = try ok(result)
            if json["success"].isTrue, let data = json["data"], data.objectValue != nil {
                return CaptchaResponse(json: data)
            }
            throw APIError.message(json["message"].str ?? "Failed to load captcha")
        }
    }

    func getSignupCities(ulbTypeCode: String) async throws -> [SignupCity] {
        try await safe {
            let result = try await network.send(network.getRequest("api/Signup_citizen/cities?type=\(ulbTypeCode)",
                                                                   headers: publicHeaders()))
            return try list(try ok(result), failure: "Failed to load cities", SignupCity.init(json:))
        }
    }

    func registerCitizen(name: String, fatherHusbandName: String, address1: String, address2: String,
                         ulbType: String, city: Int, mobileNo: String, email: String,
                         encryptedPassword: String, encryptedConfirmPassword: String,
                         captchaId: String, captcha: String) async throws -> CitizenRegisterResponse {
        try await safe {
            let result = try await network.send(network.postRequest("api/Signup_citizen/register", headers: publicHeaders(), json: [
                "name": name, "fatherHusbandName": fatherHusbandName, "address1": address1, "address2": address2,
                "ulbType": ulbType, "city": city, "mobileNo": mobileNo, "email": email,
                "encryptedPassword": encryptedPassword, "encryptedConfirmPassword": encryptedConfirmPassword,
                "captchaId": captchaId, "captcha": captcha,
            ]))
            return CitizenRegisterResponse(json: try ok(result))
        }
    }

    func resendSignupOtp(mobileNo: String, captchaId: String, captcha: String) async throws -> ResendSignupOtpResponse {
        try await safe {
            let result = try await network.send(network.postRequest("api/Signup_citizen/resend_otp", headers: publicHeaders(),
                                                                    json: ["mobileNo": mobileNo, "captchaId": captchaId, "captcha": captcha]))
            return ResendSignupOtpResponse(json: try ok(result))
        }
    }

    func verifyCitizenOtp(mobileNo: String, otp: String) async throws -> CitizenVerifyOtpResponse {
        try await safe {
            let result = try await network.send(network.postRequest("api/Signup_citizen/verify_otp", headers: publicHeaders(),
                                                                    json: ["mobileNo": mobileNo, "otp": otp]))
            return CitizenVerifyOtpResponse(json: try ok(result))
        }
    }

    func signUp(name: String, mobileNo: String, email: String, password: String) async throws -> SignUpResponse {
        try await safe {
            let result = try await network.send(network.postRequest("api/house_tax/signup", headers: publicHeaders(), json: [
                "name": name, "mobile_no": mobileNo, "email": email, "password": password.sha512,
            ]))
            return SignUpResponse(json: try ok(result))
        }
    }

    /// Dart rethrows here, so a non-200 reaches the screen as a technical error (screen fallback).
    func verifyOtpEmail(email: String, otp: String) async throws -> VerifyOtpMailResponse {
        let result = try await network.send(network.postRequest("api/house_tax/verifyOtpEmail", headers: publicHeaders(),
                                                                json: ["email": email, "otp": otp]))
        guard result.statusCode == 200 else { throw APIError.server(result.statusCode) }
        return VerifyOtpMailResponse(json: try result.json())
    }

    // MARK: - Session

    func logout() async throws -> LogoutResponse {
        try await safe { LogoutResponse(json: try await post("api/house_tax/logout", nil)) }
    }

    func refreshToken(_ refreshToken: String) async throws -> RefreshTokenResponse {
        try await safe {
            let result = try await network.send(network.postRequest("api/house_tax/refreshToken", headers: publicHeaders(),
                                                                    json: ["refresh_token": refreshToken]))
            return RefreshTokenResponse(json: try ok(result))
        }
    }
}

/// Floor payload shared by the assessment and reassessment "save floor" endpoints.
struct FloorInput {
    let floorNumber: Int
    let floorUsageCode: String
    let floorTypeId: Int
    let constructionTypeId: Int
    let constructionDate: String
    let carpetArea: Int
    let roomsPorchArea: Int
    let kitchenBalconyArea: Int
    let garageArea: Int
    let areaEnterMode: String
}
