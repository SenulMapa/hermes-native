import SwiftUI
import HermesAPI
import HermesGlass

/// Scheduled tasks list with pause/resume/run-now.
struct CronView: View {
    @Environment(AppModel.self) private var app
    @State private var store: CronStore?
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if let store {
                    content(store)
                } else {
                    ContentUnavailableView("Not connected", systemImage: "wifi.slash",
                                           description: Text("Configure a server in Settings."))
                }
            }
            .navigationTitle("Cron")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreate = true } label: { Image(systemName: "plus") }
                        .disabled(store == nil)
                }
            }
            .sheet(isPresented: $showCreate) {
                if let store { CreateCronView(store: store) }
            }
        }
        .task {
            guard store == nil, let cred = app.credential else { return }
            let s = CronStore(credential: cred)
            store = s
            await s.load()
        }
    }

    @ViewBuilder
    private func content(_ store: CronStore) -> some View {
        switch store.state {
        case .loading where store.jobs.isEmpty:
            ProgressView("Loading jobs…").frame(maxHeight: .infinity)
        case .failed(let message) where store.jobs.isEmpty:
            ContentUnavailableView {
                Label("Couldn't load", systemImage: "exclamationmark.triangle")
            } description: { Text(message) } actions: {
                Button("Retry") { Task { await store.load() } }.buttonStyle(.glassProminent)
            }
        default:
            if store.jobs.isEmpty {
                ContentUnavailableView("No jobs", systemImage: "clock",
                                       description: Text("Tap ＋ to schedule a task."))
            } else {
                list(store)
            }
        }
    }

    private func list(_ store: CronStore) -> some View {
        List {
            ForEach(store.jobs) { job in
                row(job, store: store)
            }
        }
        .listStyle(.plain)
        .refreshable { await store.load() }
    }

    private func row(_ job: CronJob, store: CronStore) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack {
                Text(job.displayName).font(.headline)
                Spacer()
                Circle().fill(job.enabled ? .green : .secondary).frame(width: 8, height: 8)
            }
            if let schedule = job.schedule {
                Text(schedule).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            if let status = job.lastStatus {
                Text("last: \(status)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Tokens.Space.xs)
        .swipeActions(edge: .leading) {
            Button { Task { await store.trigger(job) } } label: {
                Label("Run", systemImage: "play.fill")
            }.tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button { Task { await store.toggle(job) } } label: {
                Label(job.enabled ? "Pause" : "Resume",
                      systemImage: job.enabled ? "pause.fill" : "play.fill")
            }.tint(job.enabled ? .orange : .green)
        }
    }
}
