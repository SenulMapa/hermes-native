import SwiftUI
import HermesAPI
import HermesGlass

/// Telegram & other messaging bridges (PRD §15.6).
@MainActor
@Observable
final class MessagingStore {
    private let credential: HermesCredential
    var platforms: [MessagingPlatform] = []
    var error: String?
    init(credential: HermesCredential) { self.credential = credential }
    private var client: HermesAPIClient { HermesAPIClient(credential: credential) }

    func load() async {
        do { platforms = try await client.messagingPlatforms() }
        catch let e as HermesError { error = e.userMessage }
        catch { error = error.localizedDescription }
    }
    func toggle(_ p: MessagingPlatform) async {
        try? await client.setMessagingPlatform(p.id, enabled: !p.enabled)
        await load()
    }
    func test(_ p: MessagingPlatform) async { try? await client.testMessagingPlatform(p.id) }
}

struct MessagingView: View {
    let credential: HermesCredential
    @State private var store: MessagingStore?

    var body: some View {
        List {
            if let store, !store.platforms.isEmpty {
                ForEach(store.platforms) { platform in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(platform.name.capitalized).font(.headline)
                            if let mode = platform.mode {
                                Text(mode).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(platform.enabled ? "On" : "Off") {
                            Task { await store.toggle(platform) }
                        }
                        .buttonStyle(.glass)
                        .tint(platform.enabled ? .green : .secondary)
                    }
                    .swipeActions {
                        Button("Test") { Task { await store.test(platform) } }.tint(.blue)
                    }
                }
            } else {
                ContentUnavailableView("No platforms", systemImage: "message",
                                       description: Text("No messaging bridges reported by the server."))
            }
        }
        .navigationTitle("Messaging")
        .task {
            if store == nil {
                let s = MessagingStore(credential: credential)
                store = s
                await s.load()
            }
        }
    }
}
