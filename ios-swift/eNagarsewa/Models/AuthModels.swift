import Foundation

// Ports of the auth/OTP/sign-up models in lib/services/api_service.dart.
// Field names and fallbacks follow the Dart `fromJson` factories exactly.

// MARK: - Password login (secure challenge flow)

struct SignIn {
    var accessToken: String?
    var refreshToken: String?
    var emailId: String?
    var userType: String?
    var userId: String?

    init(accessToken: String? = nil, refreshToken: String? = nil, emailId: String? = nil,
         userType: String? = nil, userId: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.emailId = emailId
        self.userType = userType
        self.userId = userId
    }

    init(json: JSON) {
        accessToken = json["access_token"].str
        refreshToken = json["refresh_token"].str
        emailId = json["email_id"].str
        userType = json["user_type"].str
        userId = json["user_id"].str
    }
}

struct LoginResponse {
    let success: Bool
    let message: String
    let responseCode: Int?
    let data: SignIn?

    init(json: JSON) {
        success = json["status"].isTrue
        message = json["message"].strOrEmpty
        responseCode = json["responseCode"].int
        data = json["data"].object != nil ? SignIn(json: json["data"]!) : nil
    }
}

struct LogoutResponse {
    let status: Bool
    let message: String
    let responseCode: Int

    init(json: JSON) {
        status = json["status"].isTrue
        message = json["message"].strOrEmpty
        responseCode = json["responseCode"].int ?? 0
    }
}

struct RefreshTokenResponse {
    let status: Bool?
    let responseCode: Int?
    let message: String?
    let accessToken: String?

    init(json: JSON) {
        status = json["status"].bool
        responseCode = json["responseCode"].int
        message = json["message"].str
        accessToken = json["data"]?["access_token"].str
    }
}

// MARK: - Forgot password

struct ForgotPasswordResponse {
    let status: Bool
    let message: String
    let responseCode: Int?

    init(json: JSON) {
        status = json["status"].isTrue
        message = json["message"].strOrEmpty
        responseCode = json["responseCode"].int
    }
}

struct VerifyForgotPasswordOtpResponse {
    let status: Bool
    let message: String
    let responseCode: Int?
    let attemptsLeft: Int?

    init(json: JSON) {
        status = json["status"].isTrue
        message = json["message"].strOrEmpty
        responseCode = json["responseCode"].int
        attemptsLeft = json["data"]?["attempts_left"].int
    }
}

// MARK: - Property OTP (sendOtp / verifyOtp)

struct SendOtpResponse {
    let success: Bool?
    let message: String?
    let responseCode: Int?
    let maskedMobile: String?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        responseCode = json["responseCode"].int
        maskedMobile = json["data"]?["maskedMobile"].str
    }
}

struct VerifyOtpResponse {
    let success: Bool?
    let message: String?
    let userId: Int?
    let responseCode: Int?

    init(json: JSON) {
        success = json["success"].bool
        message = json["message"].str
        userId = json["userId"].int
        responseCode = json["responseCode"].int
    }
}

// MARK: - OTP login

struct OtpLoginSendOtpResponse {
    let status: Bool
    let responseCode: Int?
    let message: String
    let maskedMobile: String?
    let expiresInSeconds: Int?

    init(json: JSON) {
        status = json["status"].isTrue
        responseCode = json["responseCode"].int
        message = json["message"].strOrEmpty
        maskedMobile = json["data"]?["maskedMobile"].str
        expiresInSeconds = json["data"]?["expiresInSeconds"].int
    }
}

struct OtpLoginData {
    let accessToken: String?
    let refreshToken: String?
    let emailId: String?
    let userType: String?
    let ulbId: String?
    let loginVia: String?
    let userId: String?
    let mobile: String?

    init(json: JSON) {
        accessToken = json["access_token"].str
        refreshToken = json["refresh_token"].str
        emailId = json["email_id"].str
        userType = json["user_type"].str
        ulbId = json["ulbid"].str
        loginVia = json["login_via"].str
        userId = json["user_id"].str
        mobile = json["mobile"].str
    }
}

