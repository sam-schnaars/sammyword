import SwiftUI

/// "Deep Cut" — the SwiftUI port of the web app's `DeepCut.jsx`. Type an answer
/// to each prompt; rarer correct answers score more. Plays solo or against a
/// friend's challenge (same seeded prompts + their answers and score).
struct DeepCutView: View {
    let challenge: DeepCutPayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    @StateObject private var game = DeepCutGame()
    enum Phase { case intro, playing, over }
    @State private var phase: Phase = .intro
    @State private var guess = ""
    @FocusState private var inputFocused: Bool
    @State private var shake: CGFloat = 0
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
                    Text("They scored \(String(format: "%04d", c.challengerScore ?? 0)) on Deep Cut. Same prompts — can you dig up rarer answers?")
                        .font(Theme.rounded(15, .medium)).foregroundColor(Theme.mutedText)
                        .multilineTextAlignment(.center)
                    primaryButton("Play This Round") { start(seed: c.seed) }
                } else {
                    Text("💎 Deep Cut")
                        .font(Theme.rounded(30, .heavy)).foregroundColor(Theme.headerText)
                    Text("\(DeepCut.promptsPerRound) prompts, \(DeepCut.secondsPerPrompt)s each. Any correct answer scores — but the more obscure it is, the more it's worth.")
                        .font(Theme.rounded(15, .medium)).foregroundColor(Theme.mutedText)
                        .multilineTextAlignment(.center)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(1 ... 4, id: \.self) { t in
                            DeepChip(who: nil, answer: DeepCut.tierLabels[t - 1], tier: t)
                        }
                    }
                    primaryButton("Play") { start(seed: nil) }
                }
            }
            .padding(20)
        }
    }

    // MARK: Playing

    @ViewBuilder private var playing: some View {
        if let p = game.currentPrompt {
            VStack(spacing: 14) {
                HStack {
                    Button(action: onHome) {
                        Text("← Modes").font(Theme.rounded(14, .semibold)).foregroundColor(Theme.dimText)
                    }
                    Spacer()
                    Text("SCORE \(String(format: "%04d", game.score))")
                        .font(Theme.rounded(15, .bold)).foregroundColor(Theme.headerText)
                    Spacer()
                    Text(String(format: "0:%02d", game.timeRemaining))
                        .font(Theme.rounded(15, .bold))
                        .foregroundColor(game.timeRemaining <= 5 ? Theme.lowText : Theme.headerText)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(game.timeRemaining <= 5 ? Theme.lowBg : Theme.panel, in: Capsule())
                }

                Text("PROMPT \(game.index + 1) / \(game.round.count)")
                    .font(Theme.rounded(13, .semibold)).foregroundColor(Theme.dimText)

                Text(DeepCut.prompts[p].q)
                    .font(Theme.rounded(28, .heavy)).foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)

                if let r = game.reveal {
                    revealCard(r)
                } else {
                    TextField("Type an answer…", text: $guess)
                        .font(Theme.rounded(20, .semibold)).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($inputFocused)
                        .onSubmit(submit)
                        .onChange(of: guess) { g in
                            let clean = String(g.replacingOccurrences(of: "|", with: "").prefix(40))
                            if clean != g { guess = clean }
                        }
                        .padding(.vertical, 14).padding(.horizontal, 16)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(game.misses > 0 ? Theme.lowBorder : Theme.panelBorder, lineWidth: 2)
                        )
                        .modifier(Shake(amount: shake))

                    primaryButton("Lock it in", action: submit)
                        .disabled(guess.trimmingCharacters(in: .whitespaces).isEmpty)

                    if game.misses > 0 {
                        Text("Not on the list — try another")
                            .font(Theme.rounded(14, .semibold)).foregroundColor(Theme.lowText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .onAppear { inputFocused = true }
            .onChange(of: game.index) { _ in inputFocused = true }
        }
    }

    private func revealCard(_ r: DeepResult) -> some View {
        VStack(spacing: 6) {
            if r.tier > 0 {
                Text(r.answer).font(Theme.rounded(26, .bold)).foregroundColor(.white)
                Text("\(DeepCut.tierLabels[r.tier - 1].uppercased()) +\(r.points)")
                    .font(Theme.rounded(16, .bold)).foregroundColor(DeepTier.color(r.tier))
            } else {
                Text("TIME'S UP — 0").font(Theme.rounded(16, .bold)).foregroundColor(DeepTier.color(0))
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(DeepTier.color(r.tier), lineWidth: 2)
        )
        .shadow(color: r.tier == 4 ? DeepTier.color(4).opacity(0.6) : .clear, radius: 14)
        .transition(.scale.combined(with: .opacity))
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
                    Text("Done!").font(Theme.rounded(32, .heavy)).foregroundColor(Theme.headerText).padding(.top, 10)
                    Text(String(format: "%04d", game.score)).font(Theme.rounded(60, .heavy)).foregroundColor(Theme.headerText)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(game.round.enumerated()), id: \.offset) { i, p in
                        recapRow(i: i, prompt: p)
                    }
                }

                NameField(name: $name)
                    .onChange(of: name) { _ in
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

    private func recapRow(i: Int, prompt p: Int) -> some View {
        let mine = i < game.results.count ? game.results[i] : DeepResult(answer: "", tier: 0)
        let their = challenge.map { c in DeepCut.score(prompt: p, guess: i < c.challengerAnswers.count ? c.challengerAnswers[i] : "") }
        let cuts = DeepCut.deepCuts(prompt: p)
        return VStack(alignment: .leading, spacing: 6) {
            Text(DeepCut.prompts[p].q).font(Theme.rounded(14, .bold)).foregroundColor(Theme.headerText)
            DeepChip(who: challenge == nil ? nil : "You", answer: mine.answer, tier: mine.tier)
            if let t = their {
                DeepChip(who: challenge?.challengerName ?? "Friend", answer: t.answer, tier: t.tier)
            }
            Text("Deep cuts: \(cuts.isEmpty ? "—" : cuts.joined(separator: ", "))")
                .font(Theme.rounded(12, .medium)).foregroundColor(Theme.dimText)
        }
    }

    /// Opening turn: stage the result into the Messages input, then briefly show
    /// the score and auto-collapse (same flow as Flag Match / Word Hunt).
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

    private func submit() {
        guard !guess.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if game.submit(guess) {
            Haptics.wordScored(length: 3 + game.results.last!.tier)
        } else {
            withAnimation(.linear(duration: 0.3)) { shake += 1 }
            inputFocused = true
        }
        guess = ""
    }

    private func start(seed: Int?) {
        sent = false
        didAutoStage = false
        nameEdited = false
        guess = ""
        collapseTask?.cancel()
        game.start(seed: seed ?? DeepCut.randomSeed())
        phase = .playing
    }

    private func send(collapse: Bool = true, markSent: Bool = true) {
        let finalName = name.trimmingCharacters(in: .whitespaces)
        DailyStore.playerName = finalName
        let payload = DeepCutPayload(
            seed: game.seed,
            challengerScore: game.score,
            challengerName: finalName.isEmpty ? "Me" : finalName,
            challengerAnswers: game.results.map(\.answer)
        )
        session.send(.deepCut(payload), "Deep Cut — beat my \(game.score)?", collapse)
        if markSent { sent = true }
    }
}

/// Rarity tier colors: 0 = miss, 1 common → 4 deep cut.
enum DeepTier {
    static func color(_ tier: Int) -> Color {
        switch tier {
        case 1: return Color(hex: 0xB8B0C8)
        case 2: return Theme.positive
        case 3: return Theme.lowText
        case 4: return Color(hex: 0xFFD23F)
        default: return Color(hex: 0x6A6080)
        }
    }
}

/// One answer pill: optional player name, the answer, and its points.
struct DeepChip: View {
    let who: String?
    let answer: String
    let tier: Int

    var body: some View {
        HStack(spacing: 8) {
            if let who {
                Text(who).font(Theme.rounded(12, .semibold)).foregroundColor(Theme.dimText)
                    .lineLimit(1).frame(maxWidth: 90, alignment: .leading)
            }
            Text(answer.isEmpty ? "—" : answer).font(Theme.rounded(14, .semibold)).foregroundColor(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("+\(DeepCut.points(tier: tier))").font(Theme.rounded(14, .bold)).foregroundColor(DeepTier.color(tier))
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(DeepTier.color(tier), lineWidth: 1.5)
        )
    }
}

/// Horizontal shake for an off-list guess.
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 3), y: 0))
    }
}
