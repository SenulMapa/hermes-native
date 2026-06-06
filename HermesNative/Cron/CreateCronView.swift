import SwiftUI

/// Create a scheduled job. Schedule is a cron expression (plain-English parsing
/// is a later refinement, PRD §6.2).
struct CreateCronView: View {
    let store: CronStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var schedule = "0 9 * * *"
    @State private var prompt = ""
    @State private var model = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Job") {
                    TextField("Name", text: $name)
                    TextField("Schedule (cron, e.g. 0 9 * * *)", text: $schedule)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(.body.monospaced())
                }
                Section("Prompt") {
                    TextField("What should run?", text: $prompt, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Model (optional)") {
                    TextField("Default", text: $model)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Text("Common: `0 9 * * *` = 9am daily · `*/30 * * * *` = every 30 min · `0 0 1 * *` = monthly")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isValid || saving)
                }
            }
        }
    }

    private var isValid: Bool {
        !schedule.trimmingCharacters(in: .whitespaces).isEmpty
        && !prompt.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        saving = true
        Task {
            let ok = await store.create(
                name: name.isEmpty ? "Job" : name,
                schedule: schedule.trimmingCharacters(in: .whitespaces),
                prompt: prompt,
                model: model.isEmpty ? nil : model
            )
            saving = false
            if ok { dismiss() }
        }
    }
}
