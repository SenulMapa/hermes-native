import SwiftUI
import UIKit
import HermesAPI
import HermesGlass

/// Renders a single stored message by role, with Tier 1 affordances:
/// attachments, reply chip, context-menu actions, thumbs, and swipe-to-reply.
struct MessageView: View {
    let message: ChatMessage
    let convo: ConversationModel
    @Environment(\.hermesTheme) private var theme
    @Environment(SpeechService.self) private var speech
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        content
            .offset(x: dragOffset)
            .overlay(alignment: .leading) {
                if dragOffset > 8 {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .foregroundStyle(theme.accent)
                        .opacity(Double(min(dragOffset / 60, 1)))
                }
            }
            .simultaneousGesture(swipeToReply)
    }

    @ViewBuilder private var content: some View {
        switch message.role {
        case .user:      userBubble
        case .assistant: assistantBlock
        case .tool:      toolRow
        case .system, .unknown: systemRow
        }
    }

    // MARK: - Swipe to reply (works inside the ScrollView, unlike List swipeActions)

    private var swipeToReply: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = max(0, min(value.translation.width, 80))
            }
            .onEnded { value in
                if dragOffset > 56 { convo.replyingTo = message }
                withAnimation(.spring(duration: 0.25)) { dragOffset = 0 }
            }
    }

    // MARK: - User

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: Tokens.Space.xs) {
            if let reply = replyTarget { replyChip(reply) }
            if !message.attachments.isEmpty {
                MessageAttachments(convo: convo, attachments: message.attachments)
            }
            if let text = message.content, !text.isEmpty {
                HStack {
                    Spacer(minLength: Tokens.Space.xxl)
                    MarkdownMessage(text)
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.vertical, Tokens.Space.md)
                        .glassEffect(.regular.tint(theme.accent.opacity(0.22)),
                                     in: .rect(cornerRadius: Tokens.Radius.card))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contextMenu { userMenu }
    }

    @ViewBuilder private var userMenu: some View {
        Button { UIPasteboard.general.string = message.content } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        Button { convo.replyingTo = message } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
        if message.isPersisted {
            Button { convo.beginEdit(message) } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button { convo.requestBranch() } label: {
                Label("Branch from here", systemImage: "arrow.triangle.branch")
            }
        }
    }

    // MARK: - Assistant

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
            if let reply = replyTarget { replyChip(reply) }
            MarkdownMessage(message.content ?? "")
            if message.isPersisted { assistantFooter }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu { assistantMenu }
    }

    private var assistantFooter: some View {
        let score = convo.effectiveFeedback(for: message)
        return HStack(spacing: Tokens.Space.md) {
            Button { convo.setFeedback(message, score: 1) } label: {
                Image(systemName: score == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            .accessibilityLabel("Good response")
            Button { convo.setFeedback(message, score: -1) } label: {
                Image(systemName: score == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }
            .accessibilityLabel("Bad response")
            Spacer()
        }
        .font(.caption)
        .buttonStyle(.borderless)
        .tint(.secondary)
    }

    @ViewBuilder private var assistantMenu: some View {
        Button { UIPasteboard.general.string = message.content } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        Button { convo.replyingTo = message } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
        if message.isPersisted {
            Button { convo.regenerate(message) } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
            Button { convo.requestBranch() } label: {
                Label("Branch from here", systemImage: "arrow.triangle.branch")
            }
        }
    }

    // MARK: - Reply chip

    private var replyTarget: ChatMessage? {
        guard let id = message.replyToId else { return nil }
        return convo.message(withID: id)
    }

    private func replyChip(_ target: ChatMessage) -> some View {
        HStack(spacing: Tokens.Space.xs) {
            Rectangle().fill(theme.accent).frame(width: 3)
            Text(target.content ?? "attachment")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: 240, alignment: .leading)
    }

    // MARK: - Tool / system

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
