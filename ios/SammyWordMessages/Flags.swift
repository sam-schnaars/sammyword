import Foundation

/// Country bank + seeded quiz builder for "Flag Match" — the Swift port of the
/// web app's `src/flags.js`. A numeric seed reproduces the exact same questions,
/// so a challenge replays the same quiz for a friend (no backend), mirroring how
/// Word Hunt shares a board.
///
/// Flags render as emoji (two regional-indicator letters from the ISO code), so
/// there are no image assets to host — and they render correctly on iOS.
struct FlagCountry {
    let name: String
    let code: String
    let pop: Double  // approx millions; used only to weight which flags get asked
}

struct FlagQuestion: Identifiable {
    let id = UUID()
    let flag: String
    let name: String
    let options: [String]
    let answer: Int
}

enum Flags {
    static let roundSeconds = 60
    static let questions = 5
    static let pointsPerCorrect = 100

    /// How strongly to bias prompts toward less-populated countries. Higher =
    /// common-knowledge flags (USA, China, India…) show up less. 0 = uniform.
    static let popBias = 0.6

    static let countries: [FlagCountry] = [
        .init(name: "United States", code: "US", pop: 340),
        .init(name: "United Kingdom", code: "GB", pop: 68),
        .init(name: "France", code: "FR", pop: 65),
        .init(name: "Germany", code: "DE", pop: 84),
        .init(name: "Italy", code: "IT", pop: 59),
        .init(name: "Spain", code: "ES", pop: 48),
        .init(name: "Portugal", code: "PT", pop: 10),
        .init(name: "Netherlands", code: "NL", pop: 18),
        .init(name: "Belgium", code: "BE", pop: 12),
        .init(name: "Switzerland", code: "CH", pop: 9),
        .init(name: "Sweden", code: "SE", pop: 10.5),
        .init(name: "Norway", code: "NO", pop: 5.5),
        .init(name: "Finland", code: "FI", pop: 5.6),
        .init(name: "Denmark", code: "DK", pop: 5.9),
        .init(name: "Ireland", code: "IE", pop: 5.2),
        .init(name: "Iceland", code: "IS", pop: 0.39),
        .init(name: "Poland", code: "PL", pop: 38),
        .init(name: "Greece", code: "GR", pop: 10.4),
        .init(name: "Austria", code: "AT", pop: 9),
        .init(name: "Czechia", code: "CZ", pop: 10.7),
        .init(name: "Hungary", code: "HU", pop: 9.6),
        .init(name: "Russia", code: "RU", pop: 144),
        .init(name: "Ukraine", code: "UA", pop: 38),
        .init(name: "Turkey", code: "TR", pop: 85),
        .init(name: "Canada", code: "CA", pop: 39),
        .init(name: "Mexico", code: "MX", pop: 128),
        .init(name: "Brazil", code: "BR", pop: 216),
        .init(name: "Argentina", code: "AR", pop: 46),
        .init(name: "Chile", code: "CL", pop: 19.6),
        .init(name: "Colombia", code: "CO", pop: 52),
        .init(name: "Peru", code: "PE", pop: 34),
        .init(name: "Japan", code: "JP", pop: 124),
        .init(name: "China", code: "CN", pop: 1410),
        .init(name: "South Korea", code: "KR", pop: 52),
        .init(name: "India", code: "IN", pop: 1430),
        .init(name: "Thailand", code: "TH", pop: 72),
        .init(name: "Vietnam", code: "VN", pop: 99),
        .init(name: "Indonesia", code: "ID", pop: 277),
        .init(name: "Philippines", code: "PH", pop: 117),
        .init(name: "Malaysia", code: "MY", pop: 34),
        .init(name: "Singapore", code: "SG", pop: 5.9),
        .init(name: "Australia", code: "AU", pop: 26),
        .init(name: "New Zealand", code: "NZ", pop: 5.2),
        .init(name: "South Africa", code: "ZA", pop: 60),
        .init(name: "Egypt", code: "EG", pop: 112),
        .init(name: "Nigeria", code: "NG", pop: 223),
        .init(name: "Kenya", code: "KE", pop: 55),
        .init(name: "Morocco", code: "MA", pop: 37),
        .init(name: "Saudi Arabia", code: "SA", pop: 37),
        .init(name: "United Arab Emirates", code: "AE", pop: 9.4),
        .init(name: "Israel", code: "IL", pop: 9.8),
    ]

    /// Turn a 2-letter ISO code into its flag emoji (regional indicator symbols).
    static func flagEmoji(_ code: String) -> String {
        var s = ""
        for u in code.uppercased().unicodeScalars {
            if let scalar = Unicode.Scalar(127397 + u.value) {
                s.unicodeScalars.append(scalar)
            }
        }
        return s
    }

    /// A fresh random seed for a solo round.
    static func randomSeed() -> Int { Int(UInt32.random(in: 0 ... .max)) }

    /// Build a deterministic quiz from `seed`: `count` flags, each with four
    /// country choices (one correct + three distractors), all seeded so the same
    /// seed reproduces the same quiz on any device. Prompts are weighted toward
    /// less-populated countries; distractors are drawn uniformly.
    static func buildQuiz(seed: Int, count: Int = questions) -> [FlagQuestion] {
        var rng = SeededRNG(seed: UInt32(truncatingIfNeeded: seed))
        let indices = Array(countries.indices)
        let weights = countries.map { 1.0 / pow($0.pop, popBias) }
        let chosen = weightedSample(indices, weights, min(count, countries.count), &rng)

        return chosen.map { i in
            let country = countries[i]
            let distractors = Array(shuffled(indices.filter { $0 != i }, &rng).prefix(3))
                .map { countries[$0].name }
            let options = shuffled([country.name] + distractors, &rng)
            return FlagQuestion(
                flag: flagEmoji(country.code),
                name: country.name,
                options: options,
                answer: options.firstIndex(of: country.name) ?? 0
            )
        }
    }

    // MARK: - Private (seeded)

    /// Fisher-Yates shuffle into a new array, driven by `rng`.
    private static func shuffled<T>(_ arr: [T], _ rng: inout SeededRNG) -> [T] {
        var a = arr
        var i = a.count - 1
        while i > 0 {
            let j = rng.int(i + 1)
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }

    /// Weighted sampling of `count` items without replacement.
    private static func weightedSample(
        _ items: [Int], _ weights: [Double], _ count: Int, _ rng: inout SeededRNG
    ) -> [Int] {
        var pool = zip(items, weights).map { (it: $0.0, w: $0.1) }
        var out: [Int] = []
        while out.count < count && !pool.isEmpty {
            let total = pool.reduce(0.0) { $0 + $1.w }
            var r = rng.next() * total
            var k = 0
            while k < pool.count - 1 && r >= pool[k].w {
                r -= pool[k].w
                k += 1
            }
            out.append(pool[k].it)
            pool.remove(at: k)
        }
        return out
    }
}
