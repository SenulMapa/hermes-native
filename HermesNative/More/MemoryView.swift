import SwiftUI
import HermesAPI
import HermesGlass

/// Read-only view of what Hermes remembers (PRD §3.5). Degrades gracefully if
/// the server exposes no memory endpoint.
struct MemoryView: View {
    let credential: HermesCredential
    @State private var text: String?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            if let text, !text.isEmpty {
                MarkdownMessage(text).padding(Tokens.Space.lg)
            } else if loaded {
                ContentUnavailableView("No memory", systemImage: "brain",
                                       description: Text("This server doesn't expose a memory view."))
                    .padding(.top, Tokens.Space.xxl)
            } else {
                ProgressView().padding(.top, Tokens.Space.xxl)
            }
        }
        .navigationTitle("Memory")
        .task {
            text = try? await HermesAPIClient(credential: credential).memoryText()
            loaded = true
        }
    }
}
