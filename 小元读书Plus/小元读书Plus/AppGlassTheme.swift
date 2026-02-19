import SwiftUI

enum AppGlassTheme {
    static var backgroundGradient: LinearGradient {
        gradient(for: .ocean)
    }

    static func gradient(for theme: ReaderTheme) -> LinearGradient {
        let colors: [Color]
        switch theme {
        case .ocean:
            colors = [Color(red: 0.05, green: 0.09, blue: 0.18), Color(red: 0.06, green: 0.19, blue: 0.28), Color(red: 0.09, green: 0.12, blue: 0.22)]
        case .paper:
            colors = [Color(red: 0.96, green: 0.93, blue: 0.86), Color(red: 0.93, green: 0.89, blue: 0.81), Color(red: 0.87, green: 0.83, blue: 0.75)]
        case .dark:
            colors = [Color(red: 0.06, green: 0.06, blue: 0.08), Color(red: 0.09, green: 0.10, blue: 0.12), Color(red: 0.05, green: 0.05, blue: 0.06)]
        case .forest:
            colors = [Color(red: 0.07, green: 0.16, blue: 0.12), Color(red: 0.10, green: 0.24, blue: 0.17), Color(red: 0.06, green: 0.14, blue: 0.11)]
        case .sunset:
            colors = [Color(red: 0.31, green: 0.13, blue: 0.17), Color(red: 0.45, green: 0.20, blue: 0.19), Color(red: 0.67, green: 0.35, blue: 0.25)]
        case .violet:
            colors = [Color(red: 0.16, green: 0.10, blue: 0.24), Color(red: 0.24, green: 0.15, blue: 0.36), Color(red: 0.14, green: 0.10, blue: 0.22)]
        case .graphite:
            colors = [Color(red: 0.14, green: 0.15, blue: 0.17), Color(red: 0.20, green: 0.21, blue: 0.24), Color(red: 0.13, green: 0.14, blue: 0.16)]
        case .emerald:
            colors = [Color(red: 0.04, green: 0.20, blue: 0.18), Color(red: 0.07, green: 0.30, blue: 0.26), Color(red: 0.04, green: 0.18, blue: 0.16)]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.24), lineWidth: 0.9)
            }
            .shadow(color: .black.opacity(0.24), radius: 16, x: 0, y: 10)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
