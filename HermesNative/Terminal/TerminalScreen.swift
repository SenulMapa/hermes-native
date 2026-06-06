import SwiftUI
import HermesTerminal
import HermesGlass

/// A live SSH PTY session for one host.
struct TerminalScreen: View {
    let host: SSHHost
    let store: HostStore
    @State private var session: TerminalSession?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if let session {
                SSHTerminalView(session: session)
                    .ignoresSafeArea(.container, edges: .bottom)
                statusBar(session)
            } else {
                ProgressView("Preparing…").frame(maxHeight: .infinity)
            }
        }
        .navigationTitle(host.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Disconnect", role: .destructive) { session?.stop() }
            }
        }
        .task {
            guard session == nil else { return }
            session = TerminalSession(host: host, password: store.password(for: host) ?? "")
        }
        .onDisappear { session?.stop() }
    }

    @ViewBuilder
    private func statusBar(_ session: TerminalSession) -> some View {
        switch session.state {
        case .connecting:
            StatusPill(.busy("Connecting to \(host.host)…")).padding(.top, Tokens.Space.sm)
        case .failed(let message):
            StatusPill(.bad(message)).padding(.top, Tokens.Space.sm)
        case .closed:
            StatusPill(.bad("Disconnected")).padding(.top, Tokens.Space.sm)
        case .connected, .idle:
            EmptyView()
        }
    }
}
