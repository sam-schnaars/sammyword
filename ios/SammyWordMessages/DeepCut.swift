import Foundation

/// Prompt bank + rarity scoring for "Deep Cut" — the Swift port of the web app's
/// `src/deepcut.js`. Each prompt ("Name a US state") has a fixed list of valid
/// answers tagged with a rarity tier; rarer correct answers score more. A round
/// is a handful of prompts picked from a numeric seed, so a challenge replays the
/// same prompts for a friend (no backend), mirroring Flag Match.
///
/// The bank is `Resources/deepcut.json`, byte-identical to the web's
/// `src/deepcut.json`.
struct DeepAnswer {
    let display: String
    let keys: [String]
    let tier: Int  // 1 common … 4 deep cut
}

struct DeepPrompt {
    let q: String
    let answers: [DeepAnswer]
}

/// One locked-in guess: the matched answer's display name ("" for none) + tier
/// (0 for none).
struct DeepResult: Equatable {
    let answer: String
    let tier: Int
    var points: Int { DeepCut.points(tier: tier) }
}

enum DeepCut {
    static let promptsPerRound = 5
    static let secondsPerPrompt = 20
    static let tierLabels = ["Common", "Solid", "Rare", "Deep cut!"]

    private struct Bank: Decodable {
        let tiers: [Int]
        let prompts: [RawPrompt]
    }
    private struct RawPrompt: Decodable {
        let q: String
        let a: [String]
    }

    private static let bank: Bank = {
        guard let url = Bundle.main.url(forResource: "deepcut", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bank = try? JSONDecoder().decode(Bank.self, from: data)
        else { return Bank(tiers: [100, 250, 500, 1000], prompts: []) }
        return bank
    }()

    static var tierPoints: [Int] { bank.tiers }

    static let prompts: [DeepPrompt] = bank.prompts.map { p in
        DeepPrompt(q: p.q, answers: p.a.compactMap { entry in
            guard let cut = entry.lastIndex(of: ":") else { return nil }
            let names = entry[..<cut].split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            let tier = Int(entry[entry.index(after: cut)...]) ?? 1
            return DeepAnswer(display: names.first ?? "", keys: names.map(normalize), tier: tier)
        })
    }

    static func points(tier: Int) -> Int {
        tier >= 1 && tier <= tierPoints.count ? tierPoints[tier - 1] : 0
    }

    /// Lowercase, strip accents, "&" → "and", drop a leading "the", then keep
    /// only a–z / 0–9. Mirrors the web's `normalize`.
    static func normalize(_ s: String) -> String {
        var t = s.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "&", with: " and ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("the ") { t = String(t.dropFirst(4)) }
        return String(t.unicodeScalars.filter { ("a"..."z").contains($0) || ("0"..."9").contains($0) }
            .map(Character.init))
    }

    /// Exact (normalized) match first; then, for guesses of 5+ chars, forgive a
    /// single typo.
    static func match(prompt: Int, guess: String) -> DeepAnswer? {
        let g = normalize(guess)
        guard !g.isEmpty, prompt < prompts.count else { return nil }
        let answers = prompts[prompt].answers
        if let a = answers.first(where: { $0.keys.contains(g) }) { return a }
        if g.count >= 5 {
            let ga = Array(g)
            return answers.first { a in
                a.keys.contains { $0.count >= 5 && editDistance(ga, Array($0), limit: 1) <= 1 }
            }
        }
        return nil
    }

    static func score(prompt: Int, guess: String) -> DeepResult {
        guard let a = match(prompt: prompt, guess: guess) else { return DeepResult(answer: "", tier: 0) }
        return DeepResult(answer: a.display, tier: a.tier)
    }

    /// The rarest few answers for a prompt — shown after a round.
    static func deepCuts(prompt: Int, n: Int = 3) -> [String] {
        guard prompt < prompts.count else { return [] }
        return prompts[prompt].answers.filter { $0.tier == 4 }.prefix(n).map(\.display)
    }

    /// Deterministic round from `seed`: distinct prompt indices (same
    /// Fisher-Yates + mulberry32 as the web's `buildRound`).
    static func buildRound(seed: Int, count: Int = promptsPerRound) -> [Int] {
        var rng = SeededRNG(seed: UInt32(truncatingIfNeeded: seed))
        var a = Array(prompts.indices)
        var i = a.count - 1
        while i > 0 {
            let j = rng.int(i + 1)
            a.swapAt(i, j)
            i -= 1
        }
        return Array(a.prefix(min(count, a.count)))
    }

    static func randomSeed() -> Int { Int.random(in: 0 ..< 1_000_000_000) }

    /// Levenshtein distance, bailing out early once it exceeds `limit`.
    private static func editDistance(_ a: [Character], _ b: [Character], limit: Int) -> Int {
        if abs(a.count - b.count) > limit { return limit + 1 }
        if a.isEmpty || b.isEmpty { return max(a.count, b.count) }
        var prev = Array(0 ... b.count)
        for i in 1 ... a.count {
            var cur = [i]
            var rowMin = i
            for j in 1 ... b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost))
                rowMin = min(rowMin, cur[j])
            }
            if rowMin > limit { return limit + 1 }
            prev = cur
        }
        return prev[b.count]
    }
}
