import SwiftUI
import HermesAPI
import HermesGlass

@main
struct HermesNativeApp: App {
    @State private var model = AppModel(store: KeychainCredentialStore())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Tokens.accent)
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
