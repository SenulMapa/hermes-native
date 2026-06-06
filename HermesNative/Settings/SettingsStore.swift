import SwiftUI
import HermesAPI

/// Loads model catalog + usage stats for Settings.
@MainActor
@Observable
final class SettingsStore {
    private let credential: HermesCredential
    var models: [ModelOption] = []
    var currentModel: String?
    var usage: [String: Double] = [:]
    var loading = false
    var error: String?

    init(credential: HermesCredential) { self.credential = credential }

    func load() async {
        loading = true; error = nil
        let client = HermesAPIClient(credential: credential)
        async let models = try? client.modelOptions()
        async let current = try? client.currentModel()
        async let usage = try? client.usageStats()
        self.models = (await models) ?? []
        self.currentModel = await current
        self.usage = (await usage) ?? [:]
        loading = false
    }

    func setModel(_ id: String) async {
        let client = HermesAPIClient(credential: credential)
        do { try await client.setModel(id); currentModel = id }
        catch let e as HermesError { error = e.userMessage }
        catch { error = error.localizedDescription }
    }
}
