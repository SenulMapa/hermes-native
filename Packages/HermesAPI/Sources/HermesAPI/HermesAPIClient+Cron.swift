import Foundation

public extension HermesAPIClient {
    /// `GET /api/cron/jobs` — all scheduled jobs (lenient shape parsing).
    func cronJobs() async throws -> [CronJob] {
        let data = try await send("GET", "/api/cron/jobs", authenticated: true)
        let obj = try? JSONSerialization.jsonObject(with: data)
        return Self.extractObjects(obj).compactMap(CronJob.init(json:))
    }

    /// `POST /api/cron/jobs/{id}/pause`.
    func pauseCron(_ id: String) async throws {
        _ = try await send("POST", "/api/cron/jobs/\(id)/pause", authenticated: true)
    }

    /// `POST /api/cron/jobs/{id}/resume`.
    func resumeCron(_ id: String) async throws {
        _ = try await send("POST", "/api/cron/jobs/\(id)/resume", authenticated: true)
    }

    /// `POST /api/cron/jobs/{id}/trigger` — run now.
    func triggerCron(_ id: String) async throws {
        _ = try await send("POST", "/api/cron/jobs/\(id)/trigger", authenticated: true)
    }

    /// `POST /api/cron/jobs` — create a job.
    func createCron(name: String, schedule: String, prompt: String, model: String?) async throws {
        struct Body: Encodable {
            let name: String
            let schedule: String
            let prompt: String
            let model: String?
        }
        let _: EmptyResponse = try await sendJSON(
            "POST", "/api/cron/jobs",
            body: Body(name: name, schedule: schedule, prompt: prompt, model: model)
        )
    }
}
