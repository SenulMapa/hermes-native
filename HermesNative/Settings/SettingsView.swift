import SwiftUI
import HermesAPI
import HermesGlass

/// Settings: connection, model selection, usage/cost, appearance, about.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppearanceStore.self) private var appearance
    @Environment(NotificationService.self) private var notifications
    @State private var settings: SettingsStore?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    connectionCard
                    if let settings {
                        modelCard(settings)
                        usageCard(settings)
                    }
                    appearanceCard
                    notificationsCard
                    aboutCard
                }
                .padding(Tokens.Space.lg)
            }
            .navigationTitle("Settings")
            .refreshable { await reload() }
            .task {
                if settings == nil, let cred = model.credential {
                    let s = SettingsStore(credential: cred)
                    settings = s
                    await s.load()
                }
            }
        }
    }

    private func reload() async {
        await model.refresh()
        await settings?.load()
    }

    private var connectionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Connection").font(.headline)
                statusPill
                if let url = model.credential?.baseURL {
                    LabeledContent("Server", value: url.absoluteString).font(.subheadline)
                }
                HStack(spacing: Tokens.Space.md) {
                    Button("Re-check") { Task { await model.refresh() } }.buttonStyle(.glass)
                    Button("Sign out", role: .destructive) { model.signOut() }.buttonStyle(.glass)
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

    private func modelCard(_ settings: SettingsStore) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Model").font(.headline)
                NavigationLink {
                    ModelsView(store: settings)
                } label: {
                    HStack {
                        Text(settings.currentModel ?? "Default")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                if settings.models.isEmpty && !settings.loading {
                    Text("No model catalog returned by the server.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private func usageCard(_ settings: SettingsStore) -> some View {
        if !settings.usage.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Text("Usage").font(.headline)
                    ForEach(settings.usage.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(prettify(key), value: format(key: key, value: value))
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private var appearanceCard: some View {
        @Bindable var appearance = appearance
        return GlassCard {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Appearance").font(.headline)
                Picker("Theme", selection: $appearance.scheme) {
                    ForEach(AppearanceStore.Scheme.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Text("Accent").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: Tokens.Space.md) {
                    ForEach(AppearanceStore.accents) { accent in
                        Circle()
                            .fill(accent.color)
                            .frame(width: 30, height: 30)
                            .overlay {
                                if accent.id == appearance.accentName {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { appearance.accentName = accent.id }
                    }
                }
            }
        }
    }

    private var notificationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Notifications").font(.headline)
                HStack {
                    StatusPill(notifications.authorized ? .ok("Enabled") : .bad("Off"))
                    Spacer()
                    if !notifications.authorized {
                        Button("Enable") { Task { await notifications.requestAuthorization() } }
                            .buttonStyle(.glass)
                    }
                }
                Text("Local alerts for cron results and finished sub-agents. Remote push requires server setup.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .task { await notifications.refreshStatus() }
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

    // MARK: - helpers

    private func prettify(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func format(key: String, value: Double) -> String {
        if key.contains("cost") || key.contains("dollar") || key.contains("usd") {
            return String(format: "$%.2f", value)
        }
        if value >= 1000 { return String(format: "%.0f", value) }
        return value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value)
    }

    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
