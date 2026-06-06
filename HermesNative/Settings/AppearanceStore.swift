import SwiftUI
import HermesGlass

/// Local appearance preferences (PRD §15.4): accent + color scheme, persisted
/// to UserDefaults and applied app-wide.
@MainActor
@Observable
final class AppearanceStore {
    enum Scheme: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    struct Accent: Identifiable, Hashable {
        let id: String
        let color: Color
    }

    static let accents: [Accent] = [
        .init(id: "Indigo", color: Color(red: 0.42, green: 0.40, blue: 0.96)),
        .init(id: "Mint",   color: Color(red: 0.16, green: 0.80, blue: 0.62)),
        .init(id: "Pink",   color: Color(red: 0.96, green: 0.36, blue: 0.62)),
        .init(id: "Amber",  color: Color(red: 0.98, green: 0.66, blue: 0.18)),
        .init(id: "Sky",    color: Color(red: 0.28, green: 0.66, blue: 0.98)),
    ]

    // MARK: - Chat wallpaper (Telegram-style)

    struct WallpaperGradient: Identifiable, Hashable {
        let id: String
        let colors: [Color]
    }

    static let wallpaperGradients: [WallpaperGradient] = [
        .init(id: "Aurora", colors: [Color(red: 0.42, green: 0.40, blue: 0.96),
                                     Color(red: 0.16, green: 0.80, blue: 0.62)]),
        .init(id: "Dusk",   colors: [Color(red: 0.36, green: 0.20, blue: 0.52),
                                     Color(red: 0.96, green: 0.36, blue: 0.62)]),
        .init(id: "Ember",  colors: [Color(red: 0.98, green: 0.66, blue: 0.18),
                                     Color(red: 0.92, green: 0.30, blue: 0.36)]),
        .init(id: "Ocean",  colors: [Color(red: 0.10, green: 0.30, blue: 0.55),
                                     Color(red: 0.28, green: 0.66, blue: 0.98)]),
        .init(id: "Slate",  colors: [Color(red: 0.16, green: 0.18, blue: 0.22),
                                     Color(red: 0.30, green: 0.33, blue: 0.40)]),
    ]

    /// The chat background choice. Persisted as a tagged string ("none",
    /// "gradient:<id>", "photo:<filename>") so it round-trips through UserDefaults.
    enum Wallpaper: Equatable {
        case none
        case gradient(String)
        case photo(String)

        var raw: String {
            switch self {
            case .none: return "none"
            case .gradient(let id): return "gradient:\(id)"
            case .photo(let name): return "photo:\(name)"
            }
        }

        init(raw: String?) {
            switch raw {
            case .some(let s) where s.hasPrefix("gradient:"): self = .gradient(String(s.dropFirst(9)))
            case .some(let s) where s.hasPrefix("photo:"):    self = .photo(String(s.dropFirst(6)))
            default: self = .none
            }
        }
    }

    var accentName: String { didSet { defaults.set(accentName, forKey: "accent") } }
    var scheme: Scheme { didSet { defaults.set(scheme.rawValue, forKey: "scheme") } }
    var chatWallpaper: Wallpaper { didSet { defaults.set(chatWallpaper.raw, forKey: "chatWallpaper") } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.accentName = defaults.string(forKey: "accent") ?? "Indigo"
        self.scheme = Scheme(rawValue: defaults.string(forKey: "scheme") ?? "system") ?? .system
        self.chatWallpaper = Wallpaper(raw: defaults.string(forKey: "chatWallpaper"))
    }

    var accentColor: Color {
        Self.accents.first { $0.id == accentName }?.color ?? Tokens.accent
    }

    var theme: HermesTheme { HermesTheme(accent: accentColor) }

    func gradient(id: String) -> WallpaperGradient? {
        Self.wallpaperGradients.first { $0.id == id }
    }

    /// On-disk location of the custom wallpaper photo (in Documents).
    static func wallpaperPhotoURL(_ filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    /// Save picked photo bytes to Documents and select it as the wallpaper.
    func setPhotoWallpaper(_ data: Data) {
        let filename = "chat-wallpaper.jpg"
        try? data.write(to: Self.wallpaperPhotoURL(filename))
        chatWallpaper = .photo(filename)
    }
}
