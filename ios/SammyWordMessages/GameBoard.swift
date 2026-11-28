import Foundation

/// A single letter tile, always one character ("A"…"Z"). Matches the web app,
/// which draws single letters from a weighted bag (no multi-letter "QU" tile).
struct Tile: Identifiable, Equatable {
    let id: Int       // its cell index on the grid (rows*cols)
    let letter: String
}

/// Weighted single-letter bag (Scrabble-ish distribution), identical to the web
/// app's `LETTER_BAG` so iOS and web boards feel the same.
enum LetterBag {
    static let letters: [Character] = {
        let freq: [(Character, Int)] = [
            ("A", 9), ("B", 2), ("C", 2), ("D", 4), ("E", 12), ("F", 2), ("G", 3),
            ("H", 2), ("I", 9), ("J", 1), ("K", 1), ("L", 4), ("M", 2), ("N", 6),
            ("O", 8), ("P", 2), ("Q", 1), ("R", 6), ("S", 4), ("T", 6), ("U", 4),
            ("V", 2), ("W", 2), ("X", 1), ("Y", 2), ("Z", 1),
        ]
        return freq.flatMap { Array(repeating: $0.0, count: $0.1) }
    }()

    static func random() -> String {
        String(letters.randomElement() ?? "E")
    }
}

/// A board shape: a `rows × cols` grid where `mask[i] == true` marks a playable
/// cell and `false` is a hole. Mirrors the web app's maps.
struct GameMap: Identifiable, Equatable {
    let id: String
    let name: String
    let rows: Int
    let cols: Int
    let mask: [Bool]              // length == rows * cols

    var cellCount: Int { rows * cols }
    var activeCount: Int { mask.lazy.filter { $0 }.count }

    /// Build from an ASCII template: '#' is a playable cell, anything else a hole.
    static func make(_ id: String, _ name: String, _ template: [String]) -> GameMap {
        let rows = template.count
        let cols = template.first?.count ?? 0
        var mask: [Bool] = []
        for line in template { for ch in line { mask.append(ch == "#") } }
        return GameMap(id: id, name: name, rows: rows, cols: cols, mask: mask)
    }

    static func map(id: String) -> GameMap { all.first { $0.id == id } ?? classic }

    // The selectable shapes — same templates as the web app.
    static let classic = make("classic", "Classic", [
        "####",
        "####",
        "####",
        "####",
    ])
    static let donut = make("donut", "Donut", [
        ".####.",
        "######",
        "##..##",
        "##..##",
        "######",
        ".####.",
    ])
    static let plus = make("plus", "Plus", [
        "..##..",
        "..##..",
        "######",
        "######",
        "..##..",
        "..##..",
    ])
    static let diamond = make("diamond", "Diamond", [
        "..##..",
        ".####.",
        "######",
        "######",
        ".####.",
        "..##..",
    ])
    static let heart = make("heart", "Heart", [
        "##..##",
        "######",
        "######",
        ".####.",
        "..##..",
    ])

    static let all: [GameMap] = [classic, donut, plus, diamond, heart]
}

/// A filled board: a map plus a letter (or `nil` for holes) per cell. Pure value
/// type — no UIKit/Messages, so it stays portable.
struct GameBoard: Equatable {
    let map: GameMap
    let cells: [String?]         // length == map.cellCount; nil == hole

    /// Playable letters in cell-index order — what we serialize in a challenge.
    var letters: [String] { cells.compactMap { $0 } }

    /// Rendering tiles for the active cells (id == cell index).
    var tiles: [Tile] {
        cells.enumerated().compactMap { idx, c in c.map { Tile(id: idx, letter: $0) } }
    }

    func letter(at index: Int) -> String? {
        guard cells.indices.contains(index) else { return nil }
        return cells[index]
    }

    func isActive(_ index: Int) -> Bool {
        cells.indices.contains(index) && cells[index] != nil
    }

    /// Fill a map's playable cells with `letters` (in active order); any missing
    /// letters are drawn from the bag, holes stay nil.
    static func from(map: GameMap, letters: [String]) -> GameBoard {
        var cells = [String?](repeating: nil, count: map.cellCount)
        var k = 0
        for i in 0..<map.cellCount where map.mask[i] {
            cells[i] = k < letters.count ? letters[k].uppercased() : LetterBag.random()
            k += 1
        }
        return GameBoard(map: map, cells: cells)
    }

    /// A quick random board (no solvability guarantee) — used only as a
    /// placeholder before a real generated board replaces it.
    static func random(map: GameMap = .classic) -> GameBoard {
        from(map: map, letters: (0..<map.activeCount).map { _ in LetterBag.random() })
    }

    /// 8-directional (king-move) adjacency between two cell indices on a `cols`
    /// wide grid.
    static func adjacent(_ a: Int, _ b: Int, cols: Int) -> Bool {
        guard a != b else { return false }
        let ar = a / cols, ac = a % cols
        let br = b / cols, bc = b % cols
        return abs(ar - br) <= 1 && abs(ac - bc) <= 1
    }
}
