import SwiftUI

/// The pixel-art kit: palette, a 5×7 bitmap font, game sprites, bevelled
/// "8-bit" boxes and the night-sky backdrop. Everything is drawn from tiny
/// bitmaps with square cells, so it stays crisp at any size.
enum Pixel {
    static let ink = Color(hex: 0x0A0818)
    static let cream = Color(hex: 0xF6EEDC)
    static let muted = Color(hex: 0xA59CD6)
    static let gold = Color(hex: 0xFFC94A)
    static let goldDark = Color(hex: 0x8A4B12)
    static let green = Color(hex: 0x7BE89A)

    static let panel = PixelPalette(fill: 0x241E4A, light: 0x3D3478, dark: 0x171236)
    static let row = PixelPalette(fill: 0x1C173B, light: 0x302A62, dark: 0x120E2A)
    static let button = PixelPalette(fill: 0x3FBF6F, light: 0x86EFA6, dark: 0x1F7F45)
    static let featured = PixelPalette(fill: 0x2E2358, light: 0xFFC94A, dark: 0xB5762A)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct PixelPalette {
    let fill: Color, light: Color, dark: Color
    init(fill: UInt, light: UInt, dark: UInt) {
        self.fill = Color(hex: fill); self.light = Color(hex: light); self.dark = Color(hex: dark)
    }
}

// MARK: - Font

enum PixelFont {
    static let width = 5, height = 7

    static let glyphs: [Character: [[Bool]]] = raw.mapValues { rows in rows.map { $0.map { $0 == "#" } } }

    private static let raw: [Character: [String]] = [
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
        " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
        "·": [".....", ".....", ".....", "..#..", ".....", ".....", "....."],
        ".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
        ",": [".....", ".....", ".....", ".....", ".....", "..#..", ".#..."],
        ":": [".....", "..#..", ".....", ".....", ".....", "..#..", "....."],
        "'": ["..#..", "..#..", ".....", ".....", ".....", ".....", "....."],
        "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
        "_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
        "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
        "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
        "#": [".#.#.", ".#.#.", "#####", ".#.#.", "#####", ".#.#.", ".#.#."],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
        "✓": [".....", "....#", "...##", "#.##.", "###..", ".#...", "....."],
        "▶": ["#....", "##...", "###..", "####.", "###..", "##...", "#...."],
        "◀": ["....#", "...##", "..###", ".####", "..###", "...##", "....#"],
        "★": ["..#..", "..#..", "#####", ".###.", ".###.", "##.##", "#...#"],
    ]
}

/// One line of text in the pixel font. `scale` is points per font pixel.
struct PixelText: View {
    let text: String
    var scale: CGFloat = 2
    var color: Color = Pixel.cream
    var shadow: Color? = Pixel.ink

    init(_ text: String, scale: CGFloat = 2, color: Color = Pixel.cream, shadow: Color? = Pixel.ink) {
        self.text = text; self.scale = scale; self.color = color; self.shadow = shadow
    }

    var body: some View {
        let chars = Array(text.uppercased())
        let lift = shadow == nil ? 0 : scale
        let width = CGFloat(max(chars.count * 6 - 1, 0)) * scale + lift
        let height = CGFloat(PixelFont.height) * scale + lift
        Canvas { ctx, _ in
            var path = Path()
            for (i, ch) in chars.enumerated() {
                guard let rows = PixelFont.glyphs[ch] else { continue }
                for (y, row) in rows.enumerated() {
                    for (x, on) in row.enumerated() where on {
                        path.addRect(CGRect(x: CGFloat(i * 6 + x) * scale, y: CGFloat(y) * scale,
                                            width: scale, height: scale))
                    }
                }
            }
            if let shadow {
                ctx.fill(path.offsetBy(dx: scale, dy: scale), with: .color(shadow))
            }
            ctx.fill(path, with: .color(color))
        }
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel(text)
    }
}

// MARK: - Sprites

/// A small bitmap: one character per cell, `.` is transparent.
struct PixelArt {
    let rows: [String]
    let palette: [Character: UInt]
    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }
}

struct PixelSprite: View {
    let art: PixelArt
    var scale: CGFloat = 4

    var body: some View {
        Canvas { ctx, _ in
            var paths: [Character: Path] = [:]
            for (y, row) in art.rows.enumerated() {
                for (x, ch) in row.enumerated() where art.palette[ch] != nil {
                    paths[ch, default: Path()].addRect(
                        CGRect(x: CGFloat(x) * scale, y: CGFloat(y) * scale, width: scale, height: scale))
                }
            }
            for (ch, path) in paths {
                ctx.fill(path, with: .color(Color(hex: art.palette[ch]!)))
            }
        }
        .frame(width: CGFloat(art.width) * scale, height: CGFloat(art.height) * scale)
        .accessibilityHidden(true)
    }
}

