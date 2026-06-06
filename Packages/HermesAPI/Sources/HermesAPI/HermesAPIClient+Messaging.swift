import Foundation

public extension HermesAPIClient {
    /// `GET /api/messaging/platforms` — bridged messaging platforms.
    func messagingPlatforms() async throws -> [MessagingPlatform] {
        let data = try await send("GET", "/api/messaging/platforms", authenticated: true)
        let obj = try? JSONSerialization.jsonObject(with: data)
        return Self.extractObjects(obj).compactMap(MessagingPlatform.init(json:))
    }

    /// `PUT /api/messaging/platforms/{id}` — enable/disable a platform.
    func setMessagingPlatform(_ id: String, enabled: Bool) async throws {
        struct Body: Encodable { let enabled: Bool }
        let _: EmptyResponse = try await sendJSON("PUT", "/api/messaging/platforms/\(id)", body: Body(enabled: enabled))
    }

    /// `POST /api/messaging/platforms/{id}/test` — send a test message.
    func testMessagingPlatform(_ id: String) async throws {
        _ = try await send("POST", "/api/messaging/platforms/\(id)/test", authenticated: true)
    }

    /// Best-effort memory fetch. The endpoint may not exist on every server;
    /// returns nil rather than throwing on 404 so the UI can degrade.
    func memoryText() async throws -> String? {
        for path in ["/api/memory", "/api/curator"] {
            if let data = try? await send("GET", path, authenticated: true),
               let obj = try? JSONSerialization.jsonObject(with: data) {
                if let s = obj as? String { return s }
                if let d = obj as? [String: Any] {
                    if let m = (d["memory"] ?? d["content"] ?? d["text"]) as? String { return m }
                }
            }
        }
        return nil
    }
}
