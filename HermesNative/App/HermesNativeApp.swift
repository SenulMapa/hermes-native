import SwiftUI
import HermesAPI
import HermesGlass

@main
struct HermesNativeApp: App {
    @State private var model = AppModel(store: KeychainCredentialStore())
    @State private var appearance = AppearanceStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(appearance)
                .tint(appearance.accentColor)
                .hermesTheme(appearance.theme)
                .preferredColorScheme(appearance.scheme.colorScheme)
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
