import Foundation
import Security

/// The connection credential: where Hermes lives and (optionally) a session token.
public struct HermesCredential: Sendable, Equatable {
    public var baseURL: URL
    /// Hermes session/access token. Optional — reachability works without it.
    public var sessionToken: String?

    public init(baseURL: URL, sessionToken: String? = nil) {
        self.baseURL = baseURL
        self.sessionToken = sessionToken
    }
}

/// Abstraction over persistent secret storage so the client is testable without
/// the real Keychain (which is unavailable in a plain XCTest host).
public protocol CredentialStore: Sendable {
    func load() -> HermesCredential?
    func save(_ credential: HermesCredential) throws
    func clear() throws
}

/// In-memory store for tests and previews.
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: HermesCredential?
    public init(_ initial: HermesCredential? = nil) { self.stored = initial }
    public func load() -> HermesCredential? { lock.withLock { stored } }
    public func save(_ credential: HermesCredential) throws { lock.withLock { stored = credential } }
    public func clear() throws { lock.withLock { stored = nil } }
}

/// Keychain-backed store. Server URL is stored as a generic password item; the
/// token is a second item so it can be wiped independently (remote-wipe, PRD §21).
public final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let service: String
    private let urlAccount = "hermes.server.url"
    private let tokenAccount = "hermes.session.token"

    public init(service: String = "com.senulmapa.hermesnative") {
        self.service = service
    }

    public func load() -> HermesCredential? {
        guard let urlString = readString(account: urlAccount),
              let url = URL(string: urlString) else { return nil }
        return HermesCredential(baseURL: url, sessionToken: readString(account: tokenAccount))
    }

    public func save(_ credential: HermesCredential) throws {
        try write(account: urlAccount, value: credential.baseURL.absoluteString)
        if let token = credential.sessionToken, !token.isEmpty {
            try write(account: tokenAccount, value: token)
        } else {
            try delete(account: tokenAccount)
        }
    }

    public func clear() throws {
        try delete(account: urlAccount)
        try delete(account: tokenAccount)
    }

    // MARK: - SecItem plumbing

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func readString(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(account: String, value: String) throws {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert.merge(attrs) { _, new in new }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw HermesError.network("Keychain write failed (\(addStatus))")
            }
        } else if status != errSecSuccess {
            throw HermesError.network("Keychain update failed (\(status))")
        }
    }

    private func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HermesError.network("Keychain delete failed (\(status))")
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
