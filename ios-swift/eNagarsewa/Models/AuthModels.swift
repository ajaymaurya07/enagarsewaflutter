import Foundation

// MARK: - Challenge / Login (secure double-hash challenge-response, matches Flutter secureLogin)

struct ChallengeRequest: Encodable {
    let username: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case username
        case deviceId = "device_id"
    }
}

struct ChallengeResponse: Decodable {
    let status: Bool
    let message: String?
    let data: ChallengeData?
}

struct ChallengeData: Decodable {
    let challengeId: String
    let challenge: String
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case challenge
        case timestamp
    }

    /// Backend may return `timestamp` as a JSON number or string — accept either.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        challengeId = try c.decode(String.self, forKey: .challengeId)
        challenge   = try c.decode(String.self, forKey: .challenge)
        if let ts = try? c.decode(String.self, forKey: .timestamp) {
            timestamp = ts
        } else {
            timestamp = String(try c.decode(Int64.self, forKey: .timestamp))
        }
    }
}

/// Login request for the secure double-hash flow:
/// hash = SHA512(SHA512(password) + challenge + timestamp + nonce)
struct LoginRequest: Encodable {
    let username: String
    let deviceId: String
    let challengeId: String
    let timestamp: String
    let nonce: String
    let hash: String

    enum CodingKeys: String, CodingKey {
        case username
        case deviceId = "device_id"
        case challengeId = "challenge_id"
        case timestamp
        case nonce
        case hash
    }
}

struct LoginResponse: Decodable {
    let success: Bool
    let message: String?
    let data: LoginData?

    enum CodingKeys: String, CodingKey {
        case success = "status"
        case message
        case data
    }
}

struct LoginData: Decodable {
    let accessToken: String
    let refreshToken: String
    let emailId: String
    let userType: String

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case emailId      = "email_id"
        case userType     = "user_type"
    }
}

// MARK: - Sign Up

struct SignUpRequest: Encodable {
    let name: String
    let email: String
    let password: String
    let phoneNumber: String
    let deviceId: String
    let fcmToken: String
}

struct SignUpResponse: Decodable {
    let success: Bool
    let message: String
}

// MARK: - OTP

struct SendOtpRequest: Encodable {
    let phoneNumber: String
    let propertyId: String?

    /// Real backend field is `mobileNo`, not `phoneNumber` — matches Dart's
    /// `sendOtp` body: `{'mobileNo': mobileNo, 'propertyId': propertyId}`.
    enum CodingKeys: String, CodingKey {
        case phoneNumber = "mobileNo"
        case propertyId
    }
}

struct SendOtpResponse: Decodable {
    let success: Bool
    let message: String
    /// Nested under `data.maskedMobile` in the real response — matches Dart's SendOtpResponse.
    let maskedMobile: String?

    private enum CodingKeys: String, CodingKey { case success, message, data }
    private enum DataKeys: String, CodingKey { case maskedMobile }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        if let dataContainer = try? c.nestedContainer(keyedBy: DataKeys.self, forKey: .data) {
            maskedMobile = try? dataContainer.decodeIfPresent(String.self, forKey: .maskedMobile)
        } else {
            maskedMobile = nil
        }
    }
}

struct VerifyOtpRequest: Encodable {
    let phoneNumber: String
    let otp: String

    /// Real backend field is `mobileNo`, not `phoneNumber` — matches Dart's
    /// `verifyOtp` body: `{'mobileNo': mobileNo, 'otp': otp}`.
    enum CodingKeys: String, CodingKey {
        case phoneNumber = "mobileNo"
        case otp
    }
}

struct VerifyOtpResponse: Decodable {
    let success: Bool
    let message: String
    let userId: Int?
}

struct VerifyOtpMailRequest: Encodable {
    let email: String
    let otp: String
}

struct VerifyOtpMailResponse: Decodable {
    let success: Bool
    let message: String
}

// MARK: - Forgot Password

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct ForgotPasswordResponse: Decodable {
    let success: Bool
    let message: String
}

struct VerifyForgotPasswordOtpRequest: Encodable {
    let email: String
    let otp: String
    let newPassword: String  // SHA-512 hashed
}

struct VerifyForgotPasswordOtpResponse: Decodable {
    let success: Bool
    let message: String
    /// Number of remaining OTP attempts — matches Flutter attemptsLeft field
    let attemptsLeft: Int?
}

// MARK: - Token Refresh

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

struct RefreshTokenResponse: Decodable {
    let success: Bool
    let data: RefreshTokenData?

    enum CodingKeys: String, CodingKey {
        case success = "status"
        case data
    }
}

struct RefreshTokenData: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

// MARK: - Logout

struct LogoutResponse: Decodable {
    let success: Bool
    let message: String
}

// MARK: - Integrity
// Wire shapes mirror Flutter's integrity_service.dart (_fetchBackendNonce / _sendToBackend),
// which reads `status_code` (String) + `nonce` / `integrity_token` from the raw JSON body.

