import SwiftUI
import HermesAPI
import HermesGlass

@main
struct HermesNativeApp: App {
    @State private var model = AppModel(store: KeychainCredentialStore())
    @State private var appearance = AppearanceStore()
    @State private var speech = SpeechService()
    @State private var notifications = NotificationService()
    @State private var appLock = AppLock()
    @State private var drafts = DraftStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(appearance)
                .environment(speech)
                .environment(notifications)
                .environment(appLock)
                .environment(drafts)
                .tint(appearance.accentColor)
                .hermesTheme(appearance.theme)
                .preferredColorScheme(appearance.scheme.colorScheme)
                .overlay { if appLock.enabled && !appLock.unlocked { LockScreen() } }
                .task(id: appLock.unlocked) { await appLock.authenticate() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { appLock.lock() }
                }
        }
    }
}

/// Full-screen biometric gate shown while the app is locked.
struct LockScreen: View {
    @Environment(AppLock.self) private var appLock
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 48, weight: .thin))
                Text("Hermes is locked").font(.headline)
                Button("Unlock") { Task { await appLock.authenticate() } }
                    .buttonStyle(.glassProminent)
            }
        }
    }
}

/// Routes between onboarding and the main shell based on whether a server is configured.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.isConfigured {
                AppShell()
            } else {
                ConnectView()
            }
        }
        .task {
            if model.isConfigured { await model.refresh() }
        }
    }
}
