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

    var accentName: String { didSet { defaults.set(accentName, forKey: "accent") } }
    var scheme: Scheme { didSet { defaults.set(scheme.rawValue, forKey: "scheme") } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.accentName = defaults.string(forKey: "accent") ?? "Indigo"
        self.scheme = Scheme(rawValue: defaults.string(forKey: "scheme") ?? "system") ?? .system
    }

    var accentColor: Color {
        Self.accents.first { $0.id == accentName }?.color ?? Tokens.accent
    }

    var theme: HermesTheme { HermesTheme(accent: accentColor) }
}
