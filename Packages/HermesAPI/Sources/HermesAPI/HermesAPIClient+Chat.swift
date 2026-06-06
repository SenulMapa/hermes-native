import Foundation

public extension HermesAPIClient {
    /// `GET /api/sessions` — list conversations (most-recent first by default).
    func sessions(limit: Int = 40, offset: Int = 0, order: String = "recent") async throws -> [ChatSession] {
        let resp: SessionsResponse = try await get("/api/sessions", query: [
            .init(name: "limit", value: String(limit)),
            .init(name: "offset", value: String(offset)),
            .init(name: "order", value: order),
        ])
        return resp.sessions
    }

    /// `GET /api/sessions/{id}/messages` — full message history for a session.
    func messages(sessionID: String) async throws -> [ChatMessage] {
        let resp: MessagesResponse = try await get("/api/sessions/\(sessionID)/messages")
        return resp.messages
    }

    /// `GET /api/sessions/search?q=` — full-text search across sessions.
    func searchSessions(_ query: String, limit: Int = 20) async throws -> [ChatSession] {
        let resp: SessionsResponse = try await get("/api/sessions/search", query: [
            .init(name: "q", value: query),
            .init(name: "limit", value: String(limit)),
        ])
        return resp.sessions
    }

    /// `PATCH /api/sessions/{id}` — rename and/or archive.
    func updateSession(_ id: String, title: String? = nil, archived: Bool? = nil) async throws {
        struct Body: Encodable { var title: String?; var archived: Bool? }
        let _: EmptyResponse = try await sendJSON("PATCH", "/api/sessions/\(id)", body: Body(title: title, archived: archived))
    }

    /// `DELETE /api/sessions/{id}`.
    func deleteSession(_ id: String) async throws {
        _ = try await send("DELETE", "/api/sessions/\(id)", authenticated: true)
    }
}

struct EmptyResponse: Decodable {
    init() {}
    init(from decoder: Decoder) throws {}  // tolerate any/empty JSON body
}
