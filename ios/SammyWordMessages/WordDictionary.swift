import Foundation

/// Loads `words.txt` from the bundle into a sorted array (deduped, uppercased).
/// The sorted array doubles as a prefix index for the board solver: one binary
/// search answers both "is this a word?" and "is this a live prefix?" — the same
/// pruning the web app gets from its trie, without a trie's memory overhead.
///
/// Loading is lazy and thread-safe so the heavy work can run off the main thread
/// (see `BoardGenerator`), then gameplay lookups read the result for free.
final class WordDictionary {
    static let shared = WordDictionary()

    private(set) var sortedWords: [String] = []
    private var loaded = false
    private let lock = NSLock()

    private init() {}

    var isLoaded: Bool {
        lock.lock(); defer { lock.unlock() }
        return loaded
    }

    /// Parses the bundled list once. Safe to call from any thread / repeatedly.
    func loadIfNeeded() {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return }
        loaded = true
        guard let url = Bundle.main.url(forResource: "words", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        var set = Set<String>(minimumCapacity: 400_000)
        for line in text.split(whereSeparator: \.isNewline) {
            let w = line.trimmingCharacters(in: .whitespaces).uppercased()
            if !w.isEmpty { set.insert(w) }
        }
        sortedWords = set.sorted()
    }

    func contains(_ word: String) -> Bool {
        match(word.uppercased()).isWord
    }

    /// Single binary search: `isWord` if `s` is in the list, `isPrefix` if any
    /// word starts with `s` (which is also true when `s` is itself a word).
    func match(_ s: String) -> (isPrefix: Bool, isWord: Bool) {
        loadIfNeeded()
        let arr = sortedWords
        var lo = 0, hi = arr.count
        while lo < hi {
            let mid = (lo + hi) >> 1
            if arr[mid] < s { lo = mid + 1 } else { hi = mid }
        }
        guard lo < arr.count else { return (false, false) }
        let candidate = arr[lo]
        if candidate == s { return (true, true) }
        return (candidate.hasPrefix(s), false)
    }
}
