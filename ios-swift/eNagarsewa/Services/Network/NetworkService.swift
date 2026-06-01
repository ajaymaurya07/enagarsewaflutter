import Foundation

/// Core HTTP client. All requests go through here.
/// Handles cert pinning, standard headers, and HTTP-status-to-error mapping.
final class NetworkService {

    static let shared = NetworkService()

    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = AppConstants.Timeout.request
        config.timeoutIntervalForResource = AppConstants.Timeout.resource
        session = URLSession(configuration: config, delegate: CertificatePinner.shared, delegateQueue: nil)
        decoder.keyDecodingStrategy = .useDefaultKeys
    }

    // MARK: - JSON requests

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        requiresAuth: Bool = true,
        requiresIntegrity: Bool = false
    ) async throws -> T {
        var urlRequest = try buildRequest(endpoint, method: method, body: body,
                                          requiresAuth: requiresAuth,
                                          requiresIntegrity: requiresIntegrity)
        return try await perform(urlRequest)
    }

    // MARK: - Form-encoded requests

    func requestForm<T: Decodable>(
        _ endpoint: APIEndpoint,
        fields: [String: String],
        requiresAuth: Bool = true
    ) async throws -> T {
        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = HTTPMethod.POST.rawValue
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = fields.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        applyStandardHeaders(&urlRequest, requiresAuth: requiresAuth, requiresIntegrity: false)
        return try await perform(urlRequest)
    }

    // MARK: - Multipart requests

    func requestMultipart<T: Decodable>(
        _ endpoint: APIEndpoint,
        fields: [String: String],
        fileData: Data? = nil,
        fileName: String = "file.jpg",
        mimeType: String = "image/jpeg",
        fileFieldName: String = "file",
        requiresAuth: Bool = true
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = HTTPMethod.POST.rawValue
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = buildMultipartBody(boundary: boundary, fields: fields,
                                                  fileData: fileData, fileName: fileName,
                                                  mimeType: mimeType, fileFieldName: fileFieldName)
        applyStandardHeaders(&urlRequest, requiresAuth: requiresAuth, requiresIntegrity: false)
        return try await perform(urlRequest)
    }

    // MARK: - Private helpers

    private func buildRequest(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Encodable?,
        requiresAuth: Bool,
        requiresIntegrity: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = method.rawValue
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        applyStandardHeaders(&request, requiresAuth: requiresAuth, requiresIntegrity: requiresIntegrity)
        return request
    }

    private func applyStandardHeaders(
        _ request: inout URLRequest,
        requiresAuth: Bool,
        requiresIntegrity: Bool
    ) {
        request.setValue("application/json",        forHTTPHeaderField: "Accept")
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        }
        request.setValue(AppConstants.buildNumber,  forHTTPHeaderField: "X-App-Version")
        let deviceId = DeviceSecurityService.shared.deviceId
        request.setValue(deviceId,                  forHTTPHeaderField: "X-Device-Id")
        request.setValue(deviceId,                  forHTTPHeaderField: "device_id")

        if requiresAuth, let token = KeychainService.shared.accessToken {
            request.setValue("Bearer \(token)",     forHTTPHeaderField: "Authorization")
        }
        if requiresIntegrity, let token = KeychainService.shared.integrityToken {
            request.setValue(token,                 forHTTPHeaderField: "X-Integrity-Token")
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw urlError.code == .timedOut ? NetworkError.timeout : NetworkError.noInternet
        } catch {
            throw NetworkError.unknown(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "NetworkService", code: -1))
        }

        if let networkError = NetworkError.from(statusCode: http.statusCode) {
            throw networkError
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    private func buildMultipartBody(
        boundary: String,
        fields: [String: String],
        fileData: Data?,
        fileName: String,
        mimeType: String,
        fileFieldName: String
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"
        let delimiter = "--\(boundary)\(crlf)"
        let closeDelimiter = "--\(boundary)--\(crlf)"

        for (key, value) in fields {
            body.append(delimiter.utf8Data)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(crlf)\(crlf)".utf8Data)
            body.append("\(value)\(crlf)".utf8Data)
        }

        if let fileData {
            body.append(delimiter.utf8Data)
            body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\(crlf)".utf8Data)
            body.append("Content-Type: \(mimeType)\(crlf)\(crlf)".utf8Data)
            body.append(fileData)
            body.append(crlf.utf8Data)
        }

        body.append(closeDelimiter.utf8Data)
        return body
    }
}

// MARK: - Supporting types

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH
}

private extension String {
    var utf8Data: Data { Data(utf8) }
}
