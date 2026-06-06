import Foundation

/// A selectable model, parsed leniently from `/api/model/options` (whose exact
/// shape varies — array, or wrapped under options/models/data).
public struct ModelOption: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String?
    public let provider: String?
    public let contextWindow: Int?

    public init(id: String, name: String? = nil, provider: String? = nil, contextWindow: Int? = nil) {
        self.id = id; self.name = name; self.provider = provider; self.contextWindow = contextWindow
    }

    init?(json: [String: Any]) {
        guard let id = (json["id"] ?? json["model"] ?? json["name"] ?? json["slug"]) as? String else { return nil }
        self.id = id
        self.name = (json["name"] ?? json["label"] ?? json["display_name"]) as? String
        self.provider = (json["provider"] ?? json["owned_by"] ?? json["vendor"]) as? String
        self.contextWindow = (json["context_window"] ?? json["context"] ?? json["context_length"]) as? Int
    }

    public var displayName: String { name ?? id }
}
