import SwiftUI
import HermesGlass

/// A minimal syntax-neutral text/code editor backed by a Files-app document
/// (PRD §9.2 baseline). Remote SFTP editing is a later refinement.
struct FileEditorView: View {
    @State private var text: String = ""
    @State private var url: URL?
    @State private var importing = false
    @State private var status: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { importing = true } label: { Label("Open", systemImage: "folder") }
                    .buttonStyle(.glass)
                Spacer()
                if let url { Text(url.lastPathComponent).font(.caption.monospaced()).lineLimit(1) }
                Spacer()
                Button { save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    .buttonStyle(.glassProminent)
                    .disabled(url == nil)
            }
            .padding(Tokens.Space.md)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(Tokens.Space.sm)

            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary).padding(.bottom, Tokens.Space.sm)
            }
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.text, .sourceCode, .plainText, .json, .yaml]) { result in
            switch result {
            case .success(let picked): open(picked)
            case .failure(let error): status = error.localizedDescription
            }
        }
    }

    private func open(_ picked: URL) {
        guard picked.startAccessingSecurityScopedResource() else {
            status = "Couldn't access file."; return
        }
        defer { picked.stopAccessingSecurityScopedResource() }
        do {
            text = try String(contentsOf: picked, encoding: .utf8)
            url = picked
            status = "Opened."
        } catch {
            status = error.localizedDescription
        }
    }

    private func save() {
        guard let url else { return }
        guard url.startAccessingSecurityScopedResource() else {
            status = "Couldn't access file for writing."; return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            try text.data(using: .utf8)?.write(to: url)
            status = "Saved."
        } catch {
            status = error.localizedDescription
        }
    }
}
