import Foundation

/// A messaging bridge platform (Telegram, Signal, etc.), parsed leniently from
/// `/api/messaging/platforms` (PRD §15.6).
public struct MessagingPlatform: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let enabled: Bool
    public let mode: String?

    public init(id: String, name: String, enabled: Bool, mode: String? = nil) {
        self.id = id; self.name = name; self.enabled = enabled; self.mode = mode
    }

    init?(json: [String: Any]) {
        guard let id = (json["id"] ?? json["platform_id"] ?? json["platform"] ?? json["name"]).map({ "\($0)" }) else { return nil }
        self.id = id
        self.name = (json["name"] ?? json["label"] ?? json["platform"]) as? String ?? id
        if let e = json["enabled"] as? Bool { self.enabled = e }
        else if let c = json["connected"] as? Bool { self.enabled = c }
        else { self.enabled = (json["status"] as? String).map { $0.lowercased() == "connected" || $0.lowercased() == "enabled" } ?? false }
        self.mode = (json["mode"] ?? json["direction"]) as? String
    }
}
