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

    // MARK: - Request plumbing

    private func get<T: Decodable>(_ path: String, authenticated: Bool) async throws -> T {
        let data = try await rawGet(path, authenticated: authenticated)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HermesError.decoding(String(describing: error))
        }
    }

    private func rawGet(_ path: String, authenticated: Bool) async throws -> Data {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HermesError.invalidBaseURL(baseURL.absoluteString)
        }
        components.path = (components.path as NSString).appendingPathComponent(path)
        guard let url = components.url else {
            throw HermesError.invalidBaseURL(baseURL.absoluteString)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authenticated, let token, !token.isEmpty {
            // Hermes validates a session cookie; also send Bearer for forward-compat.
            request.setValue("access_token=\(token)", forHTTPHeaderField: "Cookie")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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
        case 200...299:
            return data
        case 401, 403:
            throw HermesError.unauthorized
        default:
            throw HermesError.http(status: http.statusCode)
        }
    }
}
