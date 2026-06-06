import SwiftUI
import HermesAPI

/// Loads and holds the session list for the Inbox.
@MainActor
@Observable
final class InboxStore {
    enum State: Equatable { case idle, loading, loaded, failed(String) }

    private let credential: HermesCredential
    var sessions: [ChatSession] = []
    var searchResults: [ChatSession] = []
    var state: State = .idle
    var searchText: String = ""

    init(credential: HermesCredential) { self.credential = credential }

    private var client: HermesAPIClient { HermesAPIClient(credential: credential) }

    /// Local filter fallback (instant) merged with server full-text results.
    var visibleSessions: [ChatSession] {
        guard !searchText.isEmpty else { return sessions }
        let q = searchText.lowercased()
        let local = sessions.filter {
            $0.displayTitle.lowercased().contains(q) || ($0.model?.lowercased().contains(q) ?? false)
        }
        // Merge server results, de-duplicated by id, server first.
        var seen = Set(searchResults.map(\.id))
        return searchResults + local.filter { seen.insert($0.id).inserted }
    }

    /// Full-text server search (PRD §3.4); call as the query changes.
    func runSearch() async {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { searchResults = []; return }
        searchResults = (try? await client.searchSessions(q)) ?? []
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
