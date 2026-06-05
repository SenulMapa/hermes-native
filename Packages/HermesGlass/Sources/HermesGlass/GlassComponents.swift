import SwiftUI

/// A rounded Liquid Glass container. Wraps iOS 26's `.glassEffect(_:in:)` so
/// callers never touch the raw modifier — they just get a consistent card.
public struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    public init(
        cornerRadius: CGFloat = Tokens.Radius.card,
        padding: CGFloat = Tokens.Space.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

/// A capsule status indicator (e.g. "Connected"). Tints the glass by state.
public struct StatusPill: View {
    public enum State: Sendable, Equatable {
        case ok(String)
        case busy(String)
        case bad(String)

        var label: String {
            switch self {
            case .ok(let s), .busy(let s), .bad(let s): return s
            }
        }
        var color: Color {
            switch self {
            case .ok: return .green
            case .busy: return .yellow
            case .bad: return .red
            }
        }
        var systemImage: String {
            switch self {
            case .ok: return "checkmark.circle.fill"
            case .busy: return "clock.fill"
            case .bad: return "exclamationmark.triangle.fill"
            }
        }
    }

    private let state: State
    public init(_ state: State) { self.state = state }

    public var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: state.systemImage)
            Text(state.label)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(state.color)
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.sm)
        .glassEffect(.regular.tint(state.color.opacity(0.18)), in: .capsule)
    }
}

/// A prominent Liquid Glass call-to-action button.
public struct GlassActionButton: View {
    private let title: String
    private let systemImage: String?
    private let action: () -> Void
    @Environment(\.hermesTheme) private var theme

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.sm)
        }
        .buttonStyle(.glassProminent)
        .tint(theme.accent)
    }
}
