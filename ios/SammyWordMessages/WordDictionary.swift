import Foundation

/// Loads `words.txt` from the bundle into a Set once, for O(1) validation.
/// Words are stored uppercased; lookups uppercase the query.
final class WordDictionary {
    static let shared = WordDictionary()

    private(set) var words: Set<String> = []
    var isLoaded: Bool { !words.isEmpty }

    private init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return
        }
        words = Set(
            text
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
                .filter { !$0.isEmpty }
        )
    }

    func contains(_ word: String) -> Bool {
        words.contains(word.uppercased())
    }
}
