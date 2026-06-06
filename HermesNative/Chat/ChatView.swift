import SwiftUI
import HermesAPI
import HermesGlass

/// A single conversation: scrollable transcript + live streaming + composer.
struct ChatView: View {
    let session: ChatSession
    let credential: HermesCredential
    @State private var convo: ConversationModel?

    var body: some View {
        VStack(spacing: 0) {
            if let convo {
                transcript(convo)
                composer(convo)
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if convo == nil {
                let model = ConversationModel(session: session, credential: credential)
                convo = model
                await model.load()
                model.connect()
            }
        }
        .onDisappear { convo?.disconnect() }
    }

    private func transcript(_ convo: ConversationModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    if let err = convo.loadError {
                        StatusPill(.bad(err)).frame(maxWidth: .infinity)
                    }
                    ForEach(convo.messages) { MessageView(message: $0) }

                    if convo.isStreaming || !convo.streamingText.isEmpty {
                        streamingBubble(convo).id("streaming")
                    }
                    if let note = convo.note {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(Tokens.Space.lg)
            }
            .onChange(of: convo.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: convo.streamingText) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func streamingBubble(_ convo: ConversationModel) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.sm) {
                ProgressView().controlSize(.small)
                if !convo.activeTools.isEmpty {
                    Text(convo.activeTools.joined(separator: ", "))
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                } else {
                    Text("Valerie is thinking…").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !convo.streamingThinking.isEmpty {
                Text(convo.streamingThinking)
                    .font(.caption.italic()).foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if !convo.streamingText.isEmpty {
                MarkdownMessage(convo.streamingText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func composer(_ convo: ConversationModel) -> some View {
        @Bindable var convo = convo
        return HStack(spacing: Tokens.Space.sm) {
            TextField("Message Hermes…", text: $convo.draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, Tokens.Space.sm)
                .glassEffect(.regular, in: .capsule)

            if convo.isStreaming {
                Button { convo.interrupt() } label: {
                    Image(systemName: "stop.circle.fill").font(.title2)
                }
                .tint(.red)
            } else {
                Button { convo.send() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .disabled(!convo.canSend)
            }
        }
        .padding(Tokens.Space.md)
        .background(.bar)
    }
}
