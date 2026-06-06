import SwiftUI
import HermesGlass

/// The main navigation surface. iOS 26 `TabView` is Liquid Glass by default;
/// `.sidebarAdaptable` gives iPad/Mac a sidebar. Phase 0 ships placeholder
/// destinations — each fills in on its phase.
struct AppShell: View {
    var body: some View {
        TabView {
            Tab("Inbox", systemImage: "tray.full") {
                InboxView()
            }
            Tab("Terminal", systemImage: "terminal") {
                PlaceholderView(
                    title: "Terminal",
                    systemImage: "terminal",
                    detail: "Full SSH PTY — vim, htop, lazygit.",
                    phase: "Phase 2"
                )
            }
            Tab("Cron", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                PlaceholderView(
                    title: "Cron",
                    systemImage: "clock",
                    detail: "Scheduled tasks, plain-English schedules.",
                    phase: "Phase 4"
                )
            }
            Tab("Projects", systemImage: "folder") {
                PlaceholderView(
                    title: "Projects",
                    systemImage: "folder",
                    detail: "Files, terminal, git & cost per project.",
                    phase: "Phase 6"
                )
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
