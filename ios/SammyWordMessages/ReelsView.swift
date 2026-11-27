import SwiftUI
import AVKit

/// Scroll Recall: today's 8 reels full-screen. Each plays about 8 seconds and
/// moves on by itself unless you swipe up first; there's no going back. Then
/// 5 questions, and the score goes to the chat like the other daily games.
struct ReelsView: View {
    let incoming: ScorePayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    enum Phase { case intro, watching, quiz, over }
    @State private var phase: Phase = .intro
    @State private var index = 0
    @State private var players: [Int: AVPlayer] = [:]
    @State private var muted = true
    @State private var advanceTask: Task<Void, Never>?
    @State private var q = 0
    @State private var picked: Int?
    @State private var answers: [Bool] = []
    @State private var status: SendStatus = .idle

    private let day = Daily.number()
    private var reelSet: Reels.ReelSet? { Reels.set(day: day) }
    private var reels: [Reel] { reelSet?.reels ?? [] }
    private var quiz: [ReelQuestion] { Reels.quiz(day: day) }
    private var playedToday: String? { DailyStore.played(.reels) }
    private var correct: Int { answers.filter { $0 }.count }

    var body: some View {
        Group {
            switch phase {
            case .intro: VStack(spacing: 0) { GameHeader(game: .reels, onHome: onHome); intro }
            case .watching: watching
            case .quiz: VStack(spacing: 0) { GameHeader(game: .reels, onHome: onHome); quizView }
            case .over: VStack(spacing: 0) { GameHeader(game: .reels, onHome: onHome); over }
            }
        }
        .onDisappear { stopAll() }
    }

    // MARK: Intro