extension Game {
    var sprite: PixelArt {
        switch self {
        case .wordHunt:
            return PixelArt(rows: [
                "oooooooooooo",
                "ollllllllllo",
                "olccccccccdo",
                "olwccccccwdo",
                "olwccccccwdo",
                "olwccwwccwdo",
                "olwccwwccwdo",
                "olwcwccwcwdo",
                "olwwccccwwdo",
                "olccccccccdo",
                "oddddddddddo",
                "oooooooooooo",
            ], palette: ["o": 0x0A0818, "l": 0x9C99CC, "c": 0x4A4870, "d": 0x2A2848, "w": 0xF6EEDC])
        case .flagMatch:
            return PixelArt(rows: [
                "pp..........",
                "pprrrrrrrr..",
                "pprrrrrrrrr.",
                "ppwwwwwwwww.",
                "ppwwwwwwwww.",
                "ppbbbbbbbbb.",
                "ppbbbbbbbb..",
                "pp..........",
                "pp..........",
                "pp..........",
                "pp..........",
                "pppp........",
            ], palette: ["p": 0xC9CFE8, "r": 0xE5484D, "w": 0xF6EEDC, "b": 0x3B82F6])
        case .captionMeme:
            return PixelArt(rows: [
                "oooooooooooo",
                "oyyyyyyyyyyo",
                "oybbbbbbbbyo",
                "oybbbbbbssyo",
                "oybbbbbbssyo",
                "oybbbgbbbbyo",
                "oybbgggbbbyo",
                "oybgggggbbyo",
                "oyyyyyyyyyyo",
                "owwwwwwwwwwo",
                "owkkwkwkkkwo",
                "oooooooooooo",
            ], palette: ["o": 0x0A0818, "y": 0xFFC94A, "b": 0x7AB8F5, "s": 0xF6EEDC,
                         "g": 0x4CD07D, "w": 0xF6EEDC, "k": 0x0A0818])
        case .reels:
            return PixelArt(rows: [
                "...oooooo...",
                "...owwwwo...",
                "...obbbbo...",
                "...obybbo...",
                "...obbbbo...",
                "...obbybo...",
                "...obbbbo...",
                "...oryybo...",
                "...obbbbo...",
                "...owwwwo...",
                "...ow..wo...",
                "...oooooo...",
            ], palette: ["o": 0x0A0818, "w": 0x9C99CC, "b": 0x241E4A, "y": 0xFFC94A, "r": 0xFF6AD5])
        case .krillion:
            return PixelArt(rows: [
                "ff..........",
                "..f.pppp....",
                "...ppeppkp..",
                "..pppppppkp.",
                "..ff.pppppkp",
                "..f.f.ppppkp",
                "......ppppkp",
                ".....pppppk.",
                "...ppppppk..",
                "..ppkkkk....",
                ".pp.pp......",
                "pp...p......",
            ], palette: ["p": 0xFF8A65, "k": 0xD9533A, "e": 0x0A0818, "f": 0xFFC2A8])
        case .magnitudle:
            return PixelArt(rows: [
                "...oooooo...",
                "..ocdccdco..",
                ".ocdcccccro.",
                "ocdcccccrcco",
                "occccccrccco",
                "odcccrrcccdo",
                "occccrrcccco",
                "oooooooooooo",
                "....bbbb....",
                "..bbbbbbbb..",
            ], palette: ["o": 0x0A0818, "c": 0xF6EEDC, "d": 0x3A3060, "r": 0xFF4D4D, "b": 0x6B5BB0])
        case .hundredOfUs:
            return PixelArt(rows: [
                "....oooo....",
                "..oowllwoo..",
                ".owwllllwwo.",
                ".owllllwwwo.",
                "owwwlllwwwwo",
                "owwwwllwwllo",
                "owwwwwwwlllo",
                "owllwwwwlllo",
                ".owllwwwwlo.",
                ".owwlwwwwwo.",
                "..oowwwwoo..",
                "....oooo....",
            ], palette: ["o": 0x0A0818, "w": 0x3B82F6, "l": 0x4CD07D])
        case .eraly:
            return PixelArt(rows: [
                "bbbbbbbbbbbb",
                ".bggggggggb.",
                ".byyyyyyyyb.",
                "..byyyyyyb..",
                "...byyyyb...",
                "....byyb....",
                "....bgyb....",
                "...bggygb...",
                "..bgggyggb..",
                ".bgggyyyggb.",
                ".byyyyyyyyb.",
                "bbbbbbbbbbbb",
            ], palette: ["b": 0xA0612E, "g": 0xBFE3FF, "y": 0xFFC94A])
        }
    }

