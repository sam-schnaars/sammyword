import SwiftUI

/// All colors and fonts in one place — re-theming later is a single-file edit.
/// Mirrors the Sammy Word web app: near-black background with faint diagonal
/// metal stripes, brushed-steel tiles, cool blue selection trail, and a blue
/// "valid word" bubble.
enum Theme {
    // App background (near-black with faint diagonal stripes)
    static let bgDark = Color(hex: 0x0C0C10)
    static let bgStripeA = Color(hex: 0x0E0E14)
    static let bgStripeB = Color(hex: 0x111118)
    static var background: some View { StripedBackground() }

    // Board frame
    static let boardPanel = Color(hex: 0x16171E)
    static let boardRim = Color(hex: 0x3C3F52)
    static let boardRimDark = Color(hex: 0x1A1B24)

    // Brushed-metal tiles
    static let tileTop = Color(hex: 0x545A6A)
    static let tileBottom = Color(hex: 0x363B48)
    static let tileText = Color(hex: 0xDDE3F0)
    static var tileGradient: LinearGradient {
        LinearGradient(colors: [tileTop, tileBottom], startPoint: .top, endPoint: .bottom)
    }

    // Selection (cool blue) + trail
    static let selected = Color(hex: 0x4A8FD4)
    static let selectedRing = Color(hex: 0x7AB8F5)
    static let trail = Color(hex: 0x7AB8F5)

    // HUD / cards / panels
    static let headerCard = Color(hex: 0x1A1B24)
    static let panel = Color(hex: 0x1F2030)
    static let panelBorder = Color(hex: 0x2E3040)
    static let headerText = Color(hex: 0xC8D4EA)
    static let mutedText = Color(hex: 0x9DA8BE)
    static let dimText = Color(hex: 0x6A76A0)
    static let onBackground = Color.white

    // Current-word bubble states
    static let bubbleBg = Color(hex: 0x1A1B24)
    static let validBubbleBg = Color(hex: 0x15281E)
    static let validBubbleText = Color(hex: 0x5FD4A0)
    static let validBubbleBorder = Color(hex: 0x2E7A56)
    static let dupeBubbleBg = Color(hex: 0x2A2010)
    static let dupeBubbleText = Color(hex: 0xD4A040)
    static let dupeBubbleBorder = Color(hex: 0x6A5020)

    // Primary (blue, 3D) button
    static let accent = Color(hex: 0x3A7BD5)
    static let accentDark = Color(hex: 0x2C5FA8)

    // Positive / completed (green) — e.g. a fully-found word-length goal
    static let positive = Color(hex: 0x5FD4A0)
    static let positiveBg = Color(hex: 0x15281E)
    static let positiveBorder = Color(hex: 0x2E7A56)
    static let positiveDim = Color(hex: 0x5AA982)

    // Timer low / danger
    static let lowBg = Color(hex: 0x3A1820)
    static let lowBorder = Color(hex: 0x8A2030)
    static let lowText = Color(hex: 0xF08090)

    // Fonts (Fredoka-ish rounded for UI, heavy for letters)
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Near-black background with the web app's faint 45° metal stripes.
struct StripedBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.bgStripeA))
            let stripe: CGFloat = 14
            let band = stripe * 2
            let h = size.height
            var x = -h
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + stripe, y: 0))
                p.addLine(to: CGPoint(x: x + stripe - h, y: h))
                p.addLine(to: CGPoint(x: x - h, y: h))
                p.closeSubpath()
                ctx.fill(p, with: .color(Theme.bgStripeB))
                x += band
            }
        }
        .background(Theme.bgDark)
        .ignoresSafeArea()
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
