import SwiftUI

/// Flag Match: today's 5 flags, one minute, four countries to pick from each
/// time. The quiz comes from the day, so everyone gets the same flags and a
/// friend's bubble is a score to beat on the same quiz.
struct FlagMatchView: View {
    let incoming: ScorePayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    @StateObject private var game = FlagMatchGame()
    enum Phase { case intro, playing, over }
    @State private var phase: Phase = .intro
    @State private var practice = false
    @State private var status: SendStatus = .idle

    private var playedToday: String? { DailyStore.played(.flagMatch) }

    /// Same seed for everyone on the same (UTC) day.
    static func dailySeed(_ date: Date = Date()) -> Int {
        Int(hashStr("flags-" + BoardGenerator.dailyKey(date)))
    }

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(game: .flagMatch, onHome: onHome) {
                if phase == .playing {
                    PixelStat(label: "TIME", value: clockText(game.timeRemaining), warn: game.timeRemaining <= 10)
                }
            }
            switch phase {
            case .intro: intro
            case .playing: playing
            case .over: over
            }
        }
        .onChange(of: game.isOver) { if $0 && phase == .playing { finish() } }
    }

    // MARK: Intro

    private var intro: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let friend = incoming { FriendBanner(friend: friend) }
                VStack(spacing: 14) {
                    PixelSprite(art: Game.flagMatch.sprite, scale: 6)
                    PixelText("DAY \(Daily.number())", scale: 3)
                    Text("\(Flags.questions) flags, \(Flags.roundSeconds) seconds. Tap the country each flag belongs to.")
                        .font(Pixel.mono(13))
                        .foregroundColor(Pixel.muted)
                        .multilineTextAlignment(.center)
                    if let done = playedToday {
                        PixelText("✓ TODAY: \(done)", scale: 2, color: Pixel.green)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .pixelBox(Pixel.panel, step: 4)

                if playedToday != nil {
                    PixelActionButton(title: "▶ PRACTICE") { start(practice: true) }
                } else {
                    PixelActionButton(title: "▶ START") { start(practice: false) }
                }
            }
            .padding(18)
        }
    }

    // MARK: Playing

    @ViewBuilder private var playing: some View {
        if let q = game.current {
            VStack(spacing: 14) {
                HStack {
                    PixelText("FLAG \(game.index + 1)/\(game.quiz.count)", scale: 2, color: Pixel.muted, shadow: nil)
                    Spacer()
                    PixelText("✓ \(game.correct)", scale: 2, color: Pixel.green)
                }
                Text(q.flag)
                    .font(.system(size: 120))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .pixelBox(Pixel.panel, step: 4)
                VStack(spacing: 10) {
                    ForEach(q.options.indices, id: \.self) { i in choice(q, i) }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
    }

    private func choice(_ q: FlagQuestion, _ i: Int) -> some View {
        let revealed = game.picked != nil
        let palette: PixelPalette
        if revealed && i == q.answer {
            palette = PixelPalette(fill: 0x2E9E5B, light: 0x7BE89A, dark: 0x16603A)
        } else if revealed && i == game.picked {
            palette = PixelPalette(fill: 0xB83A44, light: 0xF07A84, dark: 0x6E1A22)
        } else {
            palette = Pixel.row
        }
        return Button { game.choose(i) } label: {
            Text(q.options[i])
                .font(Pixel.mono(16, .bold))
                .foregroundColor(Pixel.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(PixelButtonStyle(palette: palette, step: 3))
        .disabled(revealed)
    }

    // MARK: Over

    private var over: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScoreCard(title: practice ? "PRACTICE" : "TIME'S UP",
                          value: "\(game.correct)/\(game.quiz.count)",
                          detail: game.correct == game.quiz.count ? "Every flag. Impressive." : "flags named correctly")
                if let friend = incoming, let theirs = friend.score, !practice {
                    PixelText(game.correct > theirs ? "YOU BEAT \(friend.senderName ?? "THEM")!"
                              : game.correct == theirs ? "A TIE!" : "\(friend.senderName ?? "THEY") WIN THIS ONE",
                              scale: 2, color: game.correct >= theirs ? Pixel.green : Pixel.gold)
                }
                NameField()
                SendButton(title: "SEND TO CHAT", payload: payload, session: session, status: $status)
                PixelActionButton(title: "PRACTICE", palette: Pixel.row, scale: 2) { start(practice: true) }
            }
            .padding(18)
        }
    }

    private var payload: ScorePayload {
        ScorePayload(game: .flagMatch, score: game.correct, day: practice ? nil : Daily.number())
    }

    // MARK: Flow

    private func start(practice: Bool) {
        self.practice = practice
        status = .idle
        game.start(seed: practice ? Flags.randomSeed() : Self.dailySeed())
        phase = .playing
    }

    private func finish() {
        phase = .over
        guard !practice else { return }
        DailyStore.record(payload)
        Delivery.send(payload, session: session, status: $status)
    }
}