    private var intro: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let friend = incoming { FriendBanner(friend: friend) }
                VStack(spacing: 14) {
                    PixelSprite(art: Game.reels.sprite, scale: 6)
                    PixelText("DAY \(day)", scale: 3)
                    if let title = reelSet?.title { PixelText(title, scale: 2, color: Pixel.gold) }
                    Text("\(reels.count) short reels, about \(Int(Reels.seconds)) seconds each. Swipe up to skip ahead, or wait and they move on by themselves. No going back. Then \(quiz.count) questions about what you saw.")
                        .font(Pixel.mono(13))
                        .foregroundColor(Pixel.muted)
                        .multilineTextAlignment(.center)
                    if let done = playedToday {
                        PixelText("✓ TODAY: \(done)", scale: 2, color: Pixel.green)
                    }
                    Text("Footage: NASA (public domain)")
                        .font(Pixel.mono(11))
                        .foregroundColor(Pixel.muted.opacity(0.8))
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .pixelBox(Pixel.panel, step: 4)

                PixelActionButton(title: playedToday == nil ? "▶ START SCROLLING" : "▶ WATCH AGAIN") { start() }
                    .disabled(reels.isEmpty)
            }
            .padding(18)
        }
    }

    // MARK: Watching

    private var watching: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player = players[index] {
                VideoPlayer(player: player)
                    .allowsHitTesting(false)
                    .id(index)
            }
            if index < reels.count {
                let reel = reels[index]
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        ForEach(0..<reels.count, id: \.self) { i in
                            Rectangle()
                                .fill(i <= index ? Color.white : Color.white.opacity(0.25))
                                .frame(height: 4)
                        }
                    }
                    HStack {
                        Button { stopAll(); onHome() } label: {
                            Text("✕").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                                .frame(width: 38, height: 38).background(Color.black.opacity(0.5))
                        }
                        Spacer()
                        Button { muted.toggle(); players.values.forEach { $0.isMuted = muted } } label: {
                            Text(muted ? "🔇" : "🔊").font(.system(size: 18))
                                .frame(width: 38, height: 38).background(Color.black.opacity(0.5))
                        }
                    }
                    .padding(.top, 8)
                    MemeText(reel.caption.uppercased())
                        .padding(.top, 24)
                        .padding(.horizontal, 12)
                    Spacer()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reel.fact)
                            .font(Pixel.mono(15, .semibold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Video: \(reel.credit)")
                            .font(Pixel.mono(10))
                            .foregroundColor(Pixel.muted)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0x0A0818).opacity(0.85))
                    .overlay(Rectangle().stroke(Pixel.gold, lineWidth: 3))
                    PixelText("SWIPE UP ↑", scale: 1.8, color: Color.white.opacity(0.8), shadow: nil)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, 12)
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 20).onEnded { v in
            if v.translation.height < -50 { advance() }
        })
    }

    // MARK: Quiz

    @ViewBuilder private var quizView: some View {
        if q < quiz.count {
            let item = quiz[q]
            ScrollView {
                VStack(spacing: 14) {
                    PixelText("QUESTION \(q + 1)/\(quiz.count)", scale: 2, color: Pixel.muted, shadow: nil)
                    Text(item.q)
                        .font(Pixel.mono(18, .bold))
                        .foregroundColor(Pixel.cream)
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .pixelBox(Pixel.panel, step: 4)
                    ForEach(item.options.indices, id: \.self) { i in choice(item, i) }
                }
                .padding(18)
            }
        }
    }

    private func choice(_ item: ReelQuestion, _ i: Int) -> some View {
        let revealed = picked != nil
        let palette: PixelPalette
        if revealed && i == item.answer {
            palette = PixelPalette(fill: 0x2E9E5B, light: 0x7BE89A, dark: 0x16603A)
        } else if revealed && i == picked {
            palette = PixelPalette(fill: 0xB83A44, light: 0xF07A84, dark: 0x6E1A22)
        } else {
            palette = Pixel.row
        }
        return Button { pick(i, item) } label: {
            Text(item.options[i])
                .font(Pixel.mono(15, .bold))
                .foregroundColor(Pixel.cream)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
        }
        .buttonStyle(PixelButtonStyle(palette: palette, step: 3))
        .disabled(revealed)
    }

    // MARK: Over

    private var over: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScoreCard(title: "SCROLL RECALL", value: "\(correct)/\(quiz.count)",
                          detail: answers.map { $0 ? "🟩" : "🟥" }.joined())
                if let friend = incoming, let theirs = friend.score {
                    PixelText(correct > theirs ? "YOU BEAT \(friend.senderName ?? "THEM")!"
                              : correct == theirs ? "A TIE!" : "\(friend.senderName ?? "THEY") WIN THIS ONE",
                              scale: 2, color: correct >= theirs ? Pixel.green : Pixel.gold)
                }
                NameField()
                SendButton(title: "SEND TO CHAT", payload: payload, session: session, status: $status)
            }
            .padding(18)
        }
    }

    private var payload: ScorePayload {
        ScorePayload(game: .reels, score: correct, day: day, marks: answers.map { $0 ? "1" : "0" })
    }

    // MARK: Flow

    private func start() {
        answers = []
        q = 0
        picked = nil
        status = .idle
        index = 0
        phase = .watching
        prepare(0)
        prepare(1)
        play(0)
    }

    private func prepare(_ i: Int) {
        guard i < reels.count, players[i] == nil else { return }
        let reel = reels[i]
        let player = AVPlayer(url: reel.src)
        player.isMuted = muted
        player.seek(to: CMTime(seconds: reel.start, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600))
        players[i] = player
    }

    private func play(_ i: Int) {
        players[i]?.play()
        advanceTask?.cancel()
        advanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Reels.seconds * 1_000_000_000))
            if !Task.isCancelled, phase == .watching, index == i { advance() }
        }
    }

    private func advance() {
        guard phase == .watching else { return }
        players[index]?.pause()
        players[index] = nil
        if index + 1 >= reels.count {
            stopAll()
            phase = .quiz
            return
        }
        index += 1
        prepare(index)
        prepare(index + 1)
        play(index)
    }

    private func pick(_ i: Int, _ item: ReelQuestion) {
        guard picked == nil else { return }
        picked = i
        let right = i == item.answer
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            answers.append(right)
            picked = nil
            if q + 1 >= quiz.count {
                phase = .over
                DailyStore.record(payload)
                Delivery.send(payload, session: session, status: $status)
            } else {
                q += 1
            }
        }
    }

    private func stopAll() {
        advanceTask?.cancel()
        players.values.forEach { $0.pause() }
        players = [:]
    }
}
