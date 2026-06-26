import Foundation
import Combine

struct FoundWord: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let points: Int
}

/// The playable Word Hunt round. UI-facing state is published; the rules live
/// here and depend only on Foundation/Combine (no UIKit/Messages), so the model
/// stays portable when the concept changes.
final class WordHuntGame: ObservableObject {
    static let roundSeconds = 80

    @Published private(set) var board: GameBoard
    @Published private(set) var path: [Int] = []          // selected cell indices
    @Published private(set) var foundWords: [FoundWord] = []
    @Published private(set) var score: Int = 0
    @Published private(set) var timeRemaining: Int = roundSeconds
    @Published private(set) var isOver: Bool = false
    /// Briefly set to the word just scored, for a "+points" flourish.
    @Published private(set) var lastScored: FoundWord?

    private let dictionary: WordDictionary
    private var timer: AnyCancellable?
    private var foundSet: Set<String> = []

    init(board: GameBoard = .random(), dictionary: WordDictionary = .shared) {
        self.board = board
        self.dictionary = dictionary
    }

    // MARK: - Derived

    var currentWord: String {
        path.map { board.tiles[$0].letter }.joined()
    }

    var isCurrentWordValid: Bool {
        let w = currentWord
        return w.count >= 3 && dictionary.contains(w) && !foundSet.contains(w)
    }

    var isCurrentWordDuplicate: Bool {
        let w = currentWord
        return w.count >= 3 && dictionary.contains(w) && foundSet.contains(w)
    }

    // MARK: - Lifecycle

    func start(board: GameBoard) {
        self.board = board
        path = []
        foundWords = []
        foundSet = []
        score = 0
        timeRemaining = Self.roundSeconds
        isOver = false
        lastScored = nil
        startTimer()
    }

    func startNewRandom() {
        start(board: .random())
    }

    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard !isOver else { return }
        timeRemaining -= 1
        if timeRemaining <= 0 {
            timeRemaining = 0
            endRound()
        }
    }

    func endRound() {
        isOver = true
        path = []
        timer?.cancel()
        timer = nil
    }

    // MARK: - Selection

    func beginSelection(at index: Int) {
        guard !isOver, board.tiles.indices.contains(index) else { return }
        path = [index]
    }

    func extendSelection(to index: Int) {
        guard !isOver, board.tiles.indices.contains(index) else { return }
        guard let last = path.last else {
            path = [index]
            return
        }
        // Backtrack: dragging onto the second-to-last tile pops the last.
        if path.count >= 2, index == path[path.count - 2] {
            path.removeLast()
            return
        }
        if index == last || path.contains(index) { return }
        if !GameBoard.adjacent(last, index) { return }
        path.append(index)
    }

    /// Validate and (if new) score the current word, then clear the path.
    func endSelection() {
        defer { path = [] }
        guard !isOver else { return }
        let word = currentWord
        guard word.count >= 3, dictionary.contains(word), !foundSet.contains(word) else { return }
        let points = Scoring.points(forLength: word.count)
        let found = FoundWord(word: word, points: points)
        foundSet.insert(word)
        foundWords.insert(found, at: 0)
        score += points
        lastScored = found
    }

    deinit {
        timer?.cancel()
    }
}
