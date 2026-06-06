import SwiftUI
import HermesAPI

/// Drives one conversation: loads REST history, opens the gateway socket, and
/// folds streaming events into a live transcript.
@MainActor
@Observable
final class ConversationModel {
    let session: ChatSession
    private let credential: HermesCredential
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

    init(session: ChatSession, credential: HermesCredential) {
        self.session = session
        self.credential = credential
    }

    func load() async {
        do {
            messages = try await HermesAPIClient(credential: credential).messages(sessionID: session.id)
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

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(makeMessage(role: .user, content: text))
        draft = ""
        streamingText = ""; streamingThinking = ""; activeTools = []
        isStreaming = true
        note = nil
        gateway?.submitPrompt(sessionID: session.id, text: text)
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

    private func finishStreaming() {
        streamingText = ""; streamingThinking = ""; activeTools = []; isStreaming = false
    }

    private func makeMessage(role: MessageRole, content: String, toolName: String? = nil) -> ChatMessage {
        tempCounter -= 1
        return ChatMessage(id: tempCounter, role: role, content: content, toolName: toolName,
                           timestamp: Date().timeIntervalSince1970)
    }
}
