import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import HermesAPI
import HermesGlass

/// A single conversation: scrollable transcript + live streaming + composer.
struct ChatView: View {
    let session: ChatSession
    let credential: HermesCredential
    @Environment(DraftStore.self) private var drafts
    @Environment(AppearanceStore.self) private var appearance
    @Environment(\.scenePhase) private var scenePhase
    @State private var convo: ConversationModel?
    @FocusState private var composerFocused: Bool

    // Attachment pickers.
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var showCamera = false
    @State private var showFiles = false

    var body: some View {
        ZStack {
            ChatWallpaperView(wallpaper: appearance.chatWallpaper)
            VStack(spacing: 0) {
                if let convo {
                    transcript(convo)
                    if let approval = convo.pendingApproval {
                        approvalBar(convo, approval: approval)
                    }
                    composer(convo)
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: branchBinding) { target in
            ChatView(session: target, credential: credential)
        }
        .task {
            if convo == nil {
                let model = ConversationModel(session: session, credential: credential, drafts: drafts)
                convo = model
                await model.load()
                model.connect()
            }
        }
        .onChange(of: convo?.editing) { _, editing in
            if editing != nil { composerFocused = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { convo?.persistDraft() }
        }
        .onDisappear { convo?.persistDraft(); convo?.disconnect() }
    }

    /// Bridges `convo?.branchTarget` to `navigationDestination(item:)`.
    private var branchBinding: Binding<ChatSession?> {
        Binding(get: { convo?.branchTarget }, set: { convo?.branchTarget = $0 })
    }

    private func transcript(_ convo: ConversationModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    if let err = convo.loadError {
                        StatusPill(.bad(err)).frame(maxWidth: .infinity)
                    }
                    ForEach(convo.messages) { message in
                        MessageView(message: message, convo: convo)
                    }

                    if convo.isStreaming || !convo.streamingText.isEmpty {
                        streamingBubble(convo).id("streaming")
                    }
                    if let note = convo.note {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(Tokens.Space.lg)
            }
            .onChange(of: convo.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: convo.streamingText) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func streamingBubble(_ convo: ConversationModel) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.sm) {
                ProgressView().controlSize(.small)
                if !convo.activeTools.isEmpty {
                    Text(convo.activeTools.joined(separator: ", "))
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                } else {
                    Text("Valerie is thinking…").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !convo.streamingThinking.isEmpty {
                Text(convo.streamingThinking)
                    .font(.caption.italic()).foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if !convo.streamingText.isEmpty {
                MarkdownMessage(convo.streamingText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func approvalBar(_ convo: ConversationModel, approval: ConversationModel.PendingApproval) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Label("Approval required", systemImage: "lock.shield")
                .font(.caption.weight(.semibold))
            Text(approval.summary).font(.subheadline)
            HStack(spacing: Tokens.Space.md) {
                Button(role: .destructive) { convo.respond(approved: false) } label: {
                    Text("Deny").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                Button { convo.respond(approved: true) } label: {
                    Text("Approve").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(Tokens.Space.md)
        .glassEffect(.regular.tint(.orange.opacity(0.2)), in: .rect(cornerRadius: Tokens.Radius.card))
        .padding(.horizontal, Tokens.Space.md)
    }

    private func composer(_ convo: ConversationModel) -> some View {
        @Bindable var convo = convo
        return VStack(spacing: Tokens.Space.sm) {
            if convo.editing != nil {
                contextBar(icon: "pencil", text: "Editing message") { convo.cancelEdit() }
            } else if let reply = convo.replyingTo {
                contextBar(icon: "arrowshape.turn.up.left",
                           text: "Replying to: \(reply.content ?? "")") { convo.replyingTo = nil }
            }

            if !convo.pendingAttachments.isEmpty {
                attachmentChips(convo)
            }

            HStack(spacing: Tokens.Space.sm) {
                attachMenu(convo)
                MicButton(convo: convo)

                TextField("Message Hermes…", text: $convo.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, Tokens.Space.sm)
                    .glassEffect(.regular, in: .capsule)

                if convo.isStreaming {
                    Button { convo.interrupt() } label: {
                        Image(systemName: "stop.circle.fill").font(.title2)
                    }
                    .tint(.red)
                    .accessibilityLabel("Stop generating")
                } else {
                    Button { convo.send() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                    .disabled(!convo.canSend)
                    .accessibilityLabel("Send message")
                }
            }
        }
        .padding(Tokens.Space.md)
        .background(.bar)
        .photosPicker(isPresented: $showPhotos, selection: $photoItems,
                      maxSelectionCount: 5, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPhotos(items, into: convo); photoItems = [] }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in addCameraImage(image, to: convo) }
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            handleFileImport(result, into: convo)
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { convo.actionError != nil },
                                    set: { if !$0 { convo.actionError = nil } })) {
            Button("OK", role: .cancel) { convo.actionError = nil }
        } message: {
            Text(convo.actionError ?? "")
        }
    }

    private func attachMenu(_ convo: ConversationModel) -> some View {
        Menu {
            Button { showPhotos = true } label: { Label("Photo Library", systemImage: "photo") }
            Button { showCamera = true } label: { Label("Camera", systemImage: "camera") }
            Button { showFiles = true } label: { Label("File", systemImage: "doc") }
            if UIPasteboard.general.hasImages {
                Button { pasteImage(into: convo) } label: { Label("Paste Image", systemImage: "doc.on.clipboard") }
            }
        } label: {
            Image(systemName: "plus.circle.fill").font(.title2)
        }
        .accessibilityLabel("Add attachment")
    }

    // MARK: - Attachment intake

    private func loadPhotos(_ items: [PhotosPickerItem], into convo: ConversationModel) async {
        for (i, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                convo.pendingAttachments.append(
                    PendingAttachment(data: data, filename: "photo-\(Date().timeIntervalSince1970)-\(i).jpg",
                                      mime: "image/jpeg"))
            }
        }
    }

    private func addCameraImage(_ image: UIImage, to convo: ConversationModel) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        convo.pendingAttachments.append(
            PendingAttachment(data: data, filename: "camera-\(Date().timeIntervalSince1970).jpg",
                              mime: "image/jpeg"))
    }

    private func pasteImage(into convo: ConversationModel) {
        guard let image = UIPasteboard.general.image,
              let data = image.jpegData(compressionQuality: 0.85) else { return }
        convo.pendingAttachments.append(
            PendingAttachment(data: data, filename: "pasted-\(Date().timeIntervalSince1970).jpg",
                              mime: "image/jpeg"))
    }

    private func handleFileImport(_ result: Result<[URL], Error>, into convo: ConversationModel) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            convo.pendingAttachments.append(
                PendingAttachment(data: data, filename: url.lastPathComponent, mime: mime))
        }
    }

    /// A dismissible banner above the composer (reply target / edit mode).
    private func contextBar(icon: String, text: String, cancel: @escaping () -> Void) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(text).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 0)
            Button { cancel() } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless).tint(.secondary)
                .accessibilityLabel("Cancel")
        }
        .padding(.horizontal, Tokens.Space.sm)
    }

    private func attachmentChips(_ convo: ConversationModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(convo.pendingAttachments) { att in
                    AttachmentChip(att: att) {
                        convo.pendingAttachments.removeAll { $0.id == att.id }
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.xs)
        }
    }
}
