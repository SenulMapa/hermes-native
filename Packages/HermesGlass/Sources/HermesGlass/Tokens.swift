import SwiftUI

/// Design tokens for Hermes Native. Centralizes spacing, radii, and the accent
/// palette so the Liquid Glass surfaces stay consistent and themeable (PRD §15.4).
public enum Tokens {
    /// 4-pt spacing scale.
    public enum Space {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    /// Corner radii for glass surfaces.
    public enum Radius {
        public static let card: CGFloat = 22
        public static let control: CGFloat = 14
        public static let pill: CGFloat = 999
    }

    /// Default accent. Hermes "electric indigo".
    public static let accent = Color(red: 0.42, green: 0.40, blue: 0.96)
}

/// Theme settings carried through the environment (Phase 0 = accent only;
/// density / true-black / font expand in Phase 3 Settings).
public struct HermesTheme: Sendable, Equatable {
    public var accent: Color
    public init(accent: Color = Tokens.accent) {
        self.accent = accent
    }
}

private struct HermesThemeKey: EnvironmentKey {
    static let defaultValue = HermesTheme()
}

public extension EnvironmentValues {
    var hermesTheme: HermesTheme {
        get { self[HermesThemeKey.self] }
        set { self[HermesThemeKey.self] = newValue }
    }
}

public extension View {
    func hermesTheme(_ theme: HermesTheme) -> some View {
        environment(\.hermesTheme, theme)
    }
}
