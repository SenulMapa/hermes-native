import SwiftUI
import UIKit
import HermesAPI

/// An image/file picked in the composer but not yet uploaded. Held in memory
/// until `send()` uploads it and swaps in the server reference.
struct PendingAttachment: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let filename: String
    let mime: String
    var isImage: Bool { mime.hasPrefix("image/") }
}

/// Drives one conversation: loads REST history, opens the gateway socket, and
/// folds streaming events into a live transcript.
@MainActor
@Observable
final class ConversationModel {
    let session: ChatSession
    private let credential: HermesCredential
    private let drafts: DraftStore?
    private var gateway: HermesGateway?
    private var eventTask: Task<Void, Never>?
    private var tempCounter = -1

    struct PendingApproval: Identifiable, Equatable {
        let id: String
        let summary: String
    }

    var messages: [ChatMessage] = []
    var draft: String = ""
    var isStreaming = false
    var streamingText = ""
    var streamingThinking = ""
    var activeTools: [String] = []
    var pendingApproval: PendingApproval?
    var loadError: String?
    var note: String?

    // Composer affordances (Tier 1).
    var pendingAttachments: [PendingAttachment] = []
    var replyingTo: ChatMessage?
    var editing: ChatMessage?
    /// Non-nil after a successful `branch()`, observed by `ChatView` to navigate.
    var branchTarget: ChatSession?
    /// Surfaced to the user when a feedback/branch call fails.
    var actionError: String?
    /// Optimistic thumbs state, keyed by server message id (overrides the decoded value).
    private(set) var feedbackOverrides: [Int: Int] = [:]

    private var client: HermesAPIClient { HermesAPIClient(credential: credential) }

    init(session: ChatSession, credential: HermesCredential, drafts: DraftStore? = nil) {
        self.session = session
        self.credential = credential
        self.drafts = drafts
        self.draft = drafts?.draft(for: session.id) ?? ""
    }

    func load() async {
        do {
            messages = try await client.messages(sessionID: session.id)
        } catch let e as HermesError {
            loadError = e.userMessage
        } catch {
            loadError = error.localizedDescription
        }
    }

    func connect() {
        guard gateway == nil else { return }
        let gw = HermesGateway(baseURL: credential.baseURL, token: credential.sessionToken)
        gateway = gw
        gw.connect()
        gw.resume(sessionID: session.id)
        eventTask = Task { [weak self] in
            for await event in gw.events { self?.handle(event) }
        }
    }

    func disconnect() {
        eventTask?.cancel(); eventTask = nil
        gateway?.disconnect(); gateway = nil
    }

    // MARK: - Drafts

    /// Persist the current composer text. Called when leaving / backgrounding.
    func persistDraft() { drafts?.set(draft, for: session.id) }

