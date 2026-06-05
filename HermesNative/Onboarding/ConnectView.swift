import SwiftUI
import HermesGlass

/// First-run connection screen: enter the Hermes server URL (+ optional session
/// token) and validate before persisting.
struct ConnectView: View {
    @Environment(AppModel.self) private var model
    @State private var urlText: String = "http://senuls-nas:8765"
    @State private var tokenText: String = ""

    var body: some View {
        ZStack {
            backdrop
            ScrollView {
                VStack(spacing: Tokens.Space.xl) {
                    header
                    GlassCard {
                        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                            field(
                                title: "Server URL",
                                systemImage: "server.rack",
                                text: $urlText,
                                prompt: "http://senuls-nas:8765",
                                keyboard: .URL
                            )
                            field(
                                title: "Session token (optional)",
                                systemImage: "key.fill",
                                text: $tokenText,
                                prompt: "paste from the Hermes web dashboard",
                                keyboard: .default,
                                secure: true
                            )
                            statusRow
                            GlassActionButton("Connect", systemImage: "bolt.fill") {
                                Task { await model.connect(baseURLString: urlText, token: tokenText) }
                            }
                            .disabled(isConnecting)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.xl)
                }
                .padding(.top, Tokens.Space.xxl)
            }
        }
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [Tokens.accent.opacity(0.35), .black.opacity(0.05)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: Tokens.Space.sm) {
            Image(systemName: "infinity")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(Tokens.accent)
            Text("Hermes").font(.largeTitle.bold())
            Text("Connect to your agent")
                .font(.headline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var statusRow: some View {
        switch model.connection {
        case .connecting:
            StatusPill(.busy("Connecting…"))
        case .online(let authed, let session):
            StatusPill(.ok(authed ? "Signed in\(session?.displayName.map { " · \($0)" } ?? "")" : "Reachable (no token)"))
        case .offline(let error):
            StatusPill(.bad(error.userMessage))
        case .unconfigured:
            EmptyView()
        }
    }

    private var isConnecting: Bool {
        if case .connecting = model.connection { return true }
        return false
    }

    private func field(
        title: String,
        systemImage: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType,
        secure: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Group {
                if secure {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .textFieldStyle(.plain)
            .padding(Tokens.Space.md)
            .glassEffect(.regular, in: .rect(cornerRadius: Tokens.Radius.control))
        }
    }
}
