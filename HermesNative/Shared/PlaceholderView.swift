import SwiftUI
import HermesGlass

/// Stand-in for a not-yet-built destination. Removed as each phase lands.
struct PlaceholderView: View {
    let title: String
    let systemImage: String
    let detail: String
    let phase: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.Space.xl) {
                    Spacer(minLength: Tokens.Space.xxl)
                    GlassCard {
                        VStack(spacing: Tokens.Space.md) {
                            Image(systemName: systemImage)
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(Tokens.accent)
                            Text(detail)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            StatusPill(.busy("Coming in \(phase)"))
                        }
                    }
                    .padding(.horizontal, Tokens.Space.xl)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(title)
        }
    }
}
