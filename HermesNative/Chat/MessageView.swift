import SwiftUI
import HermesAPI
import HermesGlass

/// Renders a single stored message by role.
struct MessageView: View {
    let message: ChatMessage
    @Environment(\.hermesTheme) private var theme

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
            Label("Valerie", systemImage: "sparkle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.accent)
            MarkdownMessage(message.content ?? "")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var toolRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "wrench.and.screwdriver.fill")
            Text(message.toolName ?? "tool").font(.caption.monospaced())
            if let c = message.content, !c.isEmpty {
                Text("·").foregroundStyle(.secondary)
                Text(c).font(.caption).lineLimit(1).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .glassEffect(.regular, in: .capsule)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systemRow: some View {
        Text(message.content ?? "")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
