import SwiftUI
import UIKit

/// The background layer behind a chat transcript (Telegram-style wallpaper).
/// Renders nothing for `.none` so the system background shows through.
struct ChatWallpaperView: View {
    let wallpaper: AppearanceStore.Wallpaper

    var body: some View {
        switch wallpaper {
        case .none:
            Color.clear
        case .gradient(let id):
            if let g = AppearanceStore.wallpaperGradients.first(where: { $0.id == id }) {
                LinearGradient(colors: g.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.5)
                    .ignoresSafeArea()
            } else {
                Color.clear
            }
        case .photo(let name):
            if let ui = UIImage(contentsOfFile: AppearanceStore.wallpaperPhotoURL(name).path) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(.ultraThinMaterial.opacity(0.25))
            } else {
                Color.clear
            }
        }
    }

    /// Whether a scrim should sit between the wallpaper and the transcript to keep
    /// bubbles legible (photos only — gradients are already subtle).
    var needsScrim: Bool {
        if case .photo = wallpaper { return true }
        return false
    }
}
