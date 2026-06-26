import Foundation

/// A single letter tile. `letter` is usually one character ("A"…"Z") but can be
/// the two-character "QU" tile — words concatenate tile letters, so "QU" counts
/// as two letters toward word length and scoring.
struct Tile: Identifiable, Equatable {
    let id: Int       // 0…15, its position on the 4×4 grid
    let letter: String
}

/// Classic 1992 Boggle dice — one face of each die lands in one cell, which
/// keeps the letter distribution playable.
enum BoggleDice {
    static let faces: [[String]] = [
        ["A", "A", "E", "E", "G", "N"],
        ["A", "B", "B", "J", "O", "O"],
        ["A", "C", "H", "O", "P", "S"],
        ["A", "F", "F", "K", "P", "S"],
        ["A", "O", "O", "T", "T", "W"],
        ["C", "I", "M", "O", "T", "U"],
        ["D", "E", "I", "L", "R", "X"],
        ["D", "E", "L", "R", "V", "Y"],
        ["D", "I", "S", "T", "T", "Y"],
        ["E", "E", "G", "H", "N", "W"],
        ["E", "E", "I", "N", "S", "U"],
        ["E", "H", "R", "T", "V", "W"],
        ["E", "I", "O", "S", "S", "T"],
        ["E", "L", "R", "T", "T", "Y"],
        ["H", "I", "M", "N", "U", "QU"], // the "Qu" die
        ["H", "L", "N", "N", "R", "Z"],
    ]
}

/// The 4×4 board. Pure value type — no UIKit/Messages so it stays portable when
/// the concept is re-themed.
struct GameBoard: Equatable {
    static let size = 4
    static let cellCount = size * size

    let tiles: [Tile]

    var letters: [String] { tiles.map(\.letter) }

    /// Shuffle the dice into the cells and pick a random face for each.
    static func random() -> GameBoard {
        let shuffled = BoggleDice.faces.shuffled()
        let tiles = shuffled.enumerated().map { index, die in
            Tile(id: index, letter: die.randomElement() ?? "E")
        }
        return GameBoard(tiles: tiles)
    }

    /// Rebuild a board from a serialized list of letters (e.g. a shared message).
    static func from(letters: [String]) -> GameBoard {
        let normalized = (0..<cellCount).map { i -> String in
            i < letters.count ? letters[i].uppercased() : "E"
        }
        let tiles = normalized.enumerated().map { Tile(id: $0.offset, letter: $0.element) }
        return GameBoard(tiles: tiles)
    }

    /// 8-directional (king-move) adjacency between two cell indices.
    static func adjacent(_ a: Int, _ b: Int) -> Bool {
        guard a != b else { return false }
        let ar = a / size, ac = a % size
        let br = b / size, bc = b % size
        return abs(ar - br) <= 1 && abs(ac - bc) <= 1
    }
}
