import Foundation

/// One row from `GET /api/auth/providers` (public bootstrap endpoint).
public struct AuthProvider: Decodable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let supportsPassword: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case supportsPassword = "supports_password"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `id` may arrive as a string or be absent; fall back to name.
        let name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.id = (try? c.decode(String.self, forKey: .id)) ?? name
        self.name = name
        self.supportsPassword = (try? c.decode(Bool.self, forKey: .supportsPassword)) ?? false
    }

    public init(id: String, name: String, supportsPassword: Bool) {
        self.id = id
        self.name = name
        self.supportsPassword = supportsPassword
    }
}

/// The current session, from `GET /api/auth/me`.
public struct Session: Decodable, Sendable, Equatable {
    public let userId: String?
    public let provider: String?
    public let displayName: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case provider
        case displayName = "display_name"
        case name
        case email
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try c.decodeIfPresent(String.self, forKey: .userId)
        self.provider = try c.decodeIfPresent(String.self, forKey: .provider)
        // Tolerate a few common shapes for the human label.
        self.displayName = (try? c.decode(String.self, forKey: .displayName))
            ?? (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .email))
    }

    public init(userId: String?, provider: String?, displayName: String?) {
        self.userId = userId
        self.provider = provider
        self.displayName = displayName
    }
}
