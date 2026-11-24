import Foundation

/// Doodle: one player picks a secret word and draws it on a small pixel grid;
/// everyone else in the chat tries to guess it. Pure rules and data, no UI.
enum Doodle {
    static let size = 12                 // the grid is size × size cells
    static let maxGuesses = 6

    /// Drawing colors, indexed 1…8 (0 is an empty cell, drawn as paper).
    static let palette: [UInt] = [
        0xF6EEDC,   // 0 paper
        0x1A1530,   // 1 ink
        0xE5484D,   // 2 red
        0xFF9F43,   // 3 orange
        0xFFC94A,   // 4 yellow
        0x4CD07D,   // 5 green
        0x3B82F6,   // 6 blue
        0xA66BFF,   // 7 purple
        0x8B5A2B,   // 8 brown
    ]

    /// Things that are fun to draw on a 12×12 grid and easy to name.
    static let words: [String] = [
        "apple", "banana", "pizza", "donut", "cake", "cookie", "carrot", "cherry",
        "cat", "dog", "fish", "bird", "duck", "frog", "snake", "spider", "bee",
        "snail", "whale", "octopus", "crab", "owl", "bunny", "turtle", "pig",
        "sun", "moon", "star", "cloud", "rainbow", "rain", "snowman", "tree",
        "flower", "cactus", "mushroom", "leaf", "volcano", "mountain", "island",
        "house", "castle", "car", "boat", "rocket", "train", "plane", "bike",
        "heart", "key", "lock", "clock", "lamp", "phone", "camera", "glasses",
        "hat", "crown", "shoe", "sock", "shirt", "umbrella", "balloon", "gift",
        "guitar", "drum", "ghost", "robot", "alien", "skull", "sword", "shield",
        "anchor", "candle", "book", "pencil", "cup", "bottle", "bell", "kite",
        "ball", "dice", "door", "ladder", "flag", "tent", "bone", "egg",
        "burger", "taco", "icecream", "lollipop", "teapot", "magnet", "bomb", "diamond",
    ]

    /// Three different words to choose from for a new drawing.
    static func choices(count: Int = 3) -> [Int] {
        Array(words.indices.shuffled().prefix(count))
    }

    /// The hidden word travels lightly scrambled so a glance at the link
    /// doesn't give it away. (It isn't meant to be secure.)
    static func scramble(_ index: Int) -> Int { (index * 37 + 11) % 997 }
    static func unscramble(_ code: Int) -> Int? {
        words.indices.first { scramble($0) == code }
    }

    static func word(forSecret code: Int?) -> String? {
        code.flatMap(unscramble).map { words[$0] }
    }

    // MARK: Drawings

    static var blank: [Int] { Array(repeating: 0, count: size * size) }

    /// One digit per cell, row by row.
    static func encode(_ cells: [Int]) -> String {
        cells.map { String(min(max($0, 0), palette.count - 1)) }.joined()
    }

    static func decode(_ text: String) -> [Int] {
        let digits = text.compactMap { $0.wholeNumberValue }
        guard digits.count == size * size else { return blank }
        return digits.map { min($0, palette.count - 1) }
    }

    static func isValidDrawing(_ text: String) -> Bool {
        text.count == size * size && text.allSatisfy { ($0.wholeNumberValue ?? 99) < palette.count }
    }

    // MARK: Guessing

    /// Forgiving match: case, spaces and a trailing "s" don't matter.
    static func matches(_ guess: String, _ word: String) -> Bool {
        func norm(_ s: String) -> String {
            s.lowercased().filter(\.isLetter)
        }
        let g = norm(guess), w = norm(word)
        guard !g.isEmpty else { return false }
        return g == w || g == w + "s" || g + "s" == w || g == w + "es"
    }

    /// The word shown as blanks, revealing more letters after each wrong guess:
    /// the first letter after 2 misses, then every third letter after 4.
    static func hint(for word: String, misses: Int) -> String {
        let letters = Array(word.uppercased())
        return letters.enumerated().map { i, ch in
            let show = (misses >= 2 && i == 0) || (misses >= 4 && i % 3 == 0)
            return show ? String(ch) : "_"
        }.joined(separator: " ")
    }
}
