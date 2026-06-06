import SwiftUI
import HermesAPI
import HermesGlass

/// Renders a single stored message by role.
struct MessageView: View {
    let message: ChatMessage
    @Environment(\.hermesTheme) private var theme
    @Environment(SpeechService.self) private var speech

    var body: some View {
        switch message.role {
        case .user:      userBubble
        case .assistant: assistantBlock
        case .tool:      toolRow
        case .system, .unknown: systemRow
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: Tokens.Space.xxl)
            MarkdownMessage(message.content ?? "")
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.md)
                .glassEffect(.regular.tint(theme.accent.opacity(0.22)),
                             in: .rect(cornerRadius: Tokens.Radius.card))
        }
    }

    private var assistantBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Label("Valerie", systemImage: "sparkle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                Spacer()
                Button {
                    if speech.isSpeaking { speech.stopSpeaking() }
                    else { speech.speak(message.content ?? "") }
                } label: {
                    Image(systemName: speech.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .tint(.secondary)
            }
            MarkdownMessage(message.content ?? "")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let subAgents: Set<String> = ["maya", "vigil", "thursday", "valerie"]

    private var isSubAgent: Bool {
        guard let name = message.toolName?.lowercased() else { return false }
        return Self.subAgents.contains(name)
    }

    private var toolRow: some View {
        GlassCard(cornerRadius: Tokens.Radius.control, padding: Tokens.Space.md) {
            HStack(alignment: .top, spacing: Tokens.Space.sm) {
                Image(systemName: isSubAgent ? "person.2.fill" : "wrench.and.screwdriver.fill")
                    .foregroundStyle(isSubAgent ? theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSubAgent ? "\(message.toolName?.capitalized ?? "Agent")" : (message.toolName ?? "tool"))
                        .font(.caption.weight(.semibold).monospaced())
                    if let c = message.content, !c.isEmpty {
                        Text(c).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systemRow: some View {
        Text(message.content ?? "")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
