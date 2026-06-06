import SwiftUI
import HermesAPI

/// Loads and mutates scheduled cron jobs.
@MainActor
@Observable
final class CronStore {
    enum State: Equatable { case idle, loading, loaded, failed(String) }

    private let credential: HermesCredential
    var jobs: [CronJob] = []
    var state: State = .idle

    init(credential: HermesCredential) { self.credential = credential }

    private var client: HermesAPIClient { HermesAPIClient(credential: credential) }

    func load() async {
        if jobs.isEmpty { state = .loading }
        do { jobs = try await client.cronJobs(); state = .loaded }
        catch let e as HermesError { state = .failed(e.userMessage) }
        catch { state = .failed(error.localizedDescription) }
    }

    func toggle(_ job: CronJob) async {
        do {
            if job.enabled { try await client.pauseCron(job.id) }
            else { try await client.resumeCron(job.id) }
            await load()
        } catch { /* surfaced on next load */ }
    }

    func trigger(_ job: CronJob) async {
        try? await client.triggerCron(job.id)
    }

    func create(name: String, schedule: String, prompt: String, model: String?) async -> Bool {
        do {
            try await client.createCron(name: name, schedule: schedule, prompt: prompt, model: model)
            await load()
            return true
        } catch { return false }
    }
}
