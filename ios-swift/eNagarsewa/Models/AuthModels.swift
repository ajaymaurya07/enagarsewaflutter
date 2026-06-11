import Foundation

// MARK: - Challenge / Login

struct ChallengeRequest: Encodable {
    let email: String
}

struct ChallengeResponse: Decodable {
    let success: Bool
    let challenge: String
}

struct LoginRequest: Encodable {
    let email: String
    let hashedPassword: String  // SHA-512(password + challenge)
    let fcmToken: String
    let deviceId: String
}

struct LoginResponse: Decodable {
    let success: Bool
    let message: String
    let data: LoginData?
}

struct LoginData: Decodable {
    let accessToken: String
    let refreshToken: String
    let emailId: String
    let userType: String
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
}

struct SendOtpResponse: Decodable {
    let success: Bool
    let message: String
}

struct VerifyOtpRequest: Encodable {
    let phoneNumber: String
    let otp: String
}

struct VerifyOtpResponse: Decodable {
    let success: Bool
    let message: String
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
}

struct RefreshTokenData: Decodable {
    let accessToken: String
    let refreshToken: String
}

// MARK: - Logout

struct LogoutResponse: Decodable {
    let success: Bool
    let message: String
}

// MARK: - Integrity

struct GetNonceResponse: Decodable {
    let nonce: String
}

struct VerifyIntegrityRequest: Encodable {
    let attestation: String
    let keyId: String
    let nonce: String
}

struct VerifyIntegrityResponse: Decodable {
    let success: Bool
    let integrityToken: String?
    let message: String
}
