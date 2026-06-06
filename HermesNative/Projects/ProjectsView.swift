import SwiftUI
import HermesTerminal
import HermesGlass

/// Projects list + detail (PRD §8). Local organizing concept linking a path,
/// an optional SSH host, and tools.
struct ProjectsView: View {
    @State private var store = ProjectStore()
    @State private var hostStore = HostStore()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if store.projects.isEmpty {
                    ContentUnavailableView {
                        Label("No projects", systemImage: "folder")
                    } description: {
                        Text("Group a path, an SSH host, and tools into a project.")
                    } actions: {
                        Button("Add project") { showAdd = true }.buttonStyle(.glassProminent)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddProjectView(store: store, hostStore: hostStore) }
        }
    }

    private var list: some View {
        List {
            ForEach(store.projects) { project in
                NavigationLink {
                    ProjectDetailView(project: project, hostStore: hostStore)
                } label: {
                    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                        Text(project.name).font(.headline)
                        Text(project.path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .padding(.vertical, Tokens.Space.xs)
                }
            }
            .onDelete { idx in idx.map { store.projects[$0] }.forEach(store.remove) }
        }
        .listStyle(.plain)
    }
}

/// Project detail: metadata + quick actions (terminal, editor).
struct ProjectDetailView: View {
    let project: Project
    let hostStore: HostStore

    private var host: SSHHost? {
        guard let id = project.sshHostID else { return nil }
        return hostStore.hosts.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Space.lg) {
                GlassCard {
                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        LabeledContent("Path", value: project.path)
                        if let remote = project.gitRemote, !remote.isEmpty {
                            LabeledContent("Git", value: remote)
                        }
                        if let host { LabeledContent("Host", value: host.subtitle) }
                    }
                }
                NavigationLink {
                    FileEditorView()
                } label: {
                    Label("Open file editor", systemImage: "doc.text").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                if let host {
                    NavigationLink {
                        TerminalScreen(host: host, store: hostStore)
                    } label: {
                        Label("Open terminal", systemImage: "terminal").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(Tokens.Space.lg)
        }
        .navigationTitle(project.name)
    }
}
