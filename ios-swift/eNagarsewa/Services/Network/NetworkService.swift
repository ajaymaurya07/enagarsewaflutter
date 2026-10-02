import Foundation

/// Raw HTTP result — status plus body, parsed lazily into an order-preserving `JSON`.
struct HTTPResult {
    let statusCode: Int
    let data: Data

    func json() throws -> JSON {
        let trimmed = data.trimmingWhitespace
        guard !trimmed.isEmpty else { throw APIError.invalidResponse }
        do { return try JSON.parse(trimmed) } catch { throw APIError.invalidResponse }
    }
}

/// One part of a multipart/form-data body.
enum MultipartPart {
    case field(name: String, value: String)
    /// A file part. Flutter's `http.MultipartFile.fromPath` always sends
    /// `application/octet-stream`, so that stays the default.
    case file(name: String, filename: String, data: Data, contentType: String = "application/octet-stream")
    /// A JSON-encoded part without a filename (`MultipartFile.fromString(..., contentType: json)`).
    case json(name: String, data: Data)
}

/// Transport only: a certificate-pinned `URLSession` plus request builders.
/// Auth/refresh/session-expiry policy lives in `APIService`, like `ApiService` in Dart.
final class NetworkService {

    static let shared = NetworkService()

    let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = AppConstants.Timeout.request
        config.timeoutIntervalForResource = AppConstants.Timeout.resource
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config, delegate: CertificatePinner.shared, delegateQueue: nil)
    }

    // MARK: - Builders

    func url(_ path: String) -> URL {
        URL(string: AppConstants.baseURL + path)!
    }

    func getRequest(_ path: String, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url(path))
        request.httpMethod = "GET"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }

    func postRequest(_ path: String, headers: [String: String], json body: [String: Any]?) -> URLRequest {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        }
        return request
    }

    func formRequest(_ path: String, headers: [String: String], fields: [(String, String)]) -> URLRequest {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { "\($0.0.formEncoded)=\($0.1.formEncoded)" }
            .joined(separator: "&")
            .data(using: .utf8)
        return request
    }

    func multipartRequest(_ path: String, headers: [String: String], parts: [MultipartPart]) -> URLRequest {
        let boundary = "dart-http-boundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        // The JSON default from `headers` must not leak into a multipart request.
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(parts: parts, boundary: boundary)
        return request
    }

    // MARK: - Execution

    func send(_ request: URLRequest) async throws -> HTTPResult {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            return HTTPResult(statusCode: http.statusCode, data: data)
        } catch let error as APIError {
            throw error
        } catch is URLError {
            throw APIError.network
        } catch {
            throw APIError.network
        }
    }

    // MARK: - Multipart encoding

    private static func multipartBody(parts: [MultipartPart], boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"
        for part in parts {
            body.append("--\(boundary)\(crlf)")
            switch part {
            case let .field(name, value):
                body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)")
                body.append(value)
            case let .file(name, filename, data, contentType):
                body.append("Content-Type: \(contentType)\(crlf)")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\(crlf)\(crlf)")
                body.append(data)
            case let .json(name, data):
                body.append("Content-Type: application/json; charset=utf-8\(crlf)")
                body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)")
                body.append(data)
            }
            body.append(crlf)
        }
        body.append("--\(boundary)--\(crlf)")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }

    var trimmingWhitespace: Data {
        let ws: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        guard let first = firstIndex(where: { !ws.contains($0) }),
              let last = lastIndex(where: { !ws.contains($0) }) else { return Data() }
        return self[first...last]
    }
}

private extension String {
    /// `Uri.encodeComponent` equivalent for form bodies.
    var formEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
