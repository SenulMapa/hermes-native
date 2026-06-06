import SwiftUI

/// Persists per-session composer text so an unsent draft survives leaving a
/// conversation or quitting the app. Mirrors `ProjectStore`: `@Observable` over a
/// single JSON blob in UserDefaults (the Hermes API has no draft endpoint —
/// drafts are a purely local convenience).
@MainActor
@Observable
final class DraftStore {
    private let key = "hermes.drafts"
    private let defaults: UserDefaults
    /// sessionID → draft text.
    private var drafts: [String: String] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        drafts = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(drafts) { defaults.set(data, forKey: key) }
    }

    func draft(for sessionID: String) -> String { drafts[sessionID] ?? "" }

    func set(_ text: String, for sessionID: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { drafts[sessionID] = nil } else { drafts[sessionID] = text }
        persist()
    }

    func clear(for sessionID: String) {
        guard drafts[sessionID] != nil else { return }
        drafts[sessionID] = nil
        persist()
    }
}
