import Foundation

public extension HermesAPIClient {
    /// `GET /api/model/options` — available models (lenient shape parsing).
    func modelOptions() async throws -> [ModelOption] {
        let data = try await send("GET", "/api/model/options", authenticated: true)
        let obj = try? JSONSerialization.jsonObject(with: data)
        return Self.extractObjects(obj).compactMap(ModelOption.init(json:))
    }

    /// `GET /api/model/info` — the current default model id, if discoverable.
    func currentModel() async throws -> String? {
        let data = try await send("GET", "/api/model/info", authenticated: true)
        let obj = try? JSONSerialization.jsonObject(with: data)
        if let s = obj as? String { return s }
        if let d = obj as? [String: Any] {
            return (d["model"] ?? d["id"] ?? d["name"] ?? d["current"]) as? String
        }
        return nil
    }

    /// `POST /api/model/set` — set the default model.
    func setModel(_ id: String) async throws {
        struct Body: Encodable { let model: String }
        let _: EmptyResponse = try await sendJSON("POST", "/api/model/set", body: Body(model: id))
    }

    /// `GET /api/sessions/stats` — top-level numeric usage/cost fields.
    func usageStats() async throws -> [String: Double] {
        let data = try await send("GET", "/api/sessions/stats", authenticated: true)
        guard let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: Double] = [:]
        for (key, value) in d {
            if let n = value as? NSNumber, !(value is Bool) { out[key] = n.doubleValue }
        }
        return out
    }

    /// Pull an array of JSON objects out of several common envelope shapes.
    static func extractObjects(_ obj: Any?) -> [[String: Any]] {
        if let a = obj as? [[String: Any]] { return a }
        if let a = obj as? [String] { return a.map { ["id": $0] } }
        if let d = obj as? [String: Any] {
            for key in ["options", "models", "data", "items", "results"] {
                if let a = d[key] as? [[String: Any]] { return a }
                if let a = d[key] as? [String] { return a.map { ["id": $0] } }
            }
        }
        return []
    }
}
