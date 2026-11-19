import UIKit

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// Bubble previews for results, one look per game. Drawing glue (UIKit), kept
/// apart from `MessagesViewController` so it can be rendered on its own.
/// Krillion: the score in huge type over a deep-sea gradient, with one colored
/// block per prompt showing how rare each answer was. Plain shapes and text only.
enum WebScoreImageRenderer {
    static func image(for payload: WebScorePayload, size: CGFloat = 320) -> UIImage {
        switch payload.game {
        case .krillion: return krillion(payload, size: size)
        case .magnitudle: return magnitudle(payload, size: size)
        case .hundredOfUs: return hundredOfUs(payload, size: size)
        case .eraly: return eraly(payload, size: size)
        }
    }

    private static func color(for tier: String) -> UIColor {
        switch tier {
        case "plankton": return UIColor(hex: 0x7BD88F)
        case "schooler": return UIColor(hex: 0x4FC3F7)
        case "rare": return UIColor(hex: 0xB388FF)
        case "deepcut": return UIColor(hex: 0xFF6AD5)
        case "krillion": return UIColor(hex: 0xFFD23F)
        default: return UIColor(white: 1, alpha: 0.14)
        }
    }

    static func krillion(_ payload: WebScorePayload, size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(hex: 0x0B3A5C).cgColor, UIColor(hex: 0x040B1C).cgColor]
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size), options: [])
            }
            UIColor(white: 1, alpha: 0.16).setFill()
            for (x, y, s) in [(0.10, 0.62, 0.03), (0.16, 0.48, 0.02), (0.88, 0.30, 0.025), (0.82, 0.16, 0.015), (0.90, 0.66, 0.02)] {
                cg.fill(CGRect(x: size * x, y: size * y, width: size * s, height: size * s))
            }

            let center = NSMutableParagraphStyle()
            center.alignment = .center
            func draw(_ text: String, font: UIFont, color: UIColor, y: CGFloat, h: CGFloat, kern: CGFloat = 0) {
                NSAttributedString(string: text, attributes: [
                    .font: font, .foregroundColor: color, .kern: kern, .paragraphStyle: center,
                ]).draw(in: CGRect(x: size * 0.04, y: size * y, width: size * 0.92, height: size * h))
            }

            let title = "🦐 KRILLION" + (payload.day.map { " #\($0)" } ?? "")
            draw(title, font: .monospacedSystemFont(ofSize: size * 0.065, weight: .heavy),
                 color: UIColor(hex: 0x6FE3FF), y: 0.08, h: 0.1, kern: 2)

            guard let score = payload.score else {
                draw("Today's dive", font: .systemFont(ofSize: size * 0.13, weight: .heavy), color: .white, y: 0.36, h: 0.2)
                draw("tap to play", font: .systemFont(ofSize: size * 0.065, weight: .semibold),
                     color: UIColor(white: 1, alpha: 0.8), y: 0.58, h: 0.1)
                return
            }

            draw(String(score), font: .monospacedDigitSystemFont(ofSize: size * 0.34, weight: .black),
                 color: .white, y: 0.2, h: 0.42)
            draw("\(payload.senderName ?? "My") \(payload.senderName == nil ? "score" : "scored") · can you beat it?",
                 font: .systemFont(ofSize: size * 0.055, weight: .semibold),
                 color: UIColor(white: 1, alpha: 0.85), y: 0.63, h: 0.09)

            // One block per prompt, colored by how rare the answer was.
            let tiers = payload.marks
            if !tiers.isEmpty {
                let gap = size * 0.02
                let block = min(size * 0.1, (size * 0.84 - gap * CGFloat(tiers.count - 1)) / CGFloat(tiers.count))
                let total = block * CGFloat(tiers.count) + gap * CGFloat(tiers.count - 1)
                var x = (size - total) / 2
                for tier in tiers {
                    color(for: tier).setFill()
                    cg.fill(CGRect(x: x, y: size * 0.78, width: block, height: block))
                    x += block + gap
                }
            }
        }
    }

    /// Shared text helper for the renderers below.
    private static func text(_ string: String, _ font: UIFont, _ color: UIColor, _ rect: CGRect,
                             align: NSTextAlignment = .center, kern: CGFloat = 0) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        NSAttributedString(string: string, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style, .kern: kern,
        ]).draw(in: rect)
    }

    /// Magnitudle: the site's near-black and signal red, the score out of 100
    /// in huge type, and a ten-notch meter filled to the score.
    static func magnitudle(_ payload: WebScorePayload, size: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let cg = ctx.cgContext
            let red = UIColor(hex: 0xE5484D), dim = UIColor(hex: 0x8A8F98)
            UIColor(hex: 0x0F1115).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: size, height: size))
            // Faint powers-of-ten ruler along the top.
            for i in 0...20 {
                let x = size * 0.06 + CGFloat(i) * size * 0.044
                UIColor(white: 1, alpha: i % 5 == 0 ? 0.22 : 0.09).setFill()
                cg.fill(CGRect(x: x, y: size * 0.05, width: 1.5, height: size * (i % 5 == 0 ? 0.05 : 0.03)))
            }

            let title = "🧮 MAGNITUDLE" + (payload.day.map { " #\($0)" } ?? "")
            text(title, .monospacedSystemFont(ofSize: size * 0.058, weight: .heavy), .white,
                 CGRect(x: 0, y: size * 0.13, width: size, height: size * 0.09), kern: 1.5)

            guard let score = payload.score else {
                text("Today's\nquestion", .systemFont(ofSize: size * 0.12, weight: .black), .white,
                     CGRect(x: 0, y: size * 0.32, width: size, height: size * 0.32))
                text("one guess · tap to play", .systemFont(ofSize: size * 0.055, weight: .semibold), dim,
                     CGRect(x: 0, y: size * 0.7, width: size, height: size * 0.08))
                return
            }

            // A perfect 100 is three digits wide; shrink it so it never wraps.
            text(String(score), .monospacedDigitSystemFont(ofSize: size * (score >= 100 ? 0.25 : 0.32), weight: .black), .white,
                 CGRect(x: size * 0.02, y: size * 0.22, width: size * 0.66, height: size * 0.4), align: .right)
            text("/100", .monospacedSystemFont(ofSize: size * 0.075, weight: .bold), red,
                 CGRect(x: size * 0.7, y: size * 0.45, width: size * 0.28, height: size * 0.1), align: .left)

            // Ten notches, lit up to the score.
            let lit = Int((Double(score) / 10).rounded())
            let gap = size * 0.014, w = (size * 0.8 - gap * 9) / 10
            for i in 0..<10 {
                (i < lit ? red : UIColor(white: 1, alpha: 0.12)).setFill()
                let r = CGRect(x: size * 0.1 + CGFloat(i) * (w + gap), y: size * 0.68, width: w, height: size * 0.07)
                UIBezierPath(roundedRect: r, cornerRadius: 3).fill()
            }

            text("\(payload.senderName.map { "\($0) scored" } ?? "My score") · can you beat it?",
                 .systemFont(ofSize: size * 0.05, weight: .semibold), dim,
                 CGRect(x: size * 0.04, y: size * 0.84, width: size * 0.92, height: size * 0.08))
        }
    }

    /// 100 of Us: a crowd of 100 dots. Dots up to the real answer are filled,
    /// the stretch between guess and answer is the miss, and the headline is
    /// how far off it was.
    static func hundredOfUs(_ payload: WebScorePayload, size: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let cg = ctx.cgContext
            let ink = UIColor(hex: 0x1D2433), teal = UIColor(hex: 0x1F8A70),
                coral = UIColor(hex: 0xF0904A), empty = UIColor(hex: 0xDCD5C8)
            UIColor(hex: 0xF6F1E7).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: size, height: size))

            let title = "🌍 100 OF US" + (payload.day.map { " · DAY \($0)" } ?? "")
            text(title, .monospacedSystemFont(ofSize: size * 0.052, weight: .heavy), ink,
                 CGRect(x: 0, y: size * 0.05, width: size, height: size * 0.08), kern: 1.2)

            let guess = payload.marks.first.flatMap { Int($0) }
            let answer = payload.marks.dropFirst().first.flatMap { Int($0) }
            let headline = payload.score == nil ? "How many of us…?"
                : payload.score == 0 ? "Spot on!" : "Off by \(payload.score!)"
            text(headline, .systemFont(ofSize: size * 0.105, weight: .black), ink,
                 CGRect(x: 0, y: size * 0.13, width: size, height: size * 0.14))

            // The crowd: 10 × 10, filled in reading order.
            let grid = size * 0.5, pitch = grid / 10, dot = pitch * 0.72
            let ox = (size - grid) / 2, oy = size * 0.29
            for i in 0..<100 {
                let n = i + 1
                let color: UIColor
                if let g = guess, let a = answer {
                    color = n <= min(g, a) ? teal : (n <= max(g, a) ? coral : empty)
                } else {
                    color = empty
                }
                color.setFill()
                let x = ox + CGFloat(i % 10) * pitch + (pitch - dot) / 2
                let y = oy + CGFloat(i / 10) * pitch + (pitch - dot) / 2
                cg.fillEllipse(in: CGRect(x: x, y: y, width: dot, height: dot))
            }

            let foot: String
            if let g = guess, let a = answer {
                foot = "\(payload.senderName ?? "I") guessed \(g) · really \(a)"
            } else {
                foot = "tap to play today's question"
            }
            text(foot, .systemFont(ofSize: size * 0.05, weight: .semibold), ink.withAlphaComponent(0.75),
                 CGRect(x: size * 0.04, y: size * 0.84, width: size * 0.92, height: size * 0.08))
        }
    }

    /// Eraly: a pixel-art dusk like the site's, the score out of 700 in gold,
    /// and one block per moment colored by how close the year was.
    static func eraly(_ payload: WebScorePayload, size: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let cg = ctx.cgContext
            let gold = UIColor(hex: 0xF2C14E), cream = UIColor(hex: 0xF6E7C8)
            // Banded sky, night at the top to sunset at the horizon.
            let bands: [UInt] = [0x1B1430, 0x251A3D, 0x33204A, 0x4A2A52, 0x6B3550, 0x8E4A4C, 0xB4644A, 0xC9803F]
            let bandH = size / CGFloat(bands.count)
            for (i, c) in bands.enumerated() {
                UIColor(hex: c).setFill()
                cg.fill(CGRect(x: 0, y: CGFloat(i) * bandH, width: size, height: bandH + 1))
            }
            UIColor(white: 1, alpha: 0.55).setFill()
            for (x, y) in [(0.08, 0.06), (0.22, 0.16), (0.74, 0.08), (0.9, 0.2), (0.55, 0.04), (0.38, 0.22)] {
                cg.fill(CGRect(x: size * x, y: size * y, width: 3, height: 3))
            }
            // Ground strip.
            UIColor(hex: 0x2A1E1A).setFill()
            cg.fill(CGRect(x: 0, y: size * 0.88, width: size, height: size * 0.12))

            let title = "ERALY" + (payload.day.map { " · DAY \($0)" } ?? "")
            text(title, .monospacedSystemFont(ofSize: size * 0.06, weight: .heavy), gold,
                 CGRect(x: 0, y: size * 0.07, width: size, height: size * 0.09), kern: 3)

            guard let score = payload.score else {
                text("What year\nwas it?", .systemFont(ofSize: size * 0.11, weight: .black), cream,
                     CGRect(x: 0, y: size * 0.28, width: size, height: size * 0.3))
                text("7 moments · tap to travel", .monospacedSystemFont(ofSize: size * 0.048, weight: .bold),
                     cream.withAlphaComponent(0.85), CGRect(x: 0, y: size * 0.66, width: size, height: size * 0.08))
                return
            }

            text(String(score), .monospacedDigitSystemFont(ofSize: size * 0.25, weight: .black), cream,
                 CGRect(x: size * 0.02, y: size * 0.18, width: size * 0.64, height: size * 0.32), align: .right)
            text("/700", .monospacedSystemFont(ofSize: size * 0.07, weight: .bold), gold,
                 CGRect(x: size * 0.68, y: size * 0.36, width: size * 0.3, height: size * 0.1), align: .left)

            // One block per moment, colored like the site's exact/close/near/rough tiers.
            func tier(_ pts: Int) -> UIColor {
                switch pts {
                case 100...: return gold
                case 85..<100: return UIColor(hex: 0x5FD3C6)
                case 60..<85: return UIColor(hex: 0x8BD17C)
                case 30..<60: return UIColor(hex: 0xF29A4E)
                case 1..<30: return UIColor(hex: 0xF07A8C)
                default: return UIColor(white: 1, alpha: 0.15)
                }
            }
            let rounds = payload.marks.compactMap { Int($0) }
            if !rounds.isEmpty {
                let gap = size * 0.02
                let block = min(size * 0.1, (size * 0.84 - gap * CGFloat(rounds.count - 1)) / CGFloat(rounds.count))
                var x = (size - (block * CGFloat(rounds.count) + gap * CGFloat(rounds.count - 1))) / 2
                for pts in rounds {
                    tier(pts).setFill()
                    cg.fill(CGRect(x: x, y: size * 0.56, width: block, height: block))
                    x += block + gap
                }
            }

            text("\(payload.senderName.map { "\($0) scored" } ?? "My score") · can you beat it?",
                 .systemFont(ofSize: size * 0.05, weight: .semibold), cream,
                 CGRect(x: size * 0.04, y: size * 0.73, width: size * 0.92, height: size * 0.08))
        }
    }
}
