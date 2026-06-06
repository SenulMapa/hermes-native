import Foundation
import NIOCore
import NIOSSH
import Crypto
import Security

/// Trust-on-first-use host-key pinning (PRD §21). On first connect the host's
/// key fingerprint is stored; subsequent connects must present the same key or
/// the connection is refused. Never blindly accepts a changed key.
final class TOFUHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let host: String
    init(host: String) { self.host = host }

    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        // Apple's NIOSSHPublicKey exposes no public byte serializer; the OpenSSH
        // string ("ssh-ed25519 AAAA…") is stable across launches — fingerprint that.
        let openSSHString = String(openSSHPublicKey: hostKey)
        let fingerprint = Data(SHA256.hash(data: Data(openSSHString.utf8)))

        if let known = HostKeyStore.fingerprint(for: host) {
            if known == fingerprint {
                validationCompletePromise.succeed(())
            } else {
                validationCompletePromise.fail(HostKeyMismatch(host: host))
            }
        } else {
            HostKeyStore.save(fingerprint, for: host)
            validationCompletePromise.succeed(())
        }
    }
}

/// Raised when a pinned host key no longer matches — a possible MITM.
public struct HostKeyMismatch: Error, CustomStringConvertible {
    public let host: String
    public var description: String {
        "Host key for \(host) changed since first connection — refusing to connect."
    }
}

/// Keychain-backed store of pinned host-key fingerprints.
public enum HostKeyStore {
    private static let service = "com.senulmapa.hermesnative.ssh.hostkey"

    static func fingerprint(for host: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    static func save(_ fingerprint: Data, for host: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: fingerprint,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        if SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var insert = query
            insert.merge(attrs) { _, new in new }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    /// Forget a pinned key (e.g. user re-keyed the host deliberately).
    public static func forget(host: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