    var canSend: Bool {
        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !pendingAttachments.isEmpty) && !isStreaming
    }

    // MARK: - Sending

    func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        // Editing a prior user message re-runs from that turn with new text,
        // via the server's truncate-before-user-ordinal rewind path.
        if let target = editing {
            let ordinal = userOrdinal(of: target)
            truncate(after: target.id, inclusive: true)
            messages.append(makeMessage(role: .user, content: text))
            editing = nil
            clearComposer()
            beginStreaming()
            gateway?.submitPrompt(sessionID: session.id, text: text,
                                  truncateBeforeUserOrdinal: ordinal)
            return
        }

        let attachmentsToSend = pendingAttachments
        let reply = replyingTo
        clearComposer()

        Task {
            var paths: [String] = []
            var rendered: [Attachment] = []
            for att in attachmentsToSend {
                do {
                    let up = try await client.uploadAttachment(
                        sessionID: session.id, data: att.data, filename: att.filename, mime: att.mime)
                    paths.append(up.path)
                    rendered.append(up.attachment)
                } catch let e as HermesError {
                    actionError = e.userMessage
                } catch {
                    actionError = error.localizedDescription
                }
            }
            messages.append(makeMessage(role: .user, content: text,
                                        attachments: rendered, replyToId: reply?.id))
            beginStreaming()
            gateway?.submitPrompt(sessionID: session.id, text: text,
                                  replyTo: reply?.id, attachmentPaths: paths)
        }
    }

    func interrupt() {
        gateway?.interrupt(sessionID: session.id)
        finishStreaming()
    }

    func respond(approved: Bool) {
        guard let approval = pendingApproval else { return }
        gateway?.respondApproval(id: approval.id, approved: approved)
        pendingApproval = nil
    }

    // MARK: - Message actions

    /// Re-run an assistant message: re-submit the user turn that produced it,
    /// truncating history from that turn onward (server rewind path).
    func regenerate(_ message: ChatMessage) {
        guard message.isPersisted, !isStreaming else { return }
        guard let mIdx = messages.firstIndex(where: { $0.id == message.id }),
              let uIdx = messages[..<mIdx].lastIndex(where: { $0.role == .user }) else { return }
        let user = messages[uIdx]
        let ordinal = userOrdinal(of: user)
        let text = user.content ?? ""
        guard !text.isEmpty else { return }
        messages.removeSubrange(uIdx...)
        messages.append(makeMessage(role: .user, content: text))
        beginStreaming()
        gateway?.submitPrompt(sessionID: session.id, text: text,
                              truncateBeforeUserOrdinal: ordinal)
    }

    /// 0-based index of a user message among all user-role messages — the
    /// `truncate_before_user_ordinal` the server expects.
    private func userOrdinal(of message: ChatMessage) -> Int {
        var n = 0
        for m in messages {
            if m.id == message.id { return n }
            if m.role == .user { n += 1 }
        }
        return n
    }

    /// Begin editing a prior user message: load it into the composer.
    func beginEdit(_ message: ChatMessage) {
        guard message.role == .user else { return }
        editing = message
        replyingTo = nil
        draft = message.content ?? ""
    }

    func cancelEdit() { editing = nil; draft = "" }

    /// Fork the conversation; on success sets `branchTarget` for the view to open.
    func requestBranch() {
        Task {
            do {
                let result = try await gateway?.branch(sessionID: session.id) ?? [:]
                // Prefer the DB session_key (works for REST history load + resume);
                // fall back to the transport session_id.
                guard let newID = (result["session_key"] as? String)
                        ?? (result["session_id"] as? String) else {
                    actionError = "Branch failed: no session id returned."; return
                }
                let title = result["title"] as? String
                branchTarget = ChatSession(id: newID, title: title, model: session.model)
            } catch let e as HermesError {
                actionError = e.userMessage
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    func effectiveFeedback(for message: ChatMessage) -> Int? {
        feedbackOverrides[message.id] ?? message.feedbackScore
    }

    func setFeedback(_ message: ChatMessage, score: Int, comment: String? = nil) {
        guard message.isPersisted else { return }
        // Toggle off if tapping the same thumb again.
        let newScore = (effectiveFeedback(for: message) == score) ? 0 : score
        let previous = feedbackOverrides[message.id]
        feedbackOverrides[message.id] = newScore
        Task {
            do {
                try await client.setFeedback(sessionID: session.id, messageID: message.id,
                                             score: newScore, comment: comment)
            } catch let e as HermesError {
                feedbackOverrides[message.id] = previous; actionError = e.userMessage
            } catch {
                feedbackOverrides[message.id] = previous; actionError = error.localizedDescription
            }
        }
    }

    /// Resolve a `reply_to_id` to its message for rendering the quoted chip.
    func message(withID id: Int) -> ChatMessage? { messages.first { $0.id == id } }

    // MARK: - Attachment loading (authenticated)

    /// Fetch an attachment's raw bytes through the authenticated REST client.
    func attachmentData(_ a: Attachment) async -> Data? {
        try? await client.attachmentData(sessionID: session.id, name: a.name)
    }

    /// Fetch and decode an attachment as a `UIImage` (nil for non-images / failures).
    func attachmentImage(_ a: Attachment) async -> UIImage? {
        guard let data = await attachmentData(a) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Event handling

    private func handle(_ event: GatewayEvent) {
        switch event {
        case .ready:
            note = nil
        case .messageStart:
            streamingText = ""; isStreaming = true
        case .messageDelta(let t):
            streamingText += t; isStreaming = true
        case .messageComplete(let text, _):
            let final = text.isEmpty ? streamingText : text
            if !final.isEmpty { messages.append(makeMessage(role: .assistant, content: final)) }
            finishStreaming()
        case .thinkingDelta(let t):
            streamingThinking += t; isStreaming = true
        case .toolStart(let name, let context):
            activeTools.append(name)
            messages.append(makeMessage(role: .tool, content: context ?? "", toolName: name))
        case .toolGenerating:
            break
        case .toolComplete(let name):
            if let n = name, let i = activeTools.firstIndex(of: n) { activeTools.remove(at: i) }
            else if !activeTools.isEmpty { activeTools.removeLast() }
        case .approvalRequest(let id, let summary):
            pendingApproval = PendingApproval(id: id ?? "", summary: summary ?? "Approve this action?")
        case .status(let s):
            note = s.isEmpty ? nil : s
        case .error(let m):
            note = m; finishStreaming()
        case .disconnected(let m):
            note = "Disconnected: \(m)"; isStreaming = false
        case .other:
            break
        }
    }

    // MARK: - Helpers

    private func beginStreaming() {
        streamingText = ""; streamingThinking = ""; activeTools = []
        isStreaming = true; note = nil
    }

    private func clearComposer() {
        draft = ""; pendingAttachments = []; replyingTo = nil
        drafts?.clear(for: session.id)
    }

    private func finishStreaming() {
        streamingText = ""; streamingThinking = ""; activeTools = []; isStreaming = false
    }

    /// Drop messages after `id`. When `inclusive`, also drop the message itself.
    private func truncate(after id: Int, inclusive: Bool) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        let cut = inclusive ? idx : idx + 1
        if cut < messages.count { messages.removeSubrange(cut...) }
    }

    private func makeMessage(role: MessageRole, content: String, toolName: String? = nil,
                             attachments: [Attachment] = [], replyToId: Int? = nil) -> ChatMessage {
        tempCounter -= 1
        return ChatMessage(id: tempCounter, role: role, content: content, toolName: toolName,
                           timestamp: Date().timeIntervalSince1970,
                           attachments: attachments, replyToId: replyToId)
    }
}
