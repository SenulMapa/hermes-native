import Foundation

/// Decoded events streamed from the Hermes gateway (`/api/ws`). Covers the text
/// chat path now; tool/approval cases are surfaced for Phase 5.
public enum GatewayEvent: Sendable, Equatable {
    case ready
    case messageStart
    case messageDelta(String)
    case messageComplete(text: String, status: String?)
    case thinkingDelta(String)
    case toolStart(name: String, context: String?)
    case toolGenerating(name: String)
    case toolComplete(name: String?)
    case approvalRequest(id: String?, summary: String?)
    case status(String)
    case error(String)
    case disconnected(String)
    case other(type: String)
}

/// JSON-RPC 2.0 client for the Hermes gateway WebSocket. Sends `prompt.submit`
/// and friends; vends an `AsyncStream<GatewayEvent>` of decoded server frames.
public final class HermesGateway: @unchecked Sendable {
    private let url: URL
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var nextID = 1
    private let idLock = NSLock()

    public let events: AsyncStream<GatewayEvent>
    private let continuation: AsyncStream<GatewayEvent>.Continuation

    public init(baseURL: URL, token: String?, session: URLSession = .shared) {
        self.session = session
        self.url = Self.websocketURL(from: baseURL, token: token)
        var cont: AsyncStream<GatewayEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    /// http(s)://host:port  ->  ws(s)://host:port/api/ws?token=…
    static func websocketURL(from base: URL, token: String?) -> URL {
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) ?? URLComponents()
        comps.scheme = (base.scheme == "https") ? "wss" : "ws"
        comps.path = (comps.path as NSString).appendingPathComponent("/api/ws")
        if let token, !token.isEmpty {
            comps.queryItems = [.init(name: "token", value: token)]
        }
        return comps.url ?? base
    }

    public func connect() {
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receiveLoop()
    }

    public func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        continuation.finish()
    }

    // MARK: - Requests

    public func submitPrompt(sessionID: String, text: String) {
        request("prompt.submit", ["session_id": sessionID, "text": text])
    }

    public func resume(sessionID: String) {
        request("session.resume", ["session_id": sessionID])
    }

    public func createSession(model: String? = nil) {
        var params: [String: Any] = [:]
        if let model { params["model"] = model }
        request("session.create", params)
    }

    public func interrupt(sessionID: String) {
        request("session.interrupt", ["session_id": sessionID])
    }

    public func respondApproval(id: String, approved: Bool) {
        request("approval.respond", ["id": id, "approved": approved])
    }

    private func request(_ method: String, _ params: [String: Any]) {
        idLock.lock(); let id = nextID; nextID += 1; idLock.unlock()
        let frame: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method, "params": params]
        guard let data = try? JSONSerialization.data(withJSONObject: frame),
              let string = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(string)) { [weak self] error in
            if let error { self?.continuation.yield(.error(error.localizedDescription)) }
        }
    }

    // MARK: - Receive

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.continuation.yield(.disconnected(error.localizedDescription))
                self.continuation.finish()
            case .success(let message):
                switch message {
                case .string(let text): self.handle(text)
                case .data(let data): self.handle(String(decoding: data, as: UTF8.self))
                @unknown default: break
                }
                self.receiveLoop()
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if let err = obj["error"] as? [String: Any] {
            continuation.yield(.error(err["message"] as? String ?? "gateway error"))
            return
        }
        guard (obj["method"] as? String) == "event",
              let params = obj["params"] as? [String: Any],
              let type = params["type"] as? String else { return }
        let payload = params["payload"] as? [String: Any] ?? [:]
        continuation.yield(Self.map(type: type, payload: payload))
    }

    static func map(type: String, payload: [String: Any]) -> GatewayEvent {
        switch type {
        case "gateway.ready":     return .ready
        case "message.start":     return .messageStart
        case "message.delta":     return .messageDelta(payload["text"] as? String ?? "")
        case "message.complete":  return .messageComplete(text: payload["text"] as? String ?? "",
                                                           status: payload["status"] as? String)
        case "thinking.delta":    return .thinkingDelta(payload["text"] as? String ?? "")
        case "tool.start":        return .toolStart(name: payload["name"] as? String ?? "tool",
                                                     context: payload["context"] as? String)
        case "tool.generating":   return .toolGenerating(name: payload["name"] as? String ?? "tool")
        case "tool.complete":     return .toolComplete(name: payload["name"] as? String)
        case "approval.request":  return .approvalRequest(id: payload["id"] as? String,
                                                           summary: payload["summary"] as? String
                                                            ?? payload["context"] as? String)
        case "status.update":     return .status(payload["text"] as? String ?? payload["message"] as? String ?? "")
        case "error":             return .error(payload["message"] as? String ?? "error")
        default:                  return .other(type: type)
        }
    }
}