    /// The color the game glows in on the home screen.
    var glow: UInt {
        switch self {
        case .wordHunt: return 0x7AB8F5
        case .flagMatch: return 0xE5484D
        case .captionMeme: return 0xFF6AD5
        case .reels: return 0x6EC3FF
        case .krillion: return 0xFF8A65
        case .magnitudle: return 0xFF5A5A
        case .hundredOfUs: return 0x3FC9B0
        case .eraly: return 0xFFC94A
        }
    }
}

enum PixelSprites {
    static let flame = PixelArt(rows: [
        "....o...",
        "...oo...",
        "..oyo.o.",
        ".oyyooo.",
        ".oyyyyo.",
        "oyywwyyo",
        "oyywwyyo",
        ".oyyyyo.",
        "..oooo..",
    ], palette: ["o": 0xFF5A3C, "y": 0xFFB13B, "w": 0xFFF1B0])
}

/// A filled pixel circle `cells` across.
struct PixelDisc: View {
    let cells: Int
    var scale: CGFloat = 4
    var color: Color

    var body: some View {
        Canvas { ctx, _ in
            ctx.fill(Self.path(cells: cells, scale: scale, origin: .zero), with: .color(color))
        }
        .frame(width: CGFloat(cells) * scale, height: CGFloat(cells) * scale)
    }

    static func path(cells: Int, scale: CGFloat, origin: CGPoint) -> Path {
        var path = Path()
        let r = Double(cells) / 2
        for y in 0..<cells {
            for x in 0..<cells {
                let dx = Double(x) + 0.5 - r, dy = Double(y) + 0.5 - r
                if dx * dx + dy * dy <= r * r {
                    path.addRect(CGRect(x: origin.x + CGFloat(x) * scale, y: origin.y + CGFloat(y) * scale,
                                        width: scale, height: scale))
                }
            }
        }
        return path
    }
}

// MARK: - Boxes and buttons

/// Rectangle with one-step notched corners, the classic 8-bit window shape.
struct PixelFrame: Shape {
    var step: CGFloat

    func path(in r: CGRect) -> Path {
        let s = step
        var p = Path()
        p.addLines([
            CGPoint(x: r.minX + s, y: r.minY), CGPoint(x: r.maxX - s, y: r.minY),
            CGPoint(x: r.maxX - s, y: r.minY + s), CGPoint(x: r.maxX, y: r.minY + s),
            CGPoint(x: r.maxX, y: r.maxY - s), CGPoint(x: r.maxX - s, y: r.maxY - s),
            CGPoint(x: r.maxX - s, y: r.maxY), CGPoint(x: r.minX + s, y: r.maxY),
            CGPoint(x: r.minX + s, y: r.maxY - s), CGPoint(x: r.minX, y: r.maxY - s),
            CGPoint(x: r.minX, y: r.minY + s), CGPoint(x: r.minX + s, y: r.minY + s),
        ])
        p.closeSubpath()
        return p
    }
}

/// Bevelled box: ink outline, light top-left edge, dark bottom-right edge and
/// a hard drop shadow (dropped while pressed, so the box "sinks").
struct PixelBox: View {
    var palette: PixelPalette
    var step: CGFloat = 3
    var pressed = false

    var body: some View {
        Canvas { ctx, size in
            let s = step
            let box = CGRect(x: pressed ? s : 0, y: pressed ? s : 0,
                             width: size.width - s, height: size.height - s)
            if !pressed {
                ctx.fill(PixelFrame(step: s).path(in: box.offsetBy(dx: s, dy: s)),
                         with: .color(.black.opacity(0.5)))
            }
            ctx.fill(PixelFrame(step: s).path(in: box), with: .color(Pixel.ink))
            let r = box.insetBy(dx: s, dy: s)
            ctx.fill(Path(r), with: .color(palette.fill))
            ctx.fill(Path(CGRect(x: r.minX, y: r.minY, width: r.width - s, height: s)), with: .color(palette.light))
            ctx.fill(Path(CGRect(x: r.minX, y: r.minY, width: s, height: r.height - s)), with: .color(palette.light))
            ctx.fill(Path(CGRect(x: r.minX + s, y: r.maxY - s, width: r.width - s, height: s)), with: .color(palette.dark))
            ctx.fill(Path(CGRect(x: r.maxX - s, y: r.minY + s, width: s, height: r.height - s)), with: .color(palette.dark))
        }
    }
}

