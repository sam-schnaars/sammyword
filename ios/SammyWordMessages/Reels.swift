import Foundation

/// Scroll Recall (working name): a daily set of 8 short reels, real
/// public-domain NASA footage with a silly caption and a fact on top, then 5
/// questions about what you saw. Pure rules and data, no UI.
///
/// The sets come from `Resources/reels.json`, byte-identical to the web's
/// `src/reels.json`. The day is the Sammy Word day number, as on the web.
struct Reel: Decodable {
    let src: URL
    let start: Double
    let caption: String
    let fact: String
    let credit: String
}

struct ReelQuestion {
    let q: String
    let options: [String]
    let answer: Int
}

enum Reels {
    private struct Bank: Decodable {
        let seconds: Double
        let sets: [ReelSet]
    }

    struct ReelSet: Decodable {
        let title: String
        let reels: [Reel]
        fileprivate let quiz: [RawQuestion]
    }

    fileprivate struct RawQuestion: Decodable {
        let q: String
        let options: [String]
        let answer: Int
    }

    private static let bank: Bank = {
        guard let url = Bundle.main.url(forResource: "reels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bank = try? JSONDecoder().decode(Bank.self, from: data)
        else { return Bank(seconds: 8, sets: []) }
        return bank
    }()

    static var seconds: Double { bank.seconds }

    static func set(day: Int) -> ReelSet? {
        let n = bank.sets.count
        guard n > 0 else { return nil }
        return bank.sets[((day - 1) % n + n) % n]
    }

    /// The day's questions with choices shuffled (the bank lists the right
    /// answer first). Same seed and steps as `quizFor` in `src/reels.js`.
    static func quiz(day: Int) -> [ReelQuestion] {
        guard let set = set(day: day) else { return [] }
        var rng = SeededRNG(seed: hashStr("reels-\(day)"))
        return set.quiz.map { item in
            var order = Array(item.options.indices)
            var i = order.count - 1
            while i > 0 {
                let j = rng.int(i + 1)
                order.swapAt(i, j)
                i -= 1
            }
            return ReelQuestion(q: item.q, options: order.map { item.options[$0] },
                                answer: order.firstIndex(of: item.answer) ?? 0)
        }
    }
}
