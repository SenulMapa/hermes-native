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

    /// `POST /api/sessions/{id}/attachments` (multipart) — upload one file/image.
    /// Returns the server-side `path` (handed to `prompt.submit`) plus the public
    /// `Attachment` used for inline rendering.
    func uploadAttachment(sessionID: String, data: Data, filename: String, mime: String) async throws -> UploadedAttachment {
        try await sendMultipart(
            "/api/sessions/\(sessionID)/attachments",
            fileField: "file", fileData: data, filename: filename, mime: mime
        )
    }

    /// `GET /api/sessions/{id}/attachments/{name}` — raw bytes for an attachment
    /// (the route is authenticated, so this can't go through a plain `AsyncImage`).
    func attachmentData(sessionID: String, name: String) async throws -> Data {
        try await send("GET", "/api/sessions/\(sessionID)/attachments/\(name)", authenticated: true)
    }

    /// `POST /api/sessions/{id}/messages/{mid}/feedback` — thumbs up/down (+ optional note).
    func setFeedback(sessionID: String, messageID: Int, score: Int, comment: String? = nil) async throws {
        struct Body: Encodable { var score: Int; var comment: String? }
        let _: EmptyResponse = try await sendJSON(
            "POST", "/api/sessions/\(sessionID)/messages/\(messageID)/feedback",
            body: Body(score: score, comment: comment)
        )
    }
}

/// Response of the attachment upload endpoint. `path` is the server filesystem
/// path used to feed the model; `name`/`url`/`mime` describe how to render it.
public struct UploadedAttachment: Decodable, Sendable, Equatable {
    public let name: String
    public let path: String
    public let url: String?
    public let mime: String?

    enum CodingKeys: String, CodingKey { case name, path, url, mime }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        path = (try? c.decode(String.self, forKey: .path)) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url)
        mime = try c.decodeIfPresent(String.self, forKey: .mime)
    }

    /// The public-facing attachment shape for the transcript.
    public var attachment: Attachment { Attachment(name: name, url: url, mime: mime) }
}

struct EmptyResponse: Decodable {
    init() {}
    init(from decoder: Decoder) throws {}  // tolerate any/empty JSON body
}
