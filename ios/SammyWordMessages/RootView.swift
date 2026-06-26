import SwiftUI

/// SwiftUI entry point. Switches on the extension's presentation style. Talks
/// only to `GameSession` — no Messages/UIKit here.
struct RootView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch session.presentation {
            case .compact:
                CompactView(session: session)
            case .expanded:
                ExpandedView(session: session)
            }
        }
    }
}

/// The small bar shown above the keyboard — a single "tap to play" affordance.
struct CompactView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        Button { session.requestExpand() } label: {
            VStack(spacing: 4) {
                Text("Sammy Word")
                    .font(Theme.rounded(26, .heavy))
                Text(subtitle)
                    .font(Theme.rounded(15, .medium))
                    .opacity(0.9)
            }
            .foregroundColor(Theme.onBackground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        if let payload = session.incoming, payload.isChallenge {
            let who = payload.challengerName ?? "A friend"
            return "\(who) challenged you — tap to play"
        }
        return "Tap to play"
    }
}

/// The expanded sheet: plays a round, then shows results + send actions.
struct ExpandedView: View {
    @ObservedObject var session: GameSession
    @StateObject private var game = WordHuntGame()
    @State private var started = false

    var body: some View {
        Group {
            if game.isOver {
                GameOverView(game: game, session: session)
            } else {
                GameView(game: game)
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            let board = session.incoming?.board ?? GameBoard.random()
            game.start(board: board)
        }
    }
}

/// Final score, optional head-to-head comparison, and the share/challenge button.
struct GameOverView: View {
    @ObservedObject var game: WordHuntGame
    @ObservedObject var session: GameSession
    @State private var sent = false

    private var incoming: GamePayload? { session.incoming }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(headline)
                    .font(Theme.rounded(34, .heavy))
                    .foregroundColor(Theme.onBackground)
                    .padding(.top, 12)

                if let challenge = incoming, challenge.isChallenge {
                    versus(myScore: game.score, theirScore: challenge.challengerScore ?? 0,
                           theirName: challenge.challengerName ?? "Them")
                } else {
                    Text(String(format: "%04d", game.score))
                        .font(Theme.rounded(64, .heavy))
                        .foregroundColor(Theme.onBackground)
                    Text("\(game.foundWords.count) word\(game.foundWords.count == 1 ? "" : "s") found")
                        .font(Theme.rounded(16, .medium))
                        .foregroundColor(Theme.onBackground.opacity(0.9))
                }

                Button(action: send) {
                    Text(sent ? "Sent! ✓" : sendLabel)
                        .font(Theme.rounded(20, .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(sent)
                .padding(.horizontal, 24)

                foundList
            }
            .padding(20)
        }
    }

    private var headline: String {
        guard let challenge = incoming, challenge.isChallenge else { return "Time!" }
        let theirs = challenge.challengerScore ?? 0
        if game.score > theirs { return "You win! 🎉" }
        if game.score < theirs { return "You lost" }
        return "It's a tie!"
    }

    private var sendLabel: String {
        if let challenge = incoming, challenge.isChallenge {
            return "Send result & rematch"
        }
        return "Challenge a friend"
    }

    private func versus(myScore: Int, theirScore: Int, theirName: String) -> some View {
        HStack(spacing: 14) {
            scoreColumn(name: "You", score: myScore, winner: myScore >= theirScore)
            Text("vs").font(Theme.rounded(15, .semibold)).foregroundColor(Theme.onBackground.opacity(0.8))
            scoreColumn(name: theirName, score: theirScore, winner: theirScore > myScore)
        }
    }

    private func scoreColumn(name: String, score: Int, winner: Bool) -> some View {
        VStack(spacing: 2) {
            Text(name).font(Theme.rounded(14, .semibold)).lineLimit(1)
            Text(String(format: "%04d", score)).font(Theme.rounded(30, .heavy))
        }
        .foregroundColor(Theme.onBackground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            (winner ? Color.white.opacity(0.28) : Color.white.opacity(0.12)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var foundList: some View {
        let sorted = game.foundWords.sorted {
            $0.points != $1.points ? $0.points > $1.points : $0.word < $1.word
        }
        return VStack(alignment: .leading, spacing: 8) {
            if !sorted.isEmpty {
                Text("WORDS")
                    .font(Theme.rounded(12, .semibold))
                    .foregroundColor(Theme.onBackground.opacity(0.85))
            }
            FlowChips(words: sorted)
        }
        .padding(.horizontal, 8)
    }

    private func send() {
        // Same board, my score becomes the score to beat.
        let payload = GamePayload(
            letters: game.board.letters,
            challengerScore: game.score,
            challengerName: "Me"
        )
        let caption = "Sammy Word — beat my \(game.score)?"
        session.sendResult(payload, caption)
        sent = true
    }
}

/// Simple wrap layout for the found-word chips.
struct FlowChips: View {
    let words: [FoundWord]

    var body: some View {
        // A lightweight wrapping grid that works on iOS 16.
        let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(words) { fw in
                HStack(spacing: 5) {
                    Text(fw.word == "QU" ? "Qu" : fw.word.replacingOccurrences(of: "QU", with: "Qu"))
                        .font(Theme.rounded(14, .bold))
                    Text("\(fw.points)")
                        .font(Theme.rounded(11, .semibold))
                        .opacity(0.55)
                }
                .foregroundColor(Theme.letter)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.tile, in: Capsule())
            }
        }
    }
}