struct OtpLoginVerifyOtpResponse {
    let status: Bool
    let responseCode: Int?
    let message: String
    let data: OtpLoginData?

    init(json: JSON) {
        status = json["status"].isTrue
        responseCode = json["responseCode"].int
        message = json["message"].strOrEmpty
        data = json["data"].object != nil ? OtpLoginData(json: json["data"]!) : nil
    }
}

// MARK: - Legacy sign-up (email OTP)

struct SignUpResponse {
    let message: String?
    let status: Bool?
    let responseCode: Int?

    init(json: JSON) {
        message = json["message"].str
        status = json["status"].bool
        responseCode = json["responseCode"].int
    }
}

struct VerifyOtpMailResponse {
    let message: String?
    let status: Bool?
    let responseCode: Int?

    init(json: JSON) {
        message = json["message"].str
        status = json["status"].bool
        responseCode = json["responseCode"].int
    }
}

// MARK: - Citizen self-registration

struct SignupCity: Equatable {
    let id: Int
    let name: String

    init(json: JSON) {
        id = json["id"].int ?? 0
        name = json["name"].strOrEmpty
    }
}

struct CaptchaResponse {
    let captchaId: String
    let captchaImage: String

    init(json: JSON) {
        captchaId = json["captchaId"].strOrEmpty
        captchaImage = json["captchaImage"].strOrEmpty
    }
}

struct CitizenRegisterResponse {
    let status: Bool?
    let responseCode: Int?
    let message: String?
    let mobileOtpRequired: Bool?
    let emailOtpRequired: Bool?
    let emailOtpSent: Bool?
    let registrationComplete: Bool?
    let alreadyOnEnagarsewa: Bool?
    let enagarMessage: String?

    init(json: JSON) {
        status = json["status"].bool
        responseCode = json["responseCode"].int
        message = json["message"].str
        let data = json["data"]
        mobileOtpRequired = data?["mobile_otp_required"].bool
        emailOtpRequired = data?["email_otp_required"].bool
        emailOtpSent = data?["email_otp_sent"].bool
        registrationComplete = data?["registration_complete"].bool
        alreadyOnEnagarsewa = data?["already_on_enagarsewa"].bool
        enagarMessage = data?["enagar_message"].str
    }
}

struct ResendSignupOtpResponse {
    let status: Bool?
    let responseCode: Int?
    let message: String?
    let mobileOtpSent: Bool?
    let emailOtpSent: Bool?
    let emailMasked: String?
    let mobileOtpRequired: Bool?
    let emailOtpRequired: Bool?
    let registrationComplete: Bool?
    let enagarMessage: String?

    init(json: JSON) {
        status = json["status"].bool
        responseCode = json["responseCode"].int
        message = json["message"].str
        let data = json["data"]
        mobileOtpSent = data?["mobile_otp_sent"].bool
        emailOtpSent = data?["email_otp_sent"].bool
        emailMasked = data?["email_masked"].str
        mobileOtpRequired = data?["mobile_otp_required"].bool
        emailOtpRequired = data?["email_otp_required"].bool
        registrationComplete = data?["registration_complete"].bool
        enagarMessage = data?["enagar_message"].str
    }
}

struct CitizenVerifyOtpResponse {
    let status: Bool?
    let responseCode: Int?
    let message: String?
    let mobileVerified: Bool?
    let emailVerified: Bool?
    let mobileOtpRequired: Bool?
    let emailOtpRequired: Bool?
    let registrationComplete: Bool?
    let enagarMessage: String?

    init(json: JSON) {
        status = json["status"].bool
        responseCode = json["responseCode"].int
        message = json["message"].str
        let data = json["data"]
        mobileVerified = data?["mobile_verified"].bool
        emailVerified = data?["email_verified"].bool
        mobileOtpRequired = data?["mobile_otp_required"].bool
        emailOtpRequired = data?["email_otp_required"].bool
        registrationComplete = data?["registration_complete"].bool
        enagarMessage = data?["enagar_message"].str
    }
}