struct GetNonceResponse: Decodable {
    let statusCode: String?
    let nonce: String?

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case nonce
    }
}

struct VerifyIntegrityResponse: Decodable {
    let statusCode: String?
    let integrityToken: String?

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case integrityToken = "integrity_token"
    }
}

// MARK: - Sign Up (Step 2) — citizen self-registration flow, matches Flutter sign_up_02.dart

struct SignupCity: Decodable {
    let id: Int
    let name: String
}

struct CaptchaResponse: Decodable {
    let captchaId: String
    let captchaImage: String  // base64-encoded PNG
}

/// Wrapper envelopes — both `getSignupCaptcha` and `getSignupCities` return `{success, message, data}`.
struct SignupCaptchaEnvelope: Decodable {
    let success: Bool
    let message: String?
    let data: CaptchaResponse?
}

struct SignupCitiesEnvelope: Decodable {
    let success: Bool
    let message: String?
    let data: [SignupCity]?
}

struct CitizenRegisterRequest: Encodable {
    let name: String
    let fatherHusbandName: String
    let address1: String
    let address2: String
    let ulbType: String
    let city: Int
    let mobileNo: String
    let email: String
    let encryptedPassword: String
    let encryptedConfirmPassword: String
    let captchaId: String
    let captcha: String
}

struct CitizenRegisterResponse: Decodable {
    let status: Bool?
    let message: String?
    let mobileOtpRequired: Bool?
    let emailOtpRequired: Bool?
    let emailOtpSent: Bool?
    let registrationComplete: Bool?
    let alreadyOnEnagarsewa: Bool?
    let enagarMessage: String?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }
    enum DataKeys: String, CodingKey {
        case mobileOtpRequired = "mobile_otp_required"
        case emailOtpRequired  = "email_otp_required"
        case emailOtpSent      = "email_otp_sent"
        case registrationComplete = "registration_complete"
        case alreadyOnEnagarsewa   = "already_on_enagarsewa"
        case enagarMessage         = "enagar_message"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decodeIfPresent(Bool.self, forKey: .status)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        let data = try? c.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        mobileOtpRequired    = try data?.decodeIfPresent(Bool.self, forKey: .mobileOtpRequired)
        emailOtpRequired     = try data?.decodeIfPresent(Bool.self, forKey: .emailOtpRequired)
        emailOtpSent         = try data?.decodeIfPresent(Bool.self, forKey: .emailOtpSent)
        registrationComplete = try data?.decodeIfPresent(Bool.self, forKey: .registrationComplete)
        alreadyOnEnagarsewa  = try data?.decodeIfPresent(Bool.self, forKey: .alreadyOnEnagarsewa)
        enagarMessage        = try data?.decodeIfPresent(String.self, forKey: .enagarMessage)
    }
}

struct CitizenVerifyOtpRequest: Encodable {
    let mobileNo: String
    let otp: String
}

struct CitizenVerifyOtpResponse: Decodable {
    let status: Bool?
    let message: String?
    let mobileVerified: Bool?
    let emailVerified: Bool?
    let mobileOtpRequired: Bool?
    let emailOtpRequired: Bool?
    let registrationComplete: Bool?
    let enagarMessage: String?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }
    enum DataKeys: String, CodingKey {
        case mobileVerified = "mobile_verified"
        case emailVerified  = "email_verified"
        case mobileOtpRequired = "mobile_otp_required"
        case emailOtpRequired  = "email_otp_required"
        case registrationComplete = "registration_complete"
        case enagarMessage         = "enagar_message"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decodeIfPresent(Bool.self, forKey: .status)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        let data = try? c.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        mobileVerified       = try data?.decodeIfPresent(Bool.self, forKey: .mobileVerified)
        emailVerified        = try data?.decodeIfPresent(Bool.self, forKey: .emailVerified)
        mobileOtpRequired    = try data?.decodeIfPresent(Bool.self, forKey: .mobileOtpRequired)
        emailOtpRequired     = try data?.decodeIfPresent(Bool.self, forKey: .emailOtpRequired)
        registrationComplete = try data?.decodeIfPresent(Bool.self, forKey: .registrationComplete)
        enagarMessage        = try data?.decodeIfPresent(String.self, forKey: .enagarMessage)
    }
}

// MARK: - ARV Change History

struct ArvChangeHistoryResponse: Decodable {
    let success: Bool?
    let message: String?
    let data: [ArvChangeHistoryItem]?
}

struct ArvChangeHistoryItem: Decodable {
    let ulbId: Int?
    let propertyId: String?
    let ownerName: String?
    let fatherHusbandName: String?
    let houseNo: String?
    let oldPropertyId: String?
    let address: String?
    let oldArv: Double?
    let currentArv: Double?
    let ulbLanguage: String?
    let arvChangeDate: String?
}

