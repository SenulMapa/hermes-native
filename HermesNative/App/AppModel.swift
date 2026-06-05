import SwiftUI
import HermesAPI

/// Root app state (Observation framework). Owns the credential and the live
/// connection state, and runs the Phase 0 connectivity probe.
@MainActor
@Observable
final class AppModel {
    enum Connection: Equatable {
        case unconfigured
        case connecting
        /// Reachable Hermes server. `authed` reflects whether the session token validated.
        case online(authed: Bool, session: Session?)
        case offline(HermesError)
    }

    private let store: CredentialStore
    private(set) var credential: HermesCredential?
    var connection: Connection = .unconfigured

    init(store: CredentialStore) {
        self.store = store
        self.credential = store.load()
        self.connection = credential == nil ? .unconfigured : .connecting
    }

    var isConfigured: Bool { credential != nil }

    /// Onboarding entry point: validate a typed URL (+ optional token) and, if
    /// the server is reachable, persist it and switch into the app.
    func connect(baseURLString: String, token: String?) async {
        guard let url = Self.normalizedURL(baseURLString) else {
            connection = .offline(.invalidBaseURL(baseURLString))
            return
        }
        let cleanToken = (token?.isEmpty ?? true) ? nil : token
        let cred = HermesCredential(baseURL: url, sessionToken: cleanToken)
        await probe(cred, persistOnReachable: true)
    }

    /// Re-check the stored connection (Settings pull, launch).
    func refresh() async {
        guard let credential else { connection = .unconfigured; return }
        await probe(credential, persistOnReachable: false)
    }

    func signOut() {
        try? store.clear()
        credential = nil
        connection = .unconfigured
    }

    private func probe(_ cred: HermesCredential, persistOnReachable: Bool) async {
        connection = .connecting
        let client = HermesAPIClient(credential: cred)
        do {
            _ = try await client.providers()          // public reachability probe
            if persistOnReachable {
                try? store.save(cred)
                credential = cred
            }
            guard cred.sessionToken != nil else {
                connection = .online(authed: false, session: nil)
                return
            }
            do {
                let session = try await client.me()    // authenticated check
                connection = .online(authed: true, session: session)
            } catch {
                connection = .online(authed: false, session: nil)
            }
        } catch let e as HermesError {
            connection = .offline(e)
        } catch {
            connection = .offline(.network((error as NSError).localizedDescription))
        }
    }

    /// Accept "senuls-nas:8765" or full URLs; default scheme to http (tailnet).
    static func normalizedURL(_ s: String) -> URL? {
        var str = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return nil }
        if !str.contains("://") { str = "http://" + str }
        guard let url = URL(string: str), url.host != nil else { return nil }
        return url
    }
}