extension View {
    /// Sits the view in a `PixelBox`, leaving room for the drop shadow.
    func pixelBox(_ palette: PixelPalette, step: CGFloat = 3, pressed: Bool = false) -> some View {
        self
            .padding(step)
            .offset(x: pressed ? step : 0, y: pressed ? step : 0)
            .padding(.trailing, step).padding(.bottom, step)
            .background(PixelBox(palette: palette, step: step, pressed: pressed))
    }
}

/// A chunky button that sinks into its shadow when pressed.
struct PixelButtonStyle: ButtonStyle {
    var palette: PixelPalette = Pixel.button
    var step: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pixelBox(palette, step: step, pressed: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

// MARK: - Backdrop

/// Dithered dusk sky with pixel stars, a moon and rolling hills.
struct PixelSky: View {
    var body: some View {
        Canvas { ctx, size in
            let p: CGFloat = 4
            let cols = Int((size.width / p).rounded(.up))
            let rowsTotal = Int((size.height / p).rounded(.up))
            let bands: [UInt] = [0x0B0A1F, 0x100E2A, 0x161335, 0x1E1842, 0x281E4F, 0x34245A]
            let bandRows = max(1, rowsTotal / bands.count)

            for (i, hex) in bands.enumerated() {
                let top = CGFloat(i * bandRows) * p
                let height = i == bands.count - 1 ? size.height - top : CGFloat(bandRows) * p
                ctx.fill(Path(CGRect(x: 0, y: top, width: size.width, height: height)), with: .color(Color(hex: hex)))
                guard i > 0 else { continue }
                // Two rows of checkerboard dither blend each band into the last.
                var dither = Path()
                for row in 0..<2 {
                    for c in 0..<cols where (c + row) % (row == 0 ? 2 : 4) == 0 {
                        dither.addRect(CGRect(x: CGFloat(c) * p, y: top + CGFloat(row) * p, width: p, height: p))
                    }
                }
                ctx.fill(dither, with: .color(Color(hex: bands[i - 1])))
            }

            // Stars (fixed pseudo-random field, so it never flickers between renders).
            var seed: UInt64 = 0x5A3D17
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / Double(1 << 31)
            }
            var dim = Path(), bright = Path(), sparkle = Path()
            for _ in 0..<70 {
                let x = (next() * Double(cols)).rounded(.down) * p
                let y = (next() * Double(rowsTotal) * 0.7).rounded(.down) * p
                let kind = next()
                if kind < 0.1 {
                    sparkle.addRect(CGRect(x: x, y: y, width: p, height: p))
                    sparkle.addRect(CGRect(x: x - p, y: y, width: p, height: p))
                    sparkle.addRect(CGRect(x: x + p, y: y, width: p, height: p))
                    sparkle.addRect(CGRect(x: x, y: y - p, width: p, height: p))
                    sparkle.addRect(CGRect(x: x, y: y + p, width: p, height: p))
                } else if kind < 0.45 {
                    bright.addRect(CGRect(x: x, y: y, width: p, height: p))
                } else {
                    dim.addRect(CGRect(x: x, y: y, width: p, height: p))
                }
            }
            ctx.fill(dim, with: .color(Color(hex: 0x6D68A8)))
            ctx.fill(bright, with: .color(Color(hex: 0xC9CFFF)))
            ctx.fill(sparkle, with: .color(Color(hex: 0xFFF4D6)))

            // Moon with a bite taken out of it.
            let moonOrigin = CGPoint(x: (size.width / p - 12).rounded(.down) * p, y: 3 * p)
            ctx.fill(PixelDisc.path(cells: 10, scale: p, origin: moonOrigin), with: .color(Color(hex: 0xFFF1C2)))
            ctx.fill(PixelDisc.path(cells: 9, scale: p, origin: CGPoint(x: moonOrigin.x + 3 * p, y: moonOrigin.y - p)),
                     with: .color(Color(hex: bands[0])))

            // Two layers of stepped hills along the bottom.
            for (layer, hex) in [(0, UInt(0x1A1536)), (1, UInt(0x110E25))] {
                var hills = Path()
                for c in 0..<cols {
                    let t = Double(c)
                    let wave = layer == 0
                        ? 9 + 4 * sin(t / 9) + 2 * sin(t / 3.7)
                        : 5 + 3 * sin(t / 6 + 2) + 1.5 * sin(t / 2.3)
                    let h = CGFloat(wave.rounded()) * p
                    hills.addRect(CGRect(x: CGFloat(c) * p, y: size.height - h, width: p, height: h))
                }
                ctx.fill(hills, with: .color(Color(hex: hex)))
            }
        }
        .background(Color(hex: 0x0B0A1F))
        .ignoresSafeArea()
    }
}
