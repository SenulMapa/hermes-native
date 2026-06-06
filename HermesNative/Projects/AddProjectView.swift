import SwiftUI
import HermesTerminal

/// Create a project, optionally linking a saved SSH host.
struct AddProjectView: View {
    let store: ProjectStore
    let hostStore: HostStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var path = ""
    @State private var gitRemote = ""
    @State private var sshHostID: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                    TextField("Path (e.g. ~/valerie-projects/app)", text: $path)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Git remote (optional)", text: $gitRemote)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("SSH Host (optional)") {
                    Picker("Host", selection: $sshHostID) {
                        Text("None").tag(String?.none)
                        ForEach(hostStore.hosts) { host in
                            Text(host.name).tag(String?.some(host.id))
                        }
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        store.add(Project(
            name: name.trimmingCharacters(in: .whitespaces),
            path: path.trimmingCharacters(in: .whitespaces),
            sshHostID: sshHostID,
            gitRemote: gitRemote.isEmpty ? nil : gitRemote
        ))
        dismiss()
    }
}
