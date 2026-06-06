import SwiftUI
import QuickLook
import UIKit
import HermesAPI
import HermesGlass

/// Thin wrapper over `UIImagePickerController` for capturing a photo with the
/// camera (SwiftUI has no native camera capture in iOS 17).
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// A removable thumbnail for a not-yet-sent attachment, shown above the composer.
struct AttachmentChip: View {
    let att: PendingAttachment
    let remove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if att.isImage, let ui = UIImage(data: att.data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "doc.fill").font(.title3)
                        Text(att.filename).font(.caption2).lineLimit(1)
                    }
                    .padding(Tokens.Space.xs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.control))

            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .offset(x: 6, y: -6)
            .accessibilityLabel("Remove attachment")
        }
        .frame(width: 60, height: 60)
    }
}

/// Loads an attachment image through the authenticated REST client (a plain
/// `AsyncImage` can't, since the route requires the session token).
struct AuthImage: View {
    let convo: ConversationModel
    let attachment: Attachment
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                ZStack { Color.secondary.opacity(0.1); ProgressView() }
            }
        }
        .task(id: attachment.name) { image = await convo.attachmentImage(attachment) }
    }
}

/// Renders the attachments attached to a sent message: images as tappable
/// thumbnails (→ full-screen zoom), other files as chips (→ Quick Look).
struct MessageAttachments: View {
    let convo: ConversationModel
    let attachments: [Attachment]
    @State private var zoomed: Attachment?
    @State private var previewURL: URL?

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(attachments) { att in
                if att.isImage {
                    Button { zoomed = att } label: {
                        AuthImage(convo: convo, attachment: att)
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.control))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { Task { previewURL = await stage(att) } } label: {
                        HStack(spacing: Tokens.Space.sm) {
                            Image(systemName: "doc.fill")
                            Text(att.name).font(.caption).lineLimit(1)
                        }
                        .padding(Tokens.Space.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: Tokens.Radius.control))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fullScreenCover(item: $zoomed) { att in
            ImageZoomView(convo: convo, attachment: att)
        }
        .quickLookPreview($previewURL)
    }

    /// Download a non-image attachment to a temp file so Quick Look can open it.
    private func stage(_ att: Attachment) async -> URL? {
        guard let data = await convo.attachmentData(att) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(att.name)
        try? data.write(to: url)
        return url
    }
}

/// Full-screen, pinch-to-zoom viewer for an image attachment.
struct ImageZoomView: View {
    let convo: ConversationModel
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AuthImage(convo: convo, attachment: attachment, contentMode: .fit)
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in scale = max(1, lastScale * value) }
                        .onEnded { _ in lastScale = scale }
                )
                .onTapGesture(count: 2) {
                    withAnimation { scale = scale > 1 ? 1 : 2.5; lastScale = scale }
                }
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.3))
            }
            .padding()
            .accessibilityLabel("Close")
        }
    }
}
