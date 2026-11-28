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
    let tier: Int  // 1 = a flag everyone knows … 5 = obscure
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

    /// The quiz ramps up: flag 1 comes from tier 1, flag 5 from tier 5, and
    /// from flag 3 on, the wrong answers include look-alike flags. Must stay
    /// identical to `src/flags.js` so a seed gives the same quiz on both.
    static let tiers = 5

    static let countries: [FlagCountry] = [
        .init(name: "United States", code: "US", tier: 1),
        .init(name: "United Kingdom", code: "GB", tier: 1),
        .init(name: "France", code: "FR", tier: 1),
        .init(name: "Germany", code: "DE", tier: 1),
        .init(name: "Italy", code: "IT", tier: 1),
        .init(name: "Spain", code: "ES", tier: 1),
        .init(name: "Japan", code: "JP", tier: 1),
        .init(name: "China", code: "CN", tier: 1),
        .init(name: "Canada", code: "CA", tier: 1),
        .init(name: "Brazil", code: "BR", tier: 1),
        .init(name: "Mexico", code: "MX", tier: 1),
        .init(name: "India", code: "IN", tier: 1),
        .init(name: "Australia", code: "AU", tier: 1),
        .init(name: "South Korea", code: "KR", tier: 1),
        .init(name: "Russia", code: "RU", tier: 1),
        .init(name: "Portugal", code: "PT", tier: 2),
        .init(name: "Netherlands", code: "NL", tier: 2),
        .init(name: "Switzerland", code: "CH", tier: 2),
        .init(name: "Sweden", code: "SE", tier: 2),
        .init(name: "Norway", code: "NO", tier: 2),
        .init(name: "Greece", code: "GR", tier: 2),
        .init(name: "Ireland", code: "IE", tier: 2),
        .init(name: "Turkey", code: "TR", tier: 2),
        .init(name: "Argentina", code: "AR", tier: 2),
        .init(name: "South Africa", code: "ZA", tier: 2),
        .init(name: "Egypt", code: "EG", tier: 2),
        .init(name: "Israel", code: "IL", tier: 2),
        .init(name: "Poland", code: "PL", tier: 2),
        .init(name: "Ukraine", code: "UA", tier: 2),
        .init(name: "New Zealand", code: "NZ", tier: 2),
        .init(name: "Denmark", code: "DK", tier: 2),
        .init(name: "Belgium", code: "BE", tier: 2),
        .init(name: "Jamaica", code: "JM", tier: 2),
        .init(name: "Finland", code: "FI", tier: 3),
        .init(name: "Austria", code: "AT", tier: 3),
        .init(name: "Iceland", code: "IS", tier: 3),
        .init(name: "Czechia", code: "CZ", tier: 3),
        .init(name: "Hungary", code: "HU", tier: 3),
        .init(name: "Chile", code: "CL", tier: 3),
        .init(name: "Colombia", code: "CO", tier: 3),
        .init(name: "Peru", code: "PE", tier: 3),
        .init(name: "Thailand", code: "TH", tier: 3),
        .init(name: "Vietnam", code: "VN", tier: 3),
        .init(name: "Indonesia", code: "ID", tier: 3),
        .init(name: "Philippines", code: "PH", tier: 3),
        .init(name: "Malaysia", code: "MY", tier: 3),
        .init(name: "Singapore", code: "SG", tier: 3),
        .init(name: "Nigeria", code: "NG", tier: 3),
        .init(name: "Kenya", code: "KE", tier: 3),
        .init(name: "Morocco", code: "MA", tier: 3),
        .init(name: "Saudi Arabia", code: "SA", tier: 3),
        .init(name: "United Arab Emirates", code: "AE", tier: 3),
        .init(name: "Cuba", code: "CU", tier: 3),
        .init(name: "Pakistan", code: "PK", tier: 3),
        .init(name: "Uruguay", code: "UY", tier: 3),
        .init(name: "Romania", code: "RO", tier: 4),
        .init(name: "Bulgaria", code: "BG", tier: 4),
        .init(name: "Croatia", code: "HR", tier: 4),
        .init(name: "Serbia", code: "RS", tier: 4),
        .init(name: "Slovakia", code: "SK", tier: 4),
        .init(name: "Slovenia", code: "SI", tier: 4),
        .init(name: "Luxembourg", code: "LU", tier: 4),
        .init(name: "Lithuania", code: "LT", tier: 4),
        .init(name: "Latvia", code: "LV", tier: 4),
        .init(name: "Estonia", code: "EE", tier: 4),
        .init(name: "Venezuela", code: "VE", tier: 4),
        .init(name: "Ecuador", code: "EC", tier: 4),
        .init(name: "Bolivia", code: "BO", tier: 4),
        .init(name: "Paraguay", code: "PY", tier: 4),
        .init(name: "Iraq", code: "IQ", tier: 4),
        .init(name: "Syria", code: "SY", tier: 4),
        .init(name: "Jordan", code: "JO", tier: 4),
        .init(name: "Kuwait", code: "KW", tier: 4),
        .init(name: "Qatar", code: "QA", tier: 4),
        .init(name: "Ghana", code: "GH", tier: 4),
        .init(name: "Senegal", code: "SN", tier: 4),
        .init(name: "Ethiopia", code: "ET", tier: 4),
        .init(name: "Tunisia", code: "TN", tier: 4),
        .init(name: "Algeria", code: "DZ", tier: 4),
        .init(name: "Bangladesh", code: "BD", tier: 4),
        .init(name: "Nepal", code: "NP", tier: 4),
        .init(name: "Sri Lanka", code: "LK", tier: 4),
        .init(name: "Iran", code: "IR", tier: 4),
        .init(name: "Malta", code: "MT", tier: 4),
        .init(name: "Chad", code: "TD", tier: 5),
        .init(name: "Andorra", code: "AD", tier: 5),
        .init(name: "Moldova", code: "MD", tier: 5),
        .init(name: "Monaco", code: "MC", tier: 5),
        .init(name: "Ivory Coast", code: "CI", tier: 5),
        .init(name: "Mali", code: "ML", tier: 5),
        .init(name: "Guinea", code: "GN", tier: 5),
        .init(name: "Cameroon", code: "CM", tier: 5),
        .init(name: "Yemen", code: "YE", tier: 5),
        .init(name: "Sudan", code: "SD", tier: 5),
        .init(name: "Bahrain", code: "BH", tier: 5),
        .init(name: "Honduras", code: "HN", tier: 5),
        .init(name: "Nicaragua", code: "NI", tier: 5),
        .init(name: "El Salvador", code: "SV", tier: 5),
        .init(name: "Guatemala", code: "GT", tier: 5),
        .init(name: "Liberia", code: "LR", tier: 5),
        .init(name: "Tajikistan", code: "TJ", tier: 5),
        .init(name: "Bhutan", code: "BT", tier: 5),
        .init(name: "Kiribati", code: "KI", tier: 5),
        .init(name: "Eswatini", code: "SZ", tier: 5),
        .init(name: "Comoros", code: "KM", tier: 5),
        .init(name: "Tuvalu", code: "TV", tier: 5),
        .init(name: "Nauru", code: "NR", tier: 5),
        .init(name: "Vanuatu", code: "VU", tier: 5),
        .init(name: "Brunei", code: "BN", tier: 5),
        .init(name: "Liechtenstein", code: "LI", tier: 5),
        .init(name: "San Marino", code: "SM", tier: 5),
        .init(name: "Niger", code: "NE", tier: 5),
        .init(name: "Palau", code: "PW", tier: 5),
        .init(name: "Maldives", code: "MV", tier: 5),
    ]

    /// Groups of flags that are easy to mix up.
    static let lookalikes: [[String]] = [
        ["TD", "RO", "AD", "MD"],
        ["ID", "MC", "PL"],
        ["IE", "CI", "IT"],
        ["NL", "LU", "PY"],
        ["AU", "NZ"],
        ["NO", "IS", "DK", "FI", "SE"],
        ["SN", "ML", "GN", "CM"],
        ["CO", "EC", "VE"],
        ["SI", "SK", "RU", "RS"],
        ["EG", "IQ", "SY", "YE"],
        ["JO", "SD", "KW", "AE"],
        ["BE", "DE"],
        ["AT", "LV"],
        ["HN", "NI", "SV", "GT", "AR"],
        ["GH", "BO", "LT", "ET"],
        ["QA", "BH"],
        ["HU", "BG", "IR", "TJ"],
        ["US", "LR", "MY"],
        ["CU", "UY", "GR"],
        ["JP", "BD", "PW"],
        ["TR", "TN"],
        ["CN", "VN"],
        ["IN", "NE"],
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
    /// country choices, getting harder as it goes. Same seed, same quiz, on
    /// any device (mirrors `buildQuiz` in `src/flags.js` step for step).
    static func buildQuiz(seed: Int, count: Int = questions) -> [FlagQuestion] {
        var rng = SeededRNG(seed: UInt32(truncatingIfNeeded: seed))
        var used: [Int] = []
        var quiz: [FlagQuestion] = []
        for q in 0..<count {
            let tier = 1 + (q * tiers) / count
            var pool = countries.indices.filter { countries[$0].tier == tier && !used.contains($0) }
            if pool.isEmpty { pool = countries.indices.filter { !used.contains($0) } }
            let i = pool[rng.int(pool.count)]
            used.append(i)

            let lookCount = min(3, max(0, q - 1))
            let looks = Array(shuffled(lookalikeIndices(countries[i].code), &rng).prefix(lookCount))
            var near = countries.indices.filter {
                $0 != i && !looks.contains($0) && abs(countries[$0].tier - tier) <= 1
            }
            if near.count < 3 - looks.count {
                near = countries.indices.filter { $0 != i && !looks.contains($0) }
            }
            let fill = Array(shuffled(near, &rng).prefix(3 - looks.count))

            let country = countries[i]
            let options = shuffled([i] + looks + fill, &rng).map { countries[$0].name }
            quiz.append(FlagQuestion(
                flag: flagEmoji(country.code),
                name: country.name,
                options: options,
                answer: options.firstIndex(of: country.name) ?? 0
            ))
        }
        return quiz
    }

    /// Look-alike country indices for `code`, in group order, without repeats.
    private static func lookalikeIndices(_ code: String) -> [Int] {
        var out: [Int] = []
        for g in lookalikes where g.contains(code) {
            for c in g where c != code {
                if let j = countries.firstIndex(where: { $0.code == c }), !out.contains(j) { out.append(j) }
            }
        }
        return out
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

}
