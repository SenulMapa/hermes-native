import Foundation
import Security

/// A saved SSH host. Secrets (password) live in the Keychain keyed by `id`,
/// never in this Codable metadata.
public struct SSHHost: Codable, Identifiable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var host: String
    public var port: Int
    public var username: String

    public init(id: String = UUID().uuidString, name: String, host: String,
                port: Int = 22, username: String) {
        self.id = id; self.name = name; self.host = host
        self.port = port; self.username = username
    }

    public var subtitle: String { "\(username)@\(host):\(port)" }
}

/// Persists host metadata (UserDefaults) and per-host passwords (Keychain).
@MainActor
@Observable
public final class HostStore {
    private let key = "hermes.ssh.hosts"
    private let defaults: UserDefaults
    public private(set) var hosts: [SSHHost] = []

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SSHHost].self, from: data) else { return }
        hosts = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(hosts) { defaults.set(data, forKey: key) }
    }

    public func add(_ host: SSHHost, password: String?) {
        hosts.append(host)
        persist()
        if let password { SSHSecrets.savePassword(password, for: host.id) }
    }

    public func remove(_ host: SSHHost) {
        hosts.removeAll { $0.id == host.id }
        persist()
        SSHSecrets.deletePassword(for: host.id)
    }

    public func password(for host: SSHHost) -> String? {
        SSHSecrets.password(for: host.id)
    }
}

/// Tiny Keychain wrapper for SSH passwords.
enum SSHSecrets {
    private static let service = "com.senulmapa.hermesnative.ssh"

    static func savePassword(_ password: String, for id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        if SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var insert = query
            insert.merge(attrs) { _, new in new }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    static func password(for id: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deletePassword(for id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
