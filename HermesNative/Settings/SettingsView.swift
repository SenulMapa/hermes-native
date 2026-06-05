import SwiftUI
import HermesGlass

/// Phase 0 settings: connection status, server info, version, sign-out.
/// Expands into the full PRD §15 settings in Phase 3.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    connectionCard
                    aboutCard
                }
                .padding(Tokens.Space.lg)
            }
            .navigationTitle("Settings")
            .refreshable { await model.refresh() }
        }
    }

    private var connectionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Connection").font(.headline)
                statusPill
                if let url = model.credential?.baseURL {
                    LabeledContent("Server", value: url.absoluteString)
                        .font(.subheadline)
                }
                HStack(spacing: Tokens.Space.md) {
                    Button("Re-check") { Task { await model.refresh() } }
                        .buttonStyle(.glass)
                    Button("Sign out", role: .destructive) { model.signOut() }
                        .buttonStyle(.glass)
                }
                .padding(.top, Tokens.Space.xs)
            }
        }
    }

    @ViewBuilder private var statusPill: some View {
        switch model.connection {
        case .unconfigured: StatusPill(.bad("Not configured"))
        case .connecting:   StatusPill(.busy("Connecting…"))
        case .online(let authed, let session):
            StatusPill(.ok(authed ? "Connected\(session?.displayName.map { " · \($0)" } ?? "")" : "Reachable (no token)"))
        case .offline(let error): StatusPill(.bad(error.userMessage))
        }
    }

    private var aboutCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("About").font(.headline)
                LabeledContent("Version", value: Self.appVersion)
                LabeledContent("Updates", value: "via AltStore")
                Text("New builds arrive over-the-air through your AltStore source.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
