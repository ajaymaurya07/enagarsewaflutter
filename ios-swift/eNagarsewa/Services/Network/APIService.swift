import Foundation

/// All 30+ API endpoint calls. Uses NetworkService for transport.
/// Handles 403 → token refresh and 412 → integrity refresh automatically.
final class APIService {

    static let shared = APIService()
    private let network   = NetworkService.shared
    private let auth      = AuthManager.shared
    private let integrity = IntegrityService.shared
    private init() {}

    // MARK: - Auth

    func getChallenge(username: String, deviceId: String) async throws -> ChallengeResponse {
        try await perform(.getChallenge, method: .POST,
                          body: ChallengeRequest(username: username, deviceId: deviceId),
                          requiresAuth: false)
    }

    func login(_ request: LoginRequest) async throws -> LoginResponse {
        try await perform(.login, method: .POST, body: request, requiresAuth: false)
    }

    func signup(_ request: SignUpRequest) async throws -> SignUpResponse {
        try await perform(.signup, method: .POST, body: request, requiresAuth: false)
    }

    func forgotPasswordRequest(email: String) async throws -> ForgotPasswordResponse {
        try await perform(.forgotPasswordRequest, method: .POST,
                          body: ForgotPasswordRequest(email: email), requiresAuth: false)
    }

    func verifyForgotPasswordOtp(_ request: VerifyForgotPasswordOtpRequest) async throws -> VerifyForgotPasswordOtpResponse {
        try await perform(.verifyForgotPasswordOtp, method: .POST, body: request, requiresAuth: false)
    }

    func logout() async throws -> LogoutResponse {
        try await perform(.logout, method: .POST)
    }

    // MARK: - OTP

    func sendOtp(phoneNumber: String, propertyId: String? = nil) async throws -> SendOtpResponse {
        try await perform(.sendOtp, method: .POST,
                          body: SendOtpRequest(phoneNumber: phoneNumber, propertyId: propertyId))
    }

    func verifyOtp(_ request: VerifyOtpRequest) async throws -> VerifyOtpResponse {
        try await perform(.verifyOtp, method: .POST, body: request)
    }

    func verifyOtpEmail(_ request: VerifyOtpMailRequest) async throws -> VerifyOtpMailResponse {
        try await perform(.verifyOtpEmail, method: .POST, body: request)
    }

    // MARK: - Property

    func fetchUlbData() async throws -> UlbDataResponse {
        try await perform(.ulbData, method: .GET)
    }

    func fetchZoneData(ulbId: String) async throws -> ZoneDataResponse {
        try await perform(.zoneData(ulbId: ulbId), method: .GET)
    }

    func fetchWardData(ulbId: String, zoneId: String) async throws -> WardDataResponse {
        try await perform(.wardData(ulbId: ulbId, zoneId: zoneId), method: .GET)
    }

    func fetchMohallaData(ulbId: String, zoneId: String, wardId: String) async throws -> MohallaDataResponse {
        try await perform(.mohallaData(ulbId: ulbId, zoneId: zoneId, wardId: wardId), method: .GET)
    }

    func searchProperty(_ request: PropertySearchRequest) async throws -> PropertySearchResponse {
        try await perform(.propertySearch, method: .POST, body: request)
    }

    func fetchPropertyDetails(_ request: PropertyDetailsRequest) async throws -> PropertyDetailsResponse {
        try await perform(.propertyDetails, method: .POST, body: request)
    }

    // MARK: - Grievance

    func fetchGrievanceCategories() async throws -> GrievanceCategoryResponse {
        try await perform(.grievanceCategory, method: .GET)
    }

    func saveGrievance(
        fields: [String: String],
        imageData: Data?
    ) async throws -> SaveGrievanceResponse {
        try await network.requestMultipart(.saveGrievance, fields: fields,
                                           fileData: imageData, requiresAuth: true)
    }

    func registerGrievanceAfterOtp(_ request: RegisterGrievanceAfterOtpRequest) async throws -> RegisterGrievanceAfterOtpResponse {
        try await perform(.registerGrievanceAfterOtp, method: .POST, body: request)
    }

    func fetchGrievanceDetails(emailId: String) async throws -> GrievanceDetailsResponse {
        try await perform(.getGrievanceDetails, method: .POST,
                          body: GrievanceDetailsRequest(emailId: emailId))
    }

    func fetchGrievanceStatus(grievanceNo: String) async throws -> GrievanceStatusResponse {
        try await perform(.getGrievanceStatus, method: .POST,
                          body: GrievanceStatusRequest(grievanceNo: grievanceNo))
    }

    // MARK: - Payment (requires integrity token)

