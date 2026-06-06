import Foundation

/// Async client for the Hermes REST API. Phase 0 covers connectivity only:
/// the public `/api/auth/providers` reachability probe and the authenticated
/// `/api/auth/me` session check. Later phases extend this with sessions,
/// models, cron, etc.
public actor HermesAPIClient {
    private let baseURL: URL
    private let token: String?
    private let session: URLSession

    public init(credential: HermesCredential, session: URLSession = .shared) {
        self.baseURL = credential.baseURL
        self.token = credential.sessionToken
        self.session = session
    }

    // MARK: - Phase 0 endpoints

    /// Public bootstrap endpoint. A 200 here proves we're talking to a reachable
    /// Hermes server, regardless of auth.
    public func providers() async throws -> [AuthProvider] {
        try await get("/api/auth/providers", authenticated: false)
    }

    /// Authenticated session check. Throws ``HermesError/unauthorized`` on 401.
    public func me() async throws -> Session {
        try await get("/api/auth/me", authenticated: true)
    }

    // MARK: - Request plumbing (internal — shared with feature extensions)

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], authenticated: Bool = true) async throws -> T {
        try decode(try await send("GET", path, query: query, body: nil, authenticated: authenticated))
    }

    @discardableResult
    func sendJSON<T: Decodable>(
        _ method: String, _ path: String, body: Encodable? = nil, authenticated: Bool = true
    ) async throws -> T {
        let data = try body.map { try JSONEncoder().encode(AnyEncodable($0)) }
        return try decode(try await send(method, path, query: [], body: data, authenticated: authenticated))
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw HermesError.decoding(String(describing: error)) }
    }

    func send(
        _ method: String, _ path: String, query: [URLQueryItem] = [],
        body: Data? = nil, authenticated: Bool
    ) async throws -> Data {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HermesError.invalidBaseURL(baseURL.absoluteString)
        }
        components.path = (components.path as NSString).appendingPathComponent(path)
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else {
            throw HermesError.invalidBaseURL(baseURL.absoluteString)
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token, !token.isEmpty {
            request.setValue("access_token=\(token)", forHTTPHeaderField: "Cookie")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await perform(request)
    }

    /// `multipart/form-data` upload. There is no other multipart path in the app;
    /// this builds the body by hand and reuses the same Bearer+Cookie auth as `send`.
    /// Uses a longer timeout since payloads (images) can be large.
    func sendMultipart<T: Decodable>(
        _ path: String, fields: [String: String] = [:],
        fileField: String, fileData: Data, filename: String, mime: String,
        authenticated: Bool = true
    ) async throws -> T {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HermesError.invalidBaseURL(baseURL.absoluteString)
        }
        components.path = (components.path as NSString).appendingPathComponent(path)
        guard let url = components.url else {
            throw HermesError.invalidBaseURL(baseURL.absoluteString)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        let crlf = "\r\n"
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        for (key, value) in fields {
            append("--\(boundary)\(crlf)")
            append("Content-Disposition: form-data; name=\"\(key)\"\(crlf)\(crlf)")
            append("\(value)\(crlf)")
        }
        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\(crlf)")
        append("Content-Type: \(mime)\(crlf)\(crlf)")
        body.append(fileData)
        append(crlf)
        append("--\(boundary)--\(crlf)")

        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        if authenticated, let token, !token.isEmpty {
            request.setValue("access_token=\(token)", forHTTPHeaderField: "Cookie")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try decode(try await perform(request))
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw HermesError.network((error as NSError).localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HermesError.network("Non-HTTP response")
        }
        switch http.statusCode {
        case 200...299: return data
        case 401, 403:  throw HermesError.unauthorized
        default:        throw HermesError.http(status: http.statusCode)
        }
    }

    /// The configured base URL (used to derive the WebSocket URL).
    public nonisolated var serverBaseURL: URL { baseURL }
    /// The session token, if any (used by the gateway socket).
    public nonisolated var serverToken: String? { token }
}

/// Type-erased Encodable so `sendJSON` can take any body.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
