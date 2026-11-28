import SwiftUI

/// Word Hunt: today's 4×4 letter grid, 30 seconds, drag across neighbors to
/// spell words. Everyone gets the same board each day, so a friend's bubble is
/// a score to beat on the very same letters. After the daily round you can
/// keep practicing on random boards.
struct WordHuntView: View {
    let incoming: ScorePayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    @StateObject private var game = WordHuntGame()
    enum Phase { case intro, playing, over }
    @State private var phase: Phase = .intro
    @State private var board: GameBoard?
    @State private var practice = false
    @State private var status: SendStatus = .idle
    @State private var flourish: FoundWord?

    private var playedToday: String? { DailyStore.played(.wordHunt) }

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(game: .wordHunt, onHome: onHome) {
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
        .onAppear(perform: prepare)
        .onChange(of: game.isOver) { if $0 && phase == .playing { finish() } }
        .onChange(of: game.lastScored) { scored in
            guard let scored else { return }
            Haptics.wordScored(length: scored.word.count)
            flourish = scored
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                if flourish?.id == scored.id { flourish = nil }
            }
        }
    }

    // MARK: Intro

    private var intro: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let friend = incoming { FriendBanner(friend: friend) }
                VStack(spacing: 14) {
                    PixelSprite(art: Game.wordHunt.sprite, scale: 6)
                    PixelText(practice ? "PRACTICE BOARD" : "DAY \(Daily.number())", scale: 3)
                    Text("Drag across touching letters to spell words of 3 or more. Longer words score far more. You have 30 seconds.")
                        .font(Pixel.mono(13))
                        .foregroundColor(Pixel.muted)
                        .multilineTextAlignment(.center)
                    if let done = playedToday, !practice {
                        PixelText("✓ TODAY: \(done)", scale: 2, color: Pixel.green)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .pixelBox(Pixel.panel, step: 4)

                if board == nil {
                    PixelText("SHUFFLING LETTERS...", scale: 2, color: Pixel.muted)
                    ProgressView().tint(Pixel.cream)
                } else if playedToday != nil && !practice {
                    PixelActionButton(title: "▶ PRACTICE") { startPractice() }
                } else {
                    PixelActionButton(title: "▶ START") { start() }
                }
            }
            .padding(18)
        }
    }

    // MARK: Playing

    private var playing: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                PixelStat(label: "SCORE", value: String(game.score))
                PixelStat(label: "WORDS", value: String(game.foundWords.count))
                Spacer(minLength: 0)
            }
            goals
            readout
            WordBoard(game: game)
                .padding(.horizontal, 4)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    /// How many words of each length the board holds, and how many you've found.
    @ViewBuilder private var goals: some View {
        let lengths = game.possibleByLength.keys.filter { $0 > 3 }.sorted()
        if !lengths.isEmpty {
            HStack(spacing: 6) {
                ForEach(lengths, id: \.self) { len in
                    let got = game.foundByLength[len] ?? 0
                    let total = game.possibleByLength[len] ?? 0
                    let done = total > 0 && got >= total
                    VStack(spacing: 3) {
                        PixelText("\(len)L", scale: 1.5, color: done ? Pixel.green : Pixel.muted, shadow: nil)
                        PixelText("\(got)/\(total)", scale: 1.5, color: done ? Pixel.green : Pixel.cream, shadow: nil)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .pixelBox(Pixel.row, step: 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The word being traced (green when it's a new word, gold if already
    /// found), or a "+points" flash just after scoring.
    private var readout: some View {
        ZStack {
            if !game.currentWord.isEmpty {
                PixelText(game.currentWord, scale: 3,
                          color: game.isCurrentWordValid ? Pixel.green
                              : game.isCurrentWordDuplicate ? Pixel.gold : Pixel.cream)
            } else if let f = flourish {
                PixelText("\(f.word) +\(f.points)", scale: 3, color: Pixel.green)
                    .transition(.opacity)
            }
        }
        .frame(height: 30)
    }

    // MARK: Over

    private var over: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScoreCard(title: practice ? "PRACTICE" : "TIME'S UP",
                          value: String(game.score),
                          detail: "\(game.foundWords.count) words found")
                if let friend = incoming, let theirs = friend.score, !practice {
                    PixelText(game.score > theirs ? "YOU BEAT \(friend.senderName ?? "THEM")!"
                              : game.score == theirs ? "A TIE!" : "\(friend.senderName ?? "THEY") WIN THIS ONE",
                              scale: 2, color: game.score >= theirs ? Pixel.green : Pixel.gold)
                }
                if !game.foundWords.isEmpty {
                    let best = game.foundWords.sorted { $0.points > $1.points }.prefix(8)
                    VStack(alignment: .leading, spacing: 8) {
                        PixelText("BEST WORDS", scale: 1.5, color: Pixel.muted, shadow: nil)
                        FlowRow(items: best.map { "\($0.word) \($0.points)" })
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pixelBox(Pixel.row, step: 2)
                }
                NameField()
                SendButton(title: "SEND TO CHAT", payload: payload, session: session, status: $status)
                PixelActionButton(title: "PRACTICE", palette: Pixel.row, scale: 2) { startPractice() }
            }
            .padding(18)
        }
    }

    private var payload: ScorePayload {
        let best = game.foundWords.sorted { $0.points > $1.points }.prefix(3).map(\.word)
        return ScorePayload(game: .wordHunt, score: game.score,
                            day: practice ? nil : Daily.number(), marks: best)
    }

    // MARK: Flow

    /// Build today's board in the background (solving it takes a moment).
    private func prepare() {
        guard board == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let b = BoardGenerator.dailyBoard(map: .classic)
            DispatchQueue.main.async { board = b }
        }
    }

    private func start() {
        guard let board else { return }
        status = .idle
        game.start(board: board)
        phase = .playing
    }

    private func startPractice() {
        practice = true
        board = nil
        phase = .intro
        DispatchQueue.global(qos: .userInitiated).async {
            let b = BoardGenerator.generate(map: .classic)
            DispatchQueue.main.async {
                board = b
                start()
            }
        }
    }

    /// The daily round is recorded and sent straight to the chat.
    private func finish() {
        phase = .over
        guard !practice else { return }
        DailyStore.record(payload)
        Delivery.send(payload, session: session, status: $status)
    }
}

/// The 4×4 board in pixel tiles, with drag-to-trace selection.
struct WordBoard: View {
    @ObservedObject var game: WordHuntGame

    var body: some View {
        let map = game.board.map
        GeometryReader { geo in
            let L = BoardLayout(size: geo.size, map: map)
            let cell = L.cell
            ZStack(alignment: .topLeading) {
                ForEach(game.board.tiles) { tile in
                    let selected = game.path.contains(tile.id)
                    PixelText(tile.letter, scale: max(3, (cell * 0.45 / 7).rounded()),
                              color: selected ? Pixel.ink : Pixel.cream,
                              shadow: selected ? nil : Pixel.ink)
                        .frame(width: cell - 6, height: cell - 6)
                        .pixelBox(selected ? PixelPalette(fill: 0x7AB8F5, light: 0xC6E2FF, dark: 0x3C6FA8)
                                           : PixelPalette(fill: 0x4A4870, light: 0x77749E, dark: 0x2A2848),
                                  step: 3, pressed: selected)
                        .position(L.center(tile.id))
                }
                Path { p in
                    for (k, i) in game.path.enumerated() {
                        if k == 0 { p.move(to: L.center(i)) } else { p.addLine(to: L.center(i)) }
                    }
                }
                .stroke(Pixel.gold.opacity(0.85), style: StrokeStyle(lineWidth: max(6, cell * 0.12), lineCap: .square, lineJoin: .miter))
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .pixelBox(Pixel.panel, step: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = value.location.x - L.origin.x, y = value.location.y - L.origin.y
                        let c = Int((x / L.step).rounded(.down)), r = Int((y / L.step).rounded(.down))
                        guard r >= 0, r < map.rows, c >= 0, c < map.cols else { return }
                        let i = r * map.cols + c
                        guard game.board.isActive(i) else { return }
                        // Only the middle of a tile counts, so diagonal drags
                        // don't clip a neighbor on the way.
                        let mid = L.center(i)
                        let dx = value.location.x - mid.x, dy = value.location.y - mid.y
                        guard dx * dx + dy * dy <= (cell * 0.45) * (cell * 0.45) else { return }
                        if game.path.isEmpty { game.beginSelection(at: i) } else { game.extendSelection(to: i) }
                    }
                    .onEnded { _ in game.endSelection() }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Where each tile sits on the board.
struct BoardLayout {
    let cell: CGFloat, step: CGFloat, origin: CGPoint, cols: Int

    init(size: CGSize, map: GameMap) {
        let gap: CGFloat = 8
        cols = map.cols
        cell = (min(size.width, size.height) - 24 - gap * CGFloat(map.cols - 1)) / CGFloat(map.cols)
        step = cell + gap
        origin = CGPoint(x: (size.width - (cell * CGFloat(map.cols) + gap * CGFloat(map.cols - 1))) / 2,
                         y: (size.height - (cell * CGFloat(map.rows) + gap * CGFloat(map.rows - 1))) / 2)
    }

    func center(_ i: Int) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(i % cols) * step + cell / 2,
                y: origin.y + CGFloat(i / cols) * step + cell / 2)
    }
}

/// Small pixel chips that wrap onto new lines.
struct FlowRow: View {
    let items: [String]

    var body: some View {
        // Two chips per row keeps long words readable at this width.
        let rows = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(rows[r], id: \.self) { item in
                        Text(item)
                            .font(Pixel.mono(13, .bold))
                            .foregroundColor(Pixel.cream)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color(hex: 0x302A62))
                    }
                }
            }
        }
    }
}
