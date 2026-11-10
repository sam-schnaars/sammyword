import SwiftUI

/// "Match the flag to its country" — the SwiftUI port of the web app's
/// `FlagMatch.jsx`. Plays solo or against a friend's challenge (same seeded
/// questions + their score).
struct FlagMatchView: View {
    let challenge: FlagPayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    @StateObject private var game = FlagMatchGame()
    enum Phase { case intro, playing, over }
    @State private var phase: Phase = .intro
    @State private var name = DailyStore.playerName
    @State private var sent = false
    @State private var didAutoStage = false
    @State private var nameEdited = false
    @State private var collapseTask: DispatchWorkItem?

    var body: some View {
        Group {
            switch phase {
            case .intro: intro
            case .playing: playing
            case .over: over
            }
        }
        .onChange(of: game.isOver) { over in if over { phase = .over } }
    }

    // MARK: Intro

    private var intro: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button(action: onHome) {
                        Text("← Modes").font(Theme.rounded(15, .semibold)).foregroundColor(Theme.dimText)
                    }
                    Spacer()
                }
                if let c = challenge {
                    Text("\(c.challengerName ?? "A friend") challenged you!")
                        .font(Theme.rounded(26, .heavy)).foregroundColor(Theme.headerText)
                        .multilineTextAlignment(.center)
                    Text("They scored \(String(format: "%04d", c.challengerScore ?? 0)) on Flag Match. Match each flag to its country — can you beat it?")
                        .font(Theme.rounded(15, .medium)).foregroundColor(Theme.mutedText)
                        .multilineTextAlignment(.center)
                    primaryButton("Play This Round") { start(seed: c.seed) }
                } else {
                    Text("🚩 Flag Match")
                        .font(Theme.rounded(30, .heavy)).foregroundColor(Theme.headerText)
                    Text("Match each flag to its country before the timer runs out.\n+\(Flags.pointsPerCorrect) for each correct answer.")
                        .font(Theme.rounded(15, .medium)).foregroundColor(Theme.mutedText)
                        .multilineTextAlignment(.center)
                    primaryButton("Play") { start(seed: nil) }
                }
            }
            .padding(20)
        }
    }

    // MARK: Playing

    @ViewBuilder private var playing: some View {
        if let q = game.current {
            VStack(spacing: 16) {
                HStack {
                    Button(action: onHome) {
                        Text("← Modes").font(Theme.rounded(14, .semibold)).foregroundColor(Theme.dimText)
                    }
                    Spacer()
                    Text("SCORE \(String(format: "%04d", game.score))")
                        .font(Theme.rounded(15, .bold)).foregroundColor(Theme.headerText)
                    Spacer()
                    Text(timeString(game.timeRemaining))
                        .font(Theme.rounded(15, .bold))
                        .foregroundColor(game.timeRemaining <= 10 ? Theme.lowText : Theme.headerText)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(game.timeRemaining <= 10 ? Theme.lowBg : Theme.panel, in: Capsule())
                }

                Text("FLAG \(game.index + 1) / \(game.quiz.count)")
                    .font(Theme.rounded(13, .semibold)).foregroundColor(Theme.dimText)

                Text(q.flag).font(.system(size: 110))
                Text("Tap the matching country")
                    .font(Theme.rounded(14, .medium)).foregroundColor(Theme.mutedText)

                VStack(spacing: 10) {
                    ForEach(q.options.indices, id: \.self) { i in
                        choiceButton(q: q, i: i)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func choiceButton(q: FlagQuestion, i: Int) -> some View {
        let revealed = game.picked != nil
        let isAnswer = i == q.answer
        let isPicked = i == game.picked
        let bg: Color = !revealed ? Theme.panel : (isAnswer ? Theme.positiveBg : (isPicked ? Theme.lowBg : Theme.panel))
        let border: Color = !revealed ? Theme.panelBorder : (isAnswer ? Theme.positiveBorder : (isPicked ? Theme.lowBorder : Theme.panelBorder))
        let fg: Color = !revealed ? Theme.headerText : (isAnswer ? Theme.positive : (isPicked ? Theme.lowText : Theme.mutedText))
        return Button { game.choose(i) } label: {
            Text(q.options[i])
                .font(Theme.rounded(17, .bold)).foregroundColor(fg)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(border, lineWidth: 1.5))
        }
        .disabled(revealed)
    }

    // MARK: Over

    private var over: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let c = challenge {
                    let theirScore = c.challengerScore ?? 0
                    OutcomeBanner(kind: .of(my: game.score, their: theirScore)).padding(.top, 8)
                    HStack(spacing: 14) {
                        scoreColumn(name: "You", score: game.score, winner: game.score >= theirScore)
                        Text("vs").font(Theme.rounded(15, .semibold)).foregroundColor(Theme.dimText)
                        scoreColumn(name: c.challengerName ?? "Friend", score: theirScore, winner: theirScore > game.score)
                    }
                } else {
                    Text("Time!").font(Theme.rounded(32, .heavy)).foregroundColor(Theme.headerText).padding(.top, 10)
                    Text(String(format: "%04d", game.score)).font(Theme.rounded(60, .heavy)).foregroundColor(Theme.headerText)
                }
                Text("\(game.correct) of \(game.quiz.count) correct")
                    .font(Theme.rounded(15, .medium)).foregroundColor(Theme.mutedText)

                NameField(name: $name)
                    .onChange(of: name) { _ in
                        // Personalizing the challenge cancels the auto-collapse
                        // and brings the button back so they can re-stage by name.
                        guard challenge == nil else { return }
                        nameEdited = true
                        collapseTask?.cancel()
                    }
                if challenge != nil || nameEdited {
                    primaryButton(sent ? "Sent! ✓" : (challenge != nil ? "Send result & rematch" : "Challenge a friend")) {
                        if !sent { send() }
                    }
                    .opacity(sent ? 0.6 : 1)
                }

                Button { start(seed: nil) } label: {
                    Text("Play again").font(Theme.rounded(16, .semibold)).foregroundColor(Theme.mutedText).underline()
                }
                Button(action: onHome) {
                    Text("Back to modes").font(Theme.rounded(15, .semibold)).foregroundColor(Theme.dimText)
                }
            }
            .padding(20)
        }
        .onAppear(perform: autoStageIfFirstTurn)
    }

    /// Opening turn (not replying to a challenge): stage the result into the
    /// Messages input the moment the game ends, then briefly show the score and
    /// auto-collapse to the compact bar — dropping the player at the staged
    /// message + send arrow, GamePigeon-style. (iOS gives no API to actually
    /// send; the user always taps that final arrow.) Editing the name cancels
    /// the collapse so they can personalize and re-stage.
    private func autoStageIfFirstTurn() {
        guard challenge == nil, !didAutoStage else { return }
        didAutoStage = true
        send(collapse: false, markSent: false)

        let task = DispatchWorkItem { session.requestCollapse() }
        collapseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: task)
    }

    private func scoreColumn(name: String, score: Int, winner: Bool) -> some View {
        VStack(spacing: 2) {
            Text(name).font(Theme.rounded(14, .semibold)).foregroundColor(Theme.dimText).lineLimit(1)
            Text(String(format: "%04d", score)).font(Theme.rounded(30, .heavy)).foregroundColor(Theme.headerText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(winner ? Theme.validBubbleBg : Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(winner ? Theme.validBubbleBorder : Theme.panelBorder, lineWidth: winner ? 2 : 1)
        )
    }

    // MARK: Helpers

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.rounded(20, .bold)).foregroundColor(.white)
                .padding(.vertical, 14).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.accentDark).offset(y: 5))
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 24)
    }

    private func start(seed: Int?) {
        sent = false
        didAutoStage = false
        nameEdited = false
        collapseTask?.cancel()
        game.start(seed: seed ?? Flags.randomSeed())
        phase = .playing
    }

    private func send(collapse: Bool = true, markSent: Bool = true) {
        let finalName = name.trimmingCharacters(in: .whitespaces)
        DailyStore.playerName = finalName
        let payload = FlagPayload(
            seed: game.seed,
            challengerScore: game.score,
            challengerName: finalName.isEmpty ? "Me" : finalName
        )
        session.send(.flagMatch(payload), "Flag Match — beat my \(game.score)?", collapse)
        if markSent { sent = true }
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
