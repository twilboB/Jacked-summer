import SwiftUI

/// The molten identity: colours act as tints, fills, and text colours layered on
/// glass, not as opaque panel fills. Text prefers system label colours so
/// contrast adapts; the ink tones are fallbacks for fixed colours on solid areas.
enum Palette {
    static let base = Color(hex: 0x16130F)
    static let baseDeep = Color(hex: 0x0E0C09) // gradient bottom

    static let molten = Color(hex: 0xFF7A18)
    static let moltenSoft = Color(hex: 0xC9620F)

    static let steel = Color(hex: 0x7FA0A8)
    static let green = Color(hex: 0x86C06A)
    static let red = Color(hex: 0xD8654F)
    static let gold = Color(hex: 0xE7B84B)

    // Fallback ink tones for solid areas (Reduce Transparency).
    static let inkPrimary = Color(hex: 0xF2ECE2)
    static let inkSecondary = Color(hex: 0x9A8F7E)
    static let inkTertiary = Color(hex: 0x5E564A)

    /// Molten gradient for prominent fills (progress bars, flame).
    /// Computed (not a stored static) so it needs no Sendable guarantees under
    /// Swift 6 strict concurrency; gradients are cheap value types.
    static var moltenGradient: LinearGradient {
        LinearGradient(colors: [molten, moltenSoft], startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// The warm base gradient that gives the glass something to refract.
struct WarmBaseBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Palette.base, Palette.baseDeep],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Typography
//
// Numbers are the hero. The prototype used Barlow Condensed; the native stand-in
// is SF Compact / SF Pro in a condensed-to-compressed width. No third-party fonts.

extension Font {
    /// Big hero numerals.
    static func stat(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default).width(.condensed)
    }

    /// Medium condensed numerals for chips and rows.
    static func statSmall(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold).width(.condensed)
    }
}

// MARK: - Accessibility environment convenience

extension EnvironmentValues {
    /// True when the app should replace glass with solid warm surfaces.
    var prefersSolidSurfaces: Bool { accessibilityReduceTransparency }
}
