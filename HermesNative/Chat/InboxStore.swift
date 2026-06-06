import SwiftUI
import HermesAPI

/// Loads and holds the session list for the Inbox.
@MainActor
@Observable
final class InboxStore {
    enum State: Equatable { case idle, loading, loaded, failed(String) }

    private let credential: HermesCredential
    var sessions: [ChatSession] = []
    var state: State = .idle
    var searchText: String = ""

    init(credential: HermesCredential) { self.credential = credential }

    var visibleSessions: [ChatSession] {
        guard !searchText.isEmpty else { return sessions }
        let q = searchText.lowercased()
        return sessions.filter {
            $0.displayTitle.lowercased().contains(q)
            || ($0.model?.lowercased().contains(q) ?? false)
        }
    }

    func refresh() async {
        if case .loaded = state {} else { state = .loading }
        do {
            sessions = try await HermesAPIClient(credential: credential).sessions()
            state = .loaded
        } catch let e as HermesError {
            state = .failed(e.userMessage)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func delete(_ session: ChatSession) async {
        sessions.removeAll { $0.id == session.id }
        try? await HermesAPIClient(credential: credential).deleteSession(session.id)
    }
}
