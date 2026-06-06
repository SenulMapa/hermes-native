import SwiftUI

/// A project groups a working directory, an optional SSH host, and a scoped
/// chat. Persisted locally (the Hermes API has no project endpoints; projects
/// are a client-side organizing concept — PRD §8).
struct Project: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var path: String
    var sshHostID: String?      // links to a HermesTerminal SSHHost, if any
    var gitRemote: String?
}

@MainActor
@Observable
final class ProjectStore {
    private let key = "hermes.projects"
    private let defaults: UserDefaults
    private(set) var projects: [Project] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Project].self, from: data) else { return }
        projects = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(projects) { defaults.set(data, forKey: key) }
    }

    func add(_ project: Project) { projects.append(project); persist() }
    func remove(_ project: Project) { projects.removeAll { $0.id == project.id }; persist() }
}
