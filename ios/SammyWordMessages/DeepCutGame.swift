import Foundation
import Combine

/// A "Deep Cut" round — the Swift port of the web app's `DeepCut.jsx` logic.
/// Type an answer per prompt before its timer runs out; an answer not on the
/// list can be retried, a valid one locks in. UI-facing state is published;
/// rules stay free of UIKit/Messages.
final class DeepCutGame: ObservableObject {
    @Published private(set) var round: [Int] = []
    @Published private(set) var index = 0
    @Published private(set) var results: [DeepResult] = []
    /// The just-locked-in result, shown briefly before advancing.
    @Published private(set) var reveal: DeepResult?
    /// Bumps on each off-list guess (drives the "not on the list" shake).
    @Published private(set) var misses = 0
    @Published private(set) var timeRemaining = DeepCut.secondsPerPrompt
    @Published private(set) var isOver = false

    private(set) var seed = 0
    private var timer: AnyCancellable?
    private var advanceWork: DispatchWorkItem?

    var score: Int { results.reduce(0) { $0 + $1.points } }
    var currentPrompt: Int? { index < round.count ? round[index] : nil }

    func start(seed: Int) {
        self.seed = seed
        round = DeepCut.buildRound(seed: seed)
        index = 0
        results = []
        reveal = nil
        misses = 0
        timeRemaining = DeepCut.secondsPerPrompt
        isOver = false
        startTimer()
    }

    /// Submit a guess. Returns false if it isn't on the list (try again).
    @discardableResult
    func submit(_ guess: String) -> Bool {
        guard reveal == nil, !isOver, let p = currentPrompt else { return false }
        let result = DeepCut.score(prompt: p, guess: guess)
        guard result.tier > 0 else {
            misses += 1
            return false
        }
        lockIn(result)
        return true
    }

    private func lockIn(_ result: DeepResult) {
        timer?.cancel()
        reveal = result
        results.append(result)
        let work = DispatchWorkItem { [weak self] in self?.advance() }
        advanceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }

    private func advance() {
        reveal = nil
        misses = 0
        if index + 1 >= round.count {
            endRound()
        } else {
            index += 1
            timeRemaining = DeepCut.secondsPerPrompt
            startTimer()
        }
    }

    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard !isOver, reveal == nil else { return }
        timeRemaining -= 1
        if timeRemaining <= 0 {
            timeRemaining = 0
            lockIn(DeepResult(answer: "", tier: 0))
        }
    }

    func endRound() {
        isOver = true
        timer?.cancel()
        timer = nil
        advanceWork?.cancel()
    }

    deinit {
        timer?.cancel()
        advanceWork?.cancel()
    }
}
