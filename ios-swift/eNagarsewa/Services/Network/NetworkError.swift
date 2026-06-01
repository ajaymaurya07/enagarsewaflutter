import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case noInternet
    case unauthorized          // 401
    case forbidden             // 403 — triggers token refresh
    case integrityExpired      // 412 — triggers App Attest refresh
    case serverError(Int)      // other 5xx/4xx
    case decodingFailed(Error)
    case certificatePinningFailed
    case timeout
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:                return "Invalid server URL."
        case .noInternet:                return "No internet connection. Please check your network."
        case .unauthorized:              return "Session expired. Please log in again."
        case .forbidden:                 return "Access denied."
        case .integrityExpired:          return "Device verification expired. Retrying…"
        case .serverError(let code):     return "Server error (\(code)). Please try again later."
        case .decodingFailed:            return "Unexpected server response."
        case .certificatePinningFailed:  return "Security certificate validation failed."
        case .timeout:                   return "Request timed out. Please try again."
        case .unknown(let e):            return e.localizedDescription
        }
    }

    static func from(statusCode: Int) -> NetworkError? {
        switch statusCode {
        case 200...299: return nil
        case 401:       return .unauthorized
        case 403:       return .forbidden
        case 412:       return .integrityExpired
        default:        return .serverError(statusCode)
        }
    }
}
