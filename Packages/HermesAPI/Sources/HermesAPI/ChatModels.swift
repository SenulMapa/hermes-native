import Foundation

/// A conversation, from `GET /api/sessions` (`db.list_sessions_rich`).
public struct ChatSession: Decodable, Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String?
    public let model: String?
    public let source: String?
    public let messageCount: Int
    public let preview: String?
    public let startedAt: Double?
    public let lastActive: Double?
    public let endedAt: Double?
    public let isActive: Bool
    public let archived: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, model, source, preview
        case messageCount = "message_count"
        case startedAt = "started_at"
        case lastActive = "last_active"
        case endedAt = "ended_at"
        case isActive = "is_active"
        case archived
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        preview = try c.decodeIfPresent(String.self, forKey: .preview)
        messageCount = (try? c.decode(Int.self, forKey: .messageCount)) ?? 0
        startedAt = try c.decodeIfPresent(Double.self, forKey: .startedAt)
        lastActive = try c.decodeIfPresent(Double.self, forKey: .lastActive)
        endedAt = try c.decodeIfPresent(Double.self, forKey: .endedAt)
        isActive = (try? c.decode(Bool.self, forKey: .isActive)) ?? false
        archived = (try? c.decode(Bool.self, forKey: .archived)) ?? false
    }

    public init(id: String, title: String?, model: String? = nil, messageCount: Int = 0,
                preview: String? = nil, lastActive: Double? = nil, isActive: Bool = false) {
        self.id = id; self.title = title; self.model = model; self.source = nil
        self.messageCount = messageCount; self.preview = preview
        self.startedAt = nil; self.lastActive = lastActive; self.endedAt = nil
        self.isActive = isActive; self.archived = false
    }

    public var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        if let p = preview, !p.isEmpty { return p }
        return "Untitled session"
    }
}

public enum MessageRole: String, Sendable, Codable {
    case user, assistant, system, tool
    case unknown
    public init(raw: String?) {
        self = MessageRole(rawValue: raw ?? "") ?? .unknown
    }
}

/// One stored message, from `GET /api/sessions/{id}/messages` (`db.get_messages`).
public struct ChatMessage: Decodable, Identifiable, Sendable, Equatable {
    public let id: Int
    public let role: MessageRole
    public let content: String?
    public let toolName: String?
    public let timestamp: Double?
    public let tokenCount: Int?
    public let finishReason: String?
    public let reasoning: String?

    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
        case toolName = "tool_name"
        case tokenCount = "token_count"
        case finishReason = "finish_reason"
        case reasoning = "reasoning_content"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id may be Int or String depending on serializer; tolerate both.
        if let i = try? c.decode(Int.self, forKey: .id) { id = i }
        else if let s = try? c.decode(String.self, forKey: .id), let i = Int(s) { id = i }
        else { id = .random(in: Int.min...Int.max) }
        role = MessageRole(raw: try? c.decode(String.self, forKey: .role))
        content = try c.decodeIfPresent(String.self, forKey: .content)
        toolName = try c.decodeIfPresent(String.self, forKey: .toolName)
        timestamp = try c.decodeIfPresent(Double.self, forKey: .timestamp)
        tokenCount = try c.decodeIfPresent(Int.self, forKey: .tokenCount)
        finishReason = try c.decodeIfPresent(String.self, forKey: .finishReason)
        reasoning = try c.decodeIfPresent(String.self, forKey: .reasoning)
    }

    public init(id: Int, role: MessageRole, content: String?, toolName: String? = nil,
                timestamp: Double? = nil, tokenCount: Int? = nil) {
        self.id = id; self.role = role; self.content = content; self.toolName = toolName
        self.timestamp = timestamp; self.tokenCount = tokenCount
        self.finishReason = nil; self.reasoning = nil
    }
}

struct SessionsResponse: Decodable {
    let sessions: [ChatSession]
    let total: Int?
}

struct MessagesResponse: Decodable {
    let sessionId: String
    let messages: [ChatMessage]
    enum CodingKeys: String, CodingKey { case sessionId = "session_id", messages }
}
