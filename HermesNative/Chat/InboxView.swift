import SwiftUI
import HermesAPI
import HermesGlass

/// Sessions list — the entry point into chat.
struct InboxView: View {
    @Environment(AppModel.self) private var app
    @State private var store: InboxStore?

    var body: some View {
        NavigationStack {
            Group {
                if let store {
                    content(store)
                } else {
                    ContentUnavailableView("Not connected", systemImage: "wifi.slash",
                                           description: Text("Configure a server in Settings."))
                }
            }
            .navigationTitle("Inbox")
        }
        .task {
            guard store == nil, let cred = app.credential else { return }
            let s = InboxStore(credential: cred)
            store = s
            await s.refresh()
        }
    }

    @ViewBuilder
    private func content(_ store: InboxStore) -> some View {
        @Bindable var store = store
        switch store.state {
        case .idle, .loading where store.sessions.isEmpty:
            ProgressView("Loading sessions…").frame(maxHeight: .infinity)
        case .failed(let message) where store.sessions.isEmpty:
            ContentUnavailableView {
                Label("Couldn't load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await store.refresh() } }.buttonStyle(.glassProminent)
            }
        default:
            list(store)
        }
    }

    private func list(_ store: InboxStore) -> some View {
        @Bindable var store = store
        return List {
            ForEach(store.visibleSessions) { session in
                NavigationLink {
                    ChatView(session: session, credential: app.credential!)
                } label: {
                    row(session)
                }
            }
            .onDelete { indexSet in
                let targets = indexSet.map { store.visibleSessions[$0] }
                Task { for t in targets { await store.delete(t) } }
            }
        }
        .listStyle(.plain)
        .searchable(text: $store.searchText, prompt: "Search sessions")
        .refreshable { await store.refresh() }
    }

    private func row(_ session: ChatSession) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack {
                Text(session.displayTitle).font(.headline).lineLimit(1)
                if session.isActive {
                    Circle().fill(.green).frame(width: 8, height: 8)
                }
            }
            HStack(spacing: Tokens.Space.sm) {
                if let model = session.model {
                    Text(model).font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
                Text("\(session.messageCount) msgs")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Tokens.Space.xs)
    }
}
