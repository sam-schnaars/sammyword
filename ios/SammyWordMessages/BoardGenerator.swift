import Foundation

/// Generates "fun", guaranteed-playable boards for a given map — a direct port
/// of the web app's `generateBoard`. Every board must clear a vowel band
/// (neither consonant soup nor all vowels) and, via the dictionary solver, yield
/// enough words: at least `minLong` words of length ≥ 5 and `minMid` words of
/// length 4. We retry up to `attempts` times, keeping the best near-miss as a
/// fallback so generation always returns a board.
enum BoardGenerator {
    private static let vowels: Set<Character> = ["A", "E", "I", "O", "U"]

    /// Every board must anchor at least this many vowels in its "core" (the cells
    /// nearest the centroid) — the most-connected part of the board, so loading it
    /// with vowels is the surest guarantee the board is solvable.
    private static let centerMinVowels = 2

    /// `pick` supplies each letter and `vowelPick` supplies a forced core vowel;
    /// both default to the random bag. Pass seeded closures (see `dailyBoard`) for
    /// a deterministic board.
    static func generate(
        map: GameMap,
        dictionary: WordDictionary = .shared,
        minLong: Int = 8,
        minMid: Int = 12,
        attempts: Int = 150,
        pick: () -> String = { LetterBag.random() },
        vowelPick: () -> String = { String(["A", "E", "I", "O", "U"].randomElement() ?? "E") }
    ) -> GameBoard {
        dictionary.loadIfNeeded()
        let active = map.activeCount
        let center = centerPositions(map)

        var fallback: [String]?
        var fallbackScore = -1

        for _ in 0..<attempts {
            let letters = (0..<active).map { _ in pick() }

            // Cheap pre-filter: skip the solver on lopsided vowel boards or
            // boards whose core lacks vowels.
            let vowelCount = letters.filter { vowels.contains($0.first ?? " ") }.count
            let ratio = Double(vowelCount) / Double(active)
            if ratio < 0.3 || ratio > 0.6 { continue }
            if centerVowelCount(letters, center) < centerMinVowels { continue }

            let board = GameBoard.from(map: map, letters: letters)
            let words = solve(board: board, dictionary: dictionary)
            var long = 0
            var mid = 0
            for w in words {
                if w.count >= 5 { long += 1 }
                else if w.count == 4 { mid += 1 }
            }
            if long >= minLong && mid >= minMid {
                #if DEBUG
                let longWords = words.filter { $0.count >= 5 }
                    .sorted { $0.count == $1.count ? $0 < $1 : $0.count < $1.count }
                print("[BoardGen] \(map.id): \(longWords.count) valid words of length 5+:")
                print(longWords.joined(separator: ", "))
                #endif
                return board
            }

            let closeness = min(long, minLong) + min(mid, minMid)
            if closeness > fallbackScore {
                fallbackScore = closeness
                fallback = letters
            }
        }

        // Fallbacks already cleared the core-vowel gate; the last-resort raw fill
        // may not, so force its core to guarantee the property holds either way.
        let letters = fallback ?? ensureCenterVowels((0..<active).map { _ in pick() }, center, vowelPick)
        return GameBoard.from(map: map, letters: letters)
    }

    /// A deterministic "Map of the Day" board: the same seed (derived from the
    /// UTC day) reproduces the same board on every launch. Mirrors the web app's
    /// `generateDailyBoard`. (Cross-platform identical boards also require an
    /// identical dictionary — see PARITY.md.)
    static func dailyBoard(
        map: GameMap,
        key: String = dailyKey(),
        dictionary: WordDictionary = .shared
    ) -> GameBoard {
        var rng = SeededRNG(seed: hashStr("sammyword-" + key))
        let bag = LetterBag.letters
        let pick: () -> String = {
            String(bag[min(Int(rng.next() * Double(bag.count)), bag.count - 1)])
        }
        let vowels = ["A", "E", "I", "O", "U"]
        let vowelPick: () -> String = {
            vowels[min(Int(rng.next() * 5), 4)]
        }
        return generate(map: map, dictionary: dictionary, pick: pick, vowelPick: vowelPick)
    }

    /// UTC day key (`YYYY-MM-DD`) so the daily board flips worldwide at once.
    static func dailyKey(_ date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? cal.timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 1, c.day ?? 1)
    }

    /// The active-order positions of the playable cells nearest the centroid,
    /// closest first. (Indexes into the `letters` array, which skips holes.)
    private static func centerPositions(_ map: GameMap, count: Int = 4) -> [Int] {
        var cells: [(pos: Int, r: Int, c: Int)] = []
        var pos = 0
        for i in 0..<map.cellCount where map.mask[i] {
            cells.append((pos, i / map.cols, i % map.cols))
            pos += 1
        }
        guard !cells.isEmpty else { return [] }
        let cr = Double(cells.reduce(0) { $0 + $1.r }) / Double(cells.count)
        let cc = Double(cells.reduce(0) { $0 + $1.c }) / Double(cells.count)
        func d2(_ x: (pos: Int, r: Int, c: Int)) -> Double {
            let dr = Double(x.r) - cr, dc = Double(x.c) - cc
            return dr * dr + dc * dc
        }
        return cells.sorted { d2($0) < d2($1) }.prefix(min(count, cells.count)).map { $0.pos }
    }

    private static func centerVowelCount(_ letters: [String], _ center: [Int]) -> Int {
        center.reduce(0) { $0 + (vowels.contains(letters[$1].first ?? " ") ? 1 : 0) }
    }

    /// Force the core to hold at least `centerMinVowels` vowels, overwriting
    /// non-vowel core cells (closest-to-center first). Only used on the degenerate
    /// fallback path.
    private static func ensureCenterVowels(
        _ letters: [String], _ center: [Int], _ vowelPick: () -> String
    ) -> [String] {
        var out = letters
        var have = centerVowelCount(out, center)
        for p in center where have < centerMinVowels {
            if !vowels.contains(out[p].first ?? " ") {
                out[p] = vowelPick()
                have += 1
            }
        }
        return out
    }

    /// Every dictionary word traceable on the board via king-move adjacency
    /// (skipping holes) without reusing a cell. Prefix matching prunes early.
    static func solve(board: GameBoard, dictionary: WordDictionary = .shared) -> Set<String> {
        let cells = board.cells
        let cols = board.map.cols
        let n = cells.count

        var neighbors = [[Int]](repeating: [], count: n)
        for i in 0..<n where cells[i] != nil {
            for j in 0..<n where j != i && cells[j] != nil && GameBoard.adjacent(i, j, cols: cols) {
                neighbors[i].append(j)
            }
        }

        var found = Set<String>()
        var visited = [Bool](repeating: false, count: n)

        func dfs(_ i: Int, _ prefix: String) {
            guard let letter = cells[i] else { return }
            let word = prefix + letter
            let m = dictionary.match(word)
            guard m.isPrefix else { return }
            if m.isWord && word.count >= 3 { found.insert(word) }
            visited[i] = true
            for j in neighbors[i] where !visited[j] { dfs(j, word) }
            visited[i] = false
        }

        for i in 0..<n where cells[i] != nil { dfs(i, "") }
        return found
    }
}
