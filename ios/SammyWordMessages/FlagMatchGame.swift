import Foundation
import Combine

/// A timed "match the flag to its country" round — the Swift port of the web
/// app's `FlagMatch.jsx` logic. UI-facing state is published; rules stay free of
/// UIKit/Messages so the model is portable.
final class FlagMatchGame: ObservableObject {
    @Published private(set) var quiz: [FlagQuestion] = []
    @Published private(set) var index = 0
    @Published private(set) var score = 0
    @Published private(set) var correct = 0
    /// The chosen option for the current question, or nil if unanswered.
    @Published private(set) var picked: Int?
    @Published private(set) var timeRemaining = Flags.roundSeconds
    @Published private(set) var isOver = false

    private(set) var seed = 0

    private var timer: AnyCancellable?
    private var advanceWork: DispatchWorkItem?

    var current: FlagQuestion? { index < quiz.count ? quiz[index] : nil }

    func start(seed: Int) {
        self.seed = seed
        quiz = Flags.buildQuiz(seed: seed)
        index = 0
        score = 0
        correct = 0
        picked = nil
        timeRemaining = Flags.roundSeconds
        isOver = false
        startTimer()
    }

    /// Answer the current question, then advance after a brief reveal.
    func choose(_ option: Int) {
        guard picked == nil, !isOver, let q = current else { return }
        picked = option
        if option == q.answer {
            score += Flags.pointsPerCorrect
            correct += 1
        }
        let work = DispatchWorkItem { [weak self] in self?.advance() }
        advanceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    private func advance() {
        if index + 1 >= quiz.count {
            endRound()
        } else {
            index += 1
            picked = nil
        }
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
        timer?.cancel()
        timer = nil
        advanceWork?.cancel()
    }

    deinit {
        timer?.cancel()
        advanceWork?.cancel()
    }
}
