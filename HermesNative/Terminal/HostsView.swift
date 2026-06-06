import SwiftUI
import HermesTerminal
import HermesGlass

/// SSH host list — entry point into terminal sessions.
struct HostsView: View {
    @State private var store = HostStore()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if store.hosts.isEmpty {
                    ContentUnavailableView {
                        Label("No hosts yet", systemImage: "terminal")
                    } description: {
                        Text("Add an SSH host to open a full PTY terminal.")
                    } actions: {
                        Button("Add host") { showAdd = true }.buttonStyle(.glassProminent)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Terminal")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddHostView(store: store) }
        }
    }

    private var list: some View {
        List {
            ForEach(store.hosts) { host in
                NavigationLink {
                    TerminalScreen(host: host, store: store)
                } label: {
                    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                        Text(host.name).font(.headline)
                        Text(host.subtitle).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Tokens.Space.xs)
                }
            }
            .onDelete { idx in idx.map { store.hosts[$0] }.forEach(store.remove) }
        }
        .listStyle(.plain)
    }
}
