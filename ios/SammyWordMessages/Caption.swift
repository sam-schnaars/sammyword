import Foundation

/// Daily Caption the Meme: one pixel-art picture a day, the same for everyone
/// (picked from the Sammy Word day number). Write a caption, send it to the
/// chat, and friends tap the bubble to see yours and write their own.
/// Pure rules and data, no UI. The pictures are our own pixel art.
enum Caption {
    static let maxLength = 80

    struct Meme {
        let name: String
        let art: PixelArt
    }

    /// Today's picture for Sammy Word day `day` (1-based); loops over `memes`.
    static func meme(day: Int) -> Meme {
        let n = memes.count
        return memes[((day - 1) % n + n) % n]
    }

    /// Trim, squash runs of whitespace and cap the length.
    static func clean(_ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(words.prefix(maxLength))
    }

    /// 16×16 scenes. "." is the background, so each one fills its square.
    static let memes: [Meme] = [
        Meme(name: "Cat at the laptop", art: PixelArt(rows: [
            "................",
            "................",
            "..o...o.........",
            "..oo.oo.........",
            "..ooooo.........",
            "..oyoyo.........",
            "..ooooo.........",
            "..oopoo.........",
            "...ooo..........",
            "..ooooo..kkkkkk.",
            ".ooooooo.kssssk.",
            ".ooooooo.kssssk.",
            ".ooooooo.kkkkkk.",
            "bbbbbbbbbbbbbbbb",
            "dddddddddddddddd",
            ".d............d.",
        ], palette: [".": 0x3D3478, "o": 0x2A2848, "y": 0xFFC94A, "p": 0xFF8FB1,
                     "k": 0x9C99CC, "s": 0x7AB8F5, "b": 0xA0612E, "d": 0x6B3E1C])),

        Meme(name: "Dog and the empty bowl", art: PixelArt(rows: [
            "................",
            "................",
            "...bb....bb.....",
            "..bbbbbbbbbb....",
            "..bbwwbbwwbb....",
            "..bbwkbbwkbb....",
            "..bbbbbbbbbb....",
            "...bbbnnbbb.....",
            "....bbbbbb......",
            "...bbbbbbbb.....",
            "..bbbbbbbbbb....",
            "..bbbbbbbbbb....",
            "..bb.bb.bb.bb...",
            "..........rrrrr.",
            "ffffffffffrrrrrf",
            "ffffffffffffffff",
        ], palette: [".": 0x2E2358, "b": 0xC98B4A, "w": 0xF6EEDC, "k": 0x0A0818,
                     "n": 0x0A0818, "r": 0xE5484D, "f": 0x8A5A3B])),

        Meme(name: "Ghost with a coffee", art: PixelArt(rows: [
            "................",
            ".....wwwwww.....",
            "....wwwwwwww....",
            "...wwwwwwwwww...",
            "...wwkwwwwkww...",
            "...wwkwwwwkww...",
            "...wwwwwwwwww.s.",
            "...wwwwkkwwww..s",
            "...wwwwwwwwwwcc.",
            "...wwwwwwwwwcmmc",
            "...wwwwwwwwwcmmc",
            "...wwwwwwwwwccc.",
            "...wwwwwwwwww...",
            "...w.ww.ww.ww...",
            "................",
            "................",
        ], palette: [".": 0x171236, "w": 0xE8E6FF, "k": 0x0A0818, "s": 0x9C99CC,
                     "c": 0xE5484D, "m": 0x6B3E1C])),

        Meme(name: "Snowman in the sun", art: PixelArt(rows: [
            "yyy.............",
            "yyyy............",
            "yyy.............",
            "......kkkk......",
            ".....kkkkkk.....",
            "......wwww......",
            ".....wkwwkw.t...",
            ".....wwwoowww...",
            "......wwww..t...",
            ".....wwwwww.....",
            "....wwwkwwww....",
            "....wwwwwwww....",
            "....wwwkwwww....",
            ".....wwwwww.....",
            "ttgggggggggggggg",
            "gggggggggggggggg",
        ], palette: [".": 0x7AB8F5, "y": 0xFFC94A, "k": 0x0A0818, "w": 0xF6EEDC,
                     "o": 0xFF9F43, "t": 0x3B82F6, "g": 0x4CD07D])),

        Meme(name: "Frog with a tiny umbrella", art: PixelArt(rows: [
            ".r.....r.....r..",
            "....r.....r.....",
            "r.pppp.....r..r.",
            "pppppppp........",
            "pppppppp..r...r.",
            "...k............",
            ".r.k....r....r..",
            "...k.gg...gg....",
            "...kgwkg.gwkg...",
            "...ggggggggggg..",
            "..ggggggggggggg.",
            "....gddddddddg..",
            "....ggggggggggg.",
            ".....gg....gg...",
            "..bbbbbbbbbbbb..",
            "bbbbbbbbbbbbbbbb",
        ], palette: [".": 0x4A4870, "r": 0x7AB8F5, "p": 0xFF6AD5, "k": 0x0A0818,
                     "g": 0x4CD07D, "w": 0xF6EEDC, "d": 0x16603A, "b": 0x1F7F45])),

        Meme(name: "Robot with a flower", art: PixelArt(rows: [
            "......a.........",
            "......a.........",
            "....aaaaaa......",
            "....ammmma......",
            "....amcmca......",
            "....ammmma......",
            "....amkkma......",
            "....aaaaaa......",
            "...mmmmmmmm.r.r.",
            "..mmmmmmmmmm.y..",
            "..mm.mggmm.mmr.r",
            "..mm.mggmm..mn..",
            "..mm.mmmmm...n..",
            ".....mmmmm...n..",
            ".....mm.mm......",
            "....mmm.mmm.....",
        ], palette: [".": 0x241E4A, "a": 0x9C99CC, "m": 0xC9CFE8, "c": 0x7BE89A,
                     "k": 0x0A0818, "g": 0xFFC94A, "r": 0xE5484D, "y": 0xFFC94A, "n": 0x4CD07D])),
    ]
}