    func createTransaction(_ request: CreateTransactionRequest) async throws -> CreateTransactionResponse {
        try await performWithIntegrity(.createTransaction, body: request)
    }

    func createSbiTransaction(_ request: CreateSbiTransactionRequest) async throws -> CreateSbiTransactionResponse {
        try await performWithIntegrity(.createSbiTransaction, body: request)
    }

    func getSbiTransactionDetails(fields: [String: String]) async throws -> SbiTransactionDetailsResponse {
        try await network.requestMultipart(.getSbiTransactionDetails, fields: fields, requiresAuth: true)
    }

    /// Cross-verifies a PayU transaction after the SDK callback fires. Matches Dart's
    /// `getTransactionDetails`: POST multipart/form-data with field `mobile_transaction_id`.
    func getTransactionDetails(mobileTransactionId: String) async throws -> PayUTransactionDetailsResponse {
        try await network.requestMultipart(.getTransactionDetails,
                                           fields: ["mobile_transaction_id": mobileTransactionId],
                                           requiresAuth: true)
    }

    /// PayU SDK hash-generation round trip. Matches Dart's `generateHash`: POST
    /// application/x-www-form-urlencoded with fields `hashName` + `hashString`.
    func generateHash(hashName: String, hashString: String) async throws -> HashResponse {
        try await network.requestForm(.generateHash,
                                      fields: ["hashName": hashName, "hashString": hashString],
                                      requiresAuth: true)
    }

    func getTransactionsByEmail(emailId: String) async throws -> TransactionsByEmailResponse {
        try await perform(.getTransactionsByEmail, method: .POST,
                          body: TransactionsByEmailRequest(emailId: emailId))
    }

    // MARK: - ARV Change History

    func getArvChangeHistory(propertyId: String) async throws -> ArvChangeHistoryResponse {
        try await perform(.arvChangeHistory, method: .POST,
                          body: PropertyIdBody(propertyId: propertyId))
    }

    // MARK: - Sign Up (Step 2) — citizen self-registration

    func getSignupCaptcha() async throws -> CaptchaResponse {
        let wrapper: SignupCaptchaEnvelope = try await perform(.signupCaptcha, method: .GET, requiresAuth: false)
        guard wrapper.success, let data = wrapper.data else {
            throw NetworkError.unknown(NSError(domain: "APIService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: wrapper.message ?? "Failed to load captcha"]))
        }
        return data
    }

    func getSignupCities(ulbType: String) async throws -> [SignupCity] {
        let wrapper: SignupCitiesEnvelope = try await perform(.signupCities(ulbType: ulbType), method: .GET, requiresAuth: false)
        guard wrapper.success, let data = wrapper.data else {
            throw NetworkError.unknown(NSError(domain: "APIService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: wrapper.message ?? "Failed to load cities"]))
        }
        return data
    }

    func registerCitizen(_ request: CitizenRegisterRequest) async throws -> CitizenRegisterResponse {
        try await perform(.registerCitizen, method: .POST, body: request, requiresAuth: false)
    }

    func verifyCitizenOtp(_ request: CitizenVerifyOtpRequest) async throws -> CitizenVerifyOtpResponse {
        try await perform(.verifyCitizenOtp, method: .POST, body: request, requiresAuth: false)
    }

    // MARK: - Core perform wrappers

    private func perform<Req: Encodable, Res: Decodable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Req? = nil,
        requiresAuth: Bool = true
    ) async throws -> Res {
        do {
            return try await network.request(endpoint, method: method, body: body,
                                             requiresAuth: requiresAuth)
        } catch NetworkError.forbidden {
            try await auth.refreshTokenIfNeeded()
            return try await network.request(endpoint, method: method, body: body,
                                             requiresAuth: requiresAuth)
        }
    }

    private func perform<Res: Decodable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        requiresAuth: Bool = true
    ) async throws -> Res {
        let body: String? = nil
        return try await perform(endpoint, method: method, body: body, requiresAuth: requiresAuth)
    }

    private func performWithIntegrity<Req: Encodable, Res: Decodable>(
        _ endpoint: APIEndpoint,
        body: Req
    ) async throws -> Res {
        do {
            return try await network.request(endpoint, method: .POST, body: body,
                                             requiresAuth: true, requiresIntegrity: true)
        } catch NetworkError.forbidden {
            try await auth.refreshTokenIfNeeded()
            return try await network.request(endpoint, method: .POST, body: body,
                                             requiresAuth: true, requiresIntegrity: true)
        } catch NetworkError.integrityExpired {
            _ = try await integrity.refreshIntegrityToken()
            return try await network.request(endpoint, method: .POST, body: body,
                                             requiresAuth: true, requiresIntegrity: true)
        }
    }
}
