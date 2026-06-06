import Foundation

/// A scheduled job, parsed leniently from `/api/cron/jobs`.
public struct CronJob: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String?
    public let schedule: String?
    public let enabled: Bool
    public let nextRun: Double?
    public let lastRun: Double?
    public let lastStatus: String?
    public let prompt: String?

    public init(id: String, name: String?, schedule: String?, enabled: Bool,
                nextRun: Double? = nil, lastRun: Double? = nil,
                lastStatus: String? = nil, prompt: String? = nil) {
        self.id = id; self.name = name; self.schedule = schedule; self.enabled = enabled
        self.nextRun = nextRun; self.lastRun = lastRun; self.lastStatus = lastStatus; self.prompt = prompt
    }

    init?(json: [String: Any]) {
        guard let id = (json["id"] ?? json["job_id"] ?? json["name"]).map({ "\($0)" }) else { return nil }
        self.id = id
        self.name = (json["name"] ?? json["title"]) as? String
        self.schedule = (json["schedule"] ?? json["cron"] ?? json["cron_expression"] ?? json["expression"]) as? String
        if let e = json["enabled"] as? Bool { self.enabled = e }
        else if let p = json["paused"] as? Bool { self.enabled = !p }
        else { self.enabled = (json["status"] as? String).map { $0.lowercased() != "paused" } ?? true }
        self.nextRun = Self.epoch(json["next_run"] ?? json["next"])
        self.lastRun = Self.epoch(json["last_run"] ?? json["last"])
        self.lastStatus = (json["last_status"] ?? json["status"]) as? String
        self.prompt = (json["prompt"] ?? json["command"] ?? json["task"]) as? String
    }

    private static func epoch(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        return nil
    }

    public var displayName: String { name ?? id }
}
