import Foundation

/// Errors surfaced by `APIService`. Mirrors how `api_service.dart` reports failures:
///
/// * Transport problems (offline, timeout, host lookup) become the network message.
/// * A server-provided `message` is shown as-is.
/// * Anything technical (non-200 status, malformed body) collapses to a generic message, or to
///   the screen's own fallback text — exactly like `ApiService.getUserFriendlyErrorMessage`.
enum APIError: LocalizedError {
    case network
    case server(Int)
    case message(String)
    case invalidResponse
    case sessionExpired

    static let genericMessage = "Something went wrong. Please try again."
    static let networkMessage = "Unable to connect right now. Please check your internet connection and try again."

    var errorDescription: String? {
        switch self {
        case .network:          return APIError.networkMessage
        case .message(let m):   return m
        case .sessionExpired:   return "Session expired. Please login again."
        case .server, .invalidResponse: return APIError.genericMessage
        }
    }

    /// Dart `ApiService.getUserFriendlyErrorMessage(error, fallbackMessage:)`.
    static func userMessage(_ error: Error, fallback: String = genericMessage) -> String {
        switch error {
        case APIError.network:
            return networkMessage
        case APIError.message(let m):
            let trimmed = m.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || isTechnical(trimmed) ? fallback : trimmed
        case APIError.sessionExpired:
            return "Session expired. Please login again."
        case is URLError:
            return networkMessage
        default:
            return fallback
        }
    }

    /// `_userSafeException`: every API call except the few Dart `rethrow`s converts technical
    /// failures into the generic message before it reaches the screen.
    static func sanitized(_ error: Error) -> APIError {
        switch error {
        case let api as APIError:
            switch api {
            case .network, .message, .sessionExpired: return api
            case .server, .invalidResponse: return .message(genericMessage)
            }
        case is URLError:
            return .network
        default:
            return .message(genericMessage)
        }
    }

    /// Port of `_isTechnicalErrorMessage`.
    private static func isTechnical(_ message: String) -> Bool {
        let n = message.lowercased()
        let prefixes = ["connection error:", "server error:", "login api error:", "failed to get challenge:",
                        "failed to load property details:", "transaction initiation failed:",
                        "failed to generate hash:", "sign up failed:", "otp verification failed:",
                        "password reset failed:"]
        if prefixes.contains(where: { n.hasPrefix($0) }) { return true }
        let fragments = ["socketexception", "clientexception", "formatexception", "xmlhttprequest error",
                         "failed host lookup", "connection closed before full header was received"]
        if fragments.contains(where: { n.contains($0) }) { return true }
        if n.contains("type ") && n.contains(" is not a subtype") { return true }
        if message.contains("${") { return true }
        return message.range(of: #":\s*\d{3}\b"#, options: .regularExpression) != nil
    }
}
