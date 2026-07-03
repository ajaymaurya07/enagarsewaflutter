import Foundation

enum APIEndpoint {

    // MARK: - Auth
    case getChallenge
    case login
    case signup
    case forgotPasswordRequest
    case verifyForgotPasswordOtp
    case refreshToken
    case logout

    // MARK: - OTP
    case sendOtp
    case verifyOtp
    case verifyOtpEmail

    // MARK: - Property
    case ulbData
    case zoneData(ulbId: String)
    case wardData(ulbId: String, zoneId: String)
    case mohallaData(ulbId: String, zoneId: String, wardId: String)
    case propertySearch
    case propertyDetails

    // MARK: - Grievance
    case grievanceCategory
    case saveGrievance
    case registerGrievanceAfterOtp
    case getGrievanceDetails
    case getGrievanceStatus

    // MARK: - Payment
    case createTransaction
    case createSbiTransaction
    case getSbiTransactionDetails
    case getTransactionDetails
    case generateHash
    case getTransactionsByEmail

    // MARK: - Integrity
    case getNonce
    case verifyIntegrity

    // MARK: - ARV Change History
    case arvChangeHistory

    // MARK: - Sign Up (citizen self-registration, Step 2)
    case signupCaptcha
    case signupCities(ulbType: String)
    case registerCitizen
    case verifyCitizenOtp

    // MARK: - Computed URL
    var url: URL {
        URL(string: AppConstants.baseURL + path)!
    }

    private var path: String {
        switch self {
        case .getChallenge:              return "api/house_tax/get_challenge"
        case .login:                     return "api/house_tax/login"
        case .signup:                    return "api/house_tax/signup"
        case .forgotPasswordRequest:     return "api/house_tax/forgot_password_request"
        case .verifyForgotPasswordOtp:   return "api/house_tax/verify_forgot_password_otp"
        case .refreshToken:              return "api/house_tax/refreshToken"
        case .logout:                    return "api/house_tax/logout"

        case .sendOtp:                   return "api/house_tax/sendOtp"
        case .verifyOtp:                 return "api/house_tax/verifyOtp"
        case .verifyOtpEmail:            return "api/house_tax/verifyOtpEmail"

        case .ulbData:                   return "api/House_tax/ulbdata"
        case .zoneData(let u):           return "api/House_tax/zonedata/\(u)"
        case .wardData(let u, let z):    return "api/House_tax/warddata/\(u)/\(z)"
        case .mohallaData(let u, let z, let w): return "api/House_tax/mohalladata/\(u)/\(z)/\(w)"
        case .propertySearch:            return "api/House_tax/propertysearch"
        case .propertyDetails:           return "api/House_tax/propertydetails"

        case .grievanceCategory:         return "api/House_tax/grievanceCategory"
        case .saveGrievance:             return "api/house_tax/saveGrievance"
        case .registerGrievanceAfterOtp: return "api/house_tax/registerGrievanceAfterOtp"
        case .getGrievanceDetails:       return "api/house_tax/getGrievanceDetails"
        case .getGrievanceStatus:        return "api/house_tax/getGrievanceStatus"

        case .createTransaction:         return "api/Payment/create_transaction"
        case .createSbiTransaction:      return "api/Payment/create_sbi_transaction"
        case .getSbiTransactionDetails:  return "api/Payment/getSbiTransactionDetails"
        case .getTransactionDetails:     return "api/payment/getTransactionDetails"
        case .generateHash:              return "api/Payment/generate_hash"
        case .getTransactionsByEmail:    return "api/payment/get_transactions_by_email"

        case .getNonce:                  return "api/Play_integrity/get_nonce"
        case .verifyIntegrity:           return "api/house_tax/verify-integrity"

        case .arvChangeHistory:          return "api/house_tax/getArvChangeHistory"

        case .signupCaptcha:             return "api/Signup_citizen/captcha"
        case .signupCities(let type):    return "api/Signup_citizen/cities?type=\(type)"
        case .registerCitizen:           return "api/Signup_citizen/register"
        case .verifyCitizenOtp:          return "api/Signup_citizen/verify_otp"
        }
    }
}
