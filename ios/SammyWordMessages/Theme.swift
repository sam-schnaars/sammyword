import SwiftUI

/// All colors and fonts in one place — re-theming later is a single-file edit.
/// Tuned to approximate GamePigeon's Word Hunt: warm orange background, cream
/// rounded tiles, bold rounded brown letters.
enum Theme {
    // Background gradient
    static let backgroundTop = Color(hex: 0xF5A623)
    static let backgroundBottom = Color(hex: 0xE8821E)
    static var background: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Tiles
    static let tile = Color(hex: 0xFBF3E0)
    static let tileSelected = Color(hex: 0xFFD45E)
    static let tileShadow = Color(hex: 0xD9B98A)
    static let letter = Color(hex: 0x4A3B2A)

    // Selection trail
    static let trail = Color(hex: 0xFFC246).opacity(0.85)

    // UI accents
    static let onBackground = Color.white
    static let pill = Color.white.opacity(0.22)
    static let card = Color.white
    static let accent = Color(hex: 0xE8821E)
    static let valid = Color(hex: 0x3E8E2F)

    // Fonts (GamePigeon-ish rounded)
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
