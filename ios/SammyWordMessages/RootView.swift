import SwiftUI

/// SwiftUI entry point. Switches on the extension's presentation style. Talks
/// only to `GameSession` — no Messages/UIKit here.
struct RootView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            Theme.background
            switch session.presentation {
            case .compact:
                CompactView(session: session)
            case .expanded:
                ExpandedView(session: session)
            }
        }
    }
}

/// The small bar shown above the keyboard. On a fresh open it offers both games
/// directly; if opened from a challenge, it's a single "tap to play" affordance.
struct CompactView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        if let subtitle = challengeSubtitle {
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
        } else {
            HStack(spacing: 10) {
                gameButton(emoji: "🔤", title: "Word Hunt") { session.launch(.wordHunt) }
                gameButton(emoji: "🚩", title: "Flag Match") { session.launch(.flagMatch) }
                gameButton(emoji: "💎", title: "Deep Cut") { session.launch(.deepCut) }
                gameButton(emoji: "🦐", title: "Krillion") { session.launch(.krillion) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
        }
    }

    private func gameButton(emoji: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji).font(.system(size: 24))
                Text(title)
                    .font(Theme.rounded(16, .bold))
                    .foregroundColor(Theme.headerText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.panelBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Non-nil only when opened from a tapped challenge — then we keep the simple
    /// single-tap bar that deep-jumps into that challenge.
    private var challengeSubtitle: String? {
        switch session.incoming {
        case let .wordHunt(p) where p.isChallenge:
            return "\(p.challengerName ?? "A friend") challenged you — tap to play"
        case let .flagMatch(p) where p.isChallenge:
            return "\(p.challengerName ?? "A friend") challenged you — tap to play"
        case let .deepCut(p) where p.isChallenge:
            return "\(p.challengerName ?? "A friend") challenged you — tap to play"
        case let .krillion(p):
            return p.score == nil
                ? "\(p.senderName ?? "A friend") wants a Krillion dive — tap to play"
                : "\(p.senderName ?? "A friend") scored \(p.score ?? 0) on Krillion — tap to beat it"
        default:
            return nil
        }
    }
}

/// The expanded sheet: pick a mode, play a round, then show results + send.
struct ExpandedView: View {
    @ObservedObject var session: GameSession
    @StateObject private var game = WordHuntGame()

    enum Screen { case modePicker, wordHome, loading, wordPlaying, flagMatch, deepCut, krillion }
    @State private var screen: Screen = .modePicker
    @State private var dailyKey: String?            // non-nil while playing the daily board
    @State private var wordChallenge: GamePayload?  // incoming Word Hunt challenge, if any
    @State private var kicked = false

    var body: some View {
        Group {
            switch screen {
            case .modePicker:
                ModePicker(
                    onWordHunt: { screen = .wordHome },
                    onFlags: { wordChallenge = nil; dailyKey = nil; screen = .flagMatch },
                    onDeep: { wordChallenge = nil; dailyKey = nil; screen = .deepCut },
                    onKrillion: { wordChallenge = nil; dailyKey = nil; screen = .krillion }
                )
            case .wordHome:
                WordHuntHome(onMap: startMap, onDaily: startDaily, onBack: { screen = .modePicker })
            case .loading:
                LoadingView()
            case .wordPlaying:
                if game.isOver {
                    WordHuntOverView(
                        game: game,
                        challenge: wordChallenge,
                        dailyKey: dailyKey,
                        session: session,
                        onNewGame: { wordChallenge = nil; dailyKey = nil; screen = .wordHome }
                    )
                } else {
                    GameView(game: game)
                }
            case .flagMatch:
                FlagMatchView(
                    challenge: incomingFlagChallenge,
                    session: session,
                    onHome: { screen = .modePicker }
                )
            case .deepCut:
                DeepCutView(
                    challenge: incomingDeepChallenge,
                    session: session,
                    onHome: { screen = .modePicker }
                )
            case .krillion:
                KrillionView(
                    incoming: incomingKrillion,
                    session: session,
                    onHome: { screen = .modePicker }
                )
            }
        }
        .onAppear(perform: begin)
    }

    private var incomingFlagChallenge: FlagPayload? {
        if case let .flagMatch(p) = session.incoming, p.isChallenge { return p }
        return nil
    }

    private var incomingDeepChallenge: DeepCutPayload? {
        if case let .deepCut(p) = session.incoming, p.isChallenge { return p }
        return nil
    }

    private var incomingKrillion: KrillionPayload? {
        if case let .krillion(p) = session.incoming { return p }
        return nil
    }

    private func begin() {
        guard !kicked else { return }
        kicked = true
        // A tapped challenge deep-jumps straight into the relevant mode.
        if case let .wordHunt(p) = session.incoming, p.isChallenge {
            wordChallenge = p
            dailyKey = nil
            game.start(board: p.board)
            screen = .wordPlaying
        } else if incomingFlagChallenge != nil {
            screen = .flagMatch
        } else if incomingDeepChallenge != nil {
            screen = .deepCut
        } else if incomingKrillion != nil {
            screen = .krillion
        } else if let mode = session.launchMode {
            // Opened fresh and the player picked a game from the compact bar.
            switch mode {
            case .wordHunt: screen = .wordHome
            case .flagMatch: screen = .flagMatch
            case .deepCut: screen = .deepCut
            case .krillion: screen = .krillion
            }
        }
        session.launchMode = nil
    }

    /// Generate a guaranteed-solvable board for the chosen map off the main
    /// thread (dictionary load + solver), then start the round.
    private func startMap(_ map: GameMap) {
        wordChallenge = nil
        dailyKey = nil
        screen = .loading
        DispatchQueue.global(qos: .userInitiated).async {
            let board = BoardGenerator.generate(map: map)
            DispatchQueue.main.async {
                game.start(board: board)
                screen = .wordPlaying
            }
        }
    }

    /// The deterministic Map of the Day (heart board), tracked for the leaderboard.
    private func startDaily() {
        wordChallenge = nil
        let key = BoardGenerator.dailyKey()
        dailyKey = key
        screen = .loading
        DispatchQueue.global(qos: .userInitiated).async {
            let board = BoardGenerator.dailyBoard(map: .heart, key: key)
            DispatchQueue.main.async {
                game.start(board: board)
                screen = .wordPlaying
            }
        }
    }
}

/// Home screen: pick a game mode.
struct ModePicker: View {
    let onWordHunt: () -> Void
    let onFlags: () -> Void
    let onDeep: () -> Void
    let onKrillion: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Sammy Word")
                    .font(Theme.rounded(30, .heavy))
                    .foregroundColor(Theme.headerText)
                    .padding(.top, 16)
                Text("Choose a game mode")
                    .font(Theme.rounded(15, .medium))
                    .foregroundColor(Theme.mutedText)

                modeTile(icon: "🔤", title: "Word Hunt",
                         sub: "Trace letters on a board to find as many words as you can",
                         action: onWordHunt)
                modeTile(icon: "🚩", title: "Flag Match",
                         sub: "Match each flag to its country against the clock",
                         action: onFlags)
                modeTile(icon: "💎", title: "Deep Cut",
                         sub: "Name something — the more obscure your answer, the more it scores",
                         action: onDeep)
                modeTile(icon: "🦐", title: "Krillion",
                         sub: "Play today's Krillion dive in chat and trade results with friends",
                         action: onKrillion)
            }
            .padding(20)
        }
    }

    private func modeTile(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(icon).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Theme.rounded(19, .bold)).foregroundColor(Theme.headerText)
                    Text(sub).font(Theme.rounded(13, .medium)).foregroundColor(Theme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.panelBorder, lineWidth: 1)
            )
        }
        .buttonStyle(MapCardButtonStyle())
    }
}

/// Word Hunt home: the featured Map of the Day plus the board-shape picker.
struct WordHuntHome: View {
    let onMap: (GameMap) -> Void
    let onDaily: () -> Void
    let onBack: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button(action: onBack) {
                        Text("← Modes").font(Theme.rounded(15, .semibold)).foregroundColor(Theme.dimText)
                    }
                    Spacer()
                }
                Text("Word Hunt")
                    .font(Theme.rounded(28, .heavy))
                    .foregroundColor(Theme.headerText)
                Text("Pick a board to play")
                    .font(Theme.rounded(14, .medium))
                    .foregroundColor(Theme.mutedText)

                // Featured: Map of the Day (deterministic heart board).
                Button(action: onDaily) {
                    HStack(spacing: 14) {
                        MiniShape(map: .heart, tint: Color(hex: 0xE0556B))
                            .frame(width: 66, height: 66)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("❤️ Map of the Day")
                                .font(Theme.rounded(18, .bold)).foregroundColor(Theme.headerText)
                            Text("Same heart board for everyone today")
                                .font(Theme.rounded(13, .medium)).foregroundColor(Theme.mutedText)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.boardRim, lineWidth: 1)
                    )
                }
                .buttonStyle(MapCardButtonStyle())

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(GameMap.all.filter { $0.id != "heart" }) { map in
                        Button { onMap(map) } label: { MapCard(map: map) }
                            .buttonStyle(MapCardButtonStyle())
                    }
                }
            }
            .padding(20)
        }
    }
}

/// A tappable card previewing one board shape.
struct MapCard: View {
    let map: GameMap

    var body: some View {
        VStack(spacing: 12) {
            MiniShape(map: map)
                .frame(width: 88, height: 88)
            Text(map.name)
                .font(Theme.rounded(16, .bold))
                .foregroundColor(Theme.headerText)
            Text("\(map.activeCount) tiles")
                .font(Theme.rounded(12, .medium))
                .foregroundColor(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.panelBorder, lineWidth: 1)
        )
    }
}

/// Press feedback for cards.
struct MapCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// A small grid preview of a map shape (active cells filled, holes empty).
struct MiniShape: View {
    let map: GameMap
    var tint: Color = Theme.selected

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let availW = geo.size.width - spacing * CGFloat(map.cols - 1)
            let availH = geo.size.height - spacing * CGFloat(map.rows - 1)
            let cell = min(availW / CGFloat(map.cols), availH / CGFloat(map.rows))
            let gridW = cell * CGFloat(map.cols) + spacing * CGFloat(map.cols - 1)
            let gridH = cell * CGFloat(map.rows) + spacing * CGFloat(map.rows - 1)
            let ox = (geo.size.width - gridW) / 2
            let oy = (geo.size.height - gridH) / 2

            ForEach(0..<map.cellCount, id: \.self) { i in
                if map.mask[i] {
                    RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                        .fill(tint)
                        .frame(width: cell, height: cell)
                        .position(
                            x: ox + CGFloat(i % map.cols) * (cell + spacing) + cell / 2,
                            y: oy + CGFloat(i / map.cols) * (cell + spacing) + cell / 2
                        )
                }
            }
        }
    }
}

/// Shown while the first board is generated (dictionary load + solver).
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Theme.headerText)
                .scaleEffect(1.3)
            Text("Building a board…")
                .font(Theme.rounded(16, .medium))
                .foregroundColor(Theme.mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Word Hunt results

/// Final score for a Word Hunt round: a head-to-head comparison when it was a
/// challenge (mirrored word columns + YOU WON! banner), the daily leaderboard on
/// the Map of the Day, or a plain score otherwise.
struct WordHuntOverView: View {
    @ObservedObject var game: WordHuntGame
    let challenge: GamePayload?
    let dailyKey: String?
    @ObservedObject var session: GameSession
    let onNewGame: () -> Void

    @State private var name = DailyStore.playerName
    @State private var sent = false
    @State private var didAutoStage = false
    @State private var nameEdited = false
    @State private var collapseTask: DispatchWorkItem?

    /// A fresh round started to challenge someone (not a reply, not the daily).
    /// Only these get the GamePigeon-style auto-stage + auto-collapse; the daily
    /// keeps its results up so the leaderboard stays readable.
    private var firstTurnChallenge: Bool { challenge == nil && dailyKey == nil }

    private var theirWords: [FoundWord] {
        (challenge?.challengerWords ?? []).map {
            FoundWord(word: $0, points: Scoring.points(forLength: $0.count))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let c = challenge {
                    let theirScore = c.challengerScore ?? 0
                    OutcomeBanner(kind: .of(my: game.score, their: theirScore))
                        .padding(.top, 8)
                    VersusWords(
                        mine: game.foundWords,
                        theirs: theirWords,
                        myScore: game.score,
                        theirScore: theirScore,
                        theirName: c.challengerName ?? "Them",
                        iWin: game.score > theirScore,
                        theyWin: theirScore > game.score
                    )
                } else {
                    Text("Time!")
                        .font(Theme.rounded(32, .heavy))
                        .foregroundColor(Theme.headerText)
                        .padding(.top, 10)
                    Text(String(format: "%04d", game.score))
                        .font(Theme.rounded(60, .heavy))
                        .foregroundColor(Theme.headerText)
                    Text("\(game.foundWords.count) word\(game.foundWords.count == 1 ? "" : "s") found")
                        .font(Theme.rounded(15, .medium))
                        .foregroundColor(Theme.mutedText)
                }

                if let day = dailyKey, challenge == nil {
                    LeaderboardView(day: day, score: game.score, name: name)
                }

                NameField(name: $name)
                    .onChange(of: name) { _ in
                        // Personalizing the challenge cancels the auto-collapse
                        // and brings the button back so they can re-stage by name.
                        guard firstTurnChallenge else { return }
                        nameEdited = true
                        collapseTask?.cancel()
                    }
                if !firstTurnChallenge || nameEdited {
                    sendButton
                }

                Button(action: onNewGame) {
                    Text("New board")
                        .font(Theme.rounded(16, .semibold))
                        .foregroundColor(Theme.mutedText)
                        .underline()
                }

                if challenge == nil {
                    FlowChips(words: game.foundWords.sorted {
                        $0.points != $1.points ? $0.points > $1.points : $0.word < $1.word
                    })
                    .padding(.horizontal, 8)
                }
            }
            .padding(20)
        }
        .onAppear {
            if let day = dailyKey { DailyStore.saveBest(day, game.score) }
            autoStageIfFirstTurn()
        }
    }

    /// On the opening turn (not a reply to someone's challenge), stage the
    /// challenge message into the Messages input the moment results appear. For
    /// a fresh challenge round we then briefly show the score and auto-collapse
    /// to the compact bar, dropping the player right at the staged message + send
    /// arrow — the GamePigeon feel. (iOS gives no API to actually send; the user
    /// always taps that final arrow.) The daily only stages, so its leaderboard
    /// stays up.
    private func autoStageIfFirstTurn() {
        guard challenge == nil, !didAutoStage else { return }
        didAutoStage = true
        send(collapse: false, markSent: false)

        guard firstTurnChallenge else { return }
        let task = DispatchWorkItem { session.requestCollapse() }
        collapseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: task)
    }

    private var sendLabel: String {
        challenge != nil ? "Send result & rematch" : "Challenge a friend"
    }

    private var sendButton: some View {
        Button(action: { send() }) {
            Text(sent ? "Sent! ✓" : sendLabel)
                .font(Theme.rounded(20, .bold))
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.accentDark).offset(y: 5)
                )
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(sent)
        .opacity(sent ? 0.6 : 1)
        .padding(.horizontal, 24)
    }

    private func send(collapse: Bool = true, markSent: Bool = true) {
        let finalName = name.trimmingCharacters(in: .whitespaces)
        DailyStore.playerName = finalName
        let payload = GamePayload(
            mapId: game.board.map.id,
            letters: game.board.letters,
            challengerScore: game.score,
            challengerName: finalName.isEmpty ? "Me" : finalName,
            challengerWords: game.foundWords.map { $0.word }
        )
        session.send(.wordHunt(payload), "Sammy Word — beat my \(game.score)?", collapse)
        if markSent { sent = true }
    }
}

// MARK: - Head-to-head word columns (mirrors the web "YOU WON!" screen)

enum OutcomeKind {
    case won, lost, tie

    static func of(my: Int, their: Int) -> OutcomeKind {
        my > their ? .won : (my < their ? .lost : .tie)
    }

    var text: String {
        switch self {
        case .won: return "YOU WON!"
        case .lost: return "YOU LOST"
        case .tie: return "IT'S A TIE!"
        }
    }
    var fg: Color {
        switch self {
        case .won: return Color(hex: 0x2A2300)
        case .lost: return .white
        case .tie: return Color(hex: 0xE7ECF6)
        }
    }
    var bg: Color {
        switch self {
        case .won: return Color(hex: 0xFFD23F)
        case .lost: return Color(hex: 0xD06070)
        case .tie: return Color(hex: 0x3A7BD5)
        }
    }
    var shadow: Color {
        switch self {
        case .won: return Color(hex: 0xD9A800)
        case .lost: return Color(hex: 0xA8475A)
        case .tie: return Color(hex: 0x2C5FA8)
        }
    }
}

struct OutcomeBanner: View {
    let kind: OutcomeKind
    var body: some View {
        Text(kind.text)
            .font(Theme.rounded(28, .heavy))
            .foregroundColor(kind.fg)
            .padding(.vertical, 12)
            .padding(.horizontal, 34)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(kind.shadow).offset(y: 5)
            )
            .background(kind.bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Two mirrored columns of scored words — yours on the left (chip + points),
/// the opponent's on the right (points + chip) — each with a WORDS/SCORE header,
/// truncated to a preview until "View all words" is tapped.
struct VersusWords: View {
    let mine: [FoundWord]
    let theirs: [FoundWord]
    let myScore: Int
    let theirScore: Int
    let theirName: String
    let iWin: Bool
    let theyWin: Bool

    @State private var showAll = false
    private let preview = 12

    var body: some View {
        let mineSorted = sorted(mine)
        let theirsSorted = sorted(theirs)
        let hidden = max(mineSorted.count, theirsSorted.count) - preview
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                column(name: "You", words: mineSorted, count: mine.count, score: myScore, winner: iWin, mirror: false)
                column(name: theirName, words: theirsSorted, count: theirs.count, score: theirScore, winner: theyWin, mirror: true)
            }
            if hidden > 0 {
                Button(showAll ? "Show fewer words" : "View all words") {
                    withAnimation { showAll.toggle() }
                }
                .font(Theme.rounded(16, .bold))
                .foregroundColor(Color(hex: 0x14161F))
                .padding(.vertical, 12)
                .padding(.horizontal, 28)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func sorted(_ a: [FoundWord]) -> [FoundWord] {
        a.sorted { $0.points != $1.points ? $0.points > $1.points : $0.word < $1.word }
    }

    private func column(name: String, words: [FoundWord], count: Int, score: Int, winner: Bool, mirror: Bool) -> some View {
        let align: HorizontalAlignment = mirror ? .trailing : .leading
        let shown = showAll ? words : Array(words.prefix(preview))
        let more = words.count - shown.count
        return VStack(alignment: align, spacing: 8) {
            Text(name)
                .font(Theme.rounded(15, .bold))
                .foregroundColor(winner ? Color(hex: 0xFFD23F) : Theme.headerText)
                .shadow(color: winner ? Color(hex: 0xFFD23F).opacity(0.6) : .clear, radius: 10)

            VStack(alignment: align, spacing: 1) {
                Text("WORDS: \(count)")
                    .font(Theme.rounded(12, .bold)).foregroundColor(Color(hex: 0x4A4F66))
                Text("SCORE: \(score)")
                    .font(Theme.rounded(20, .heavy)).foregroundColor(Color(hex: 0x14161F))
            }
            .frame(maxWidth: .infinity, alignment: mirror ? .trailing : .leading)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(hex: 0xF2F4FA), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(winner ? Color(hex: 0xFFD23F) : .clear, lineWidth: 2)
            )

            VStack(spacing: 6) {
                ForEach(shown) { fw in
                    if mirror {
                        HStack(spacing: 8) {
                            Text("\(fw.points)").font(Theme.rounded(14, .bold)).foregroundColor(Theme.headerText)
                            Spacer(minLength: 0)
                            wordChip(fw.word)
                        }
                    } else {
                        HStack(spacing: 8) {
                            wordChip(fw.word)
                            Spacer(minLength: 0)
                            Text("\(fw.points)").font(Theme.rounded(14, .bold)).foregroundColor(Theme.headerText)
                        }
                    }
                }
                if shown.isEmpty {
                    Text("No words").font(Theme.rounded(13, .medium)).foregroundColor(Theme.dimText)
                }
                if more > 0 {
                    Text("(\(more) more)").font(Theme.rounded(12, .semibold)).foregroundColor(Theme.dimText)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity)
            .background(Theme.boardPanel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.panelBorder, lineWidth: 1)
            )
        }
    }

    private func wordChip(_ word: String) -> some View {
        Text(word == "QU" ? "Qu" : word.replacingOccurrences(of: "QU", with: "Qu"))
            .font(Theme.rounded(13, .bold))
            .foregroundColor(Theme.tileText)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Theme.tileGradient, in: Capsule())
    }
}

// MARK: - Leaderboard

struct LeaderboardView: View {
    let day: String
    let score: Int
    let name: String

    @State private var data: LeaderboardData?
    @State private var posting = false
    @State private var posted = false

    var body: some View {
        Group {
            if data == nil {
                VStack(spacing: 6) {
                    Text("🏆 Global Leaderboard").font(Theme.rounded(15, .bold)).foregroundColor(Theme.headerText)
                    ProgressView().tint(Theme.mutedText)
                }
                .frame(maxWidth: .infinity).padding(14)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if let d = data, d.configured {
                card(d)
            } else {
                EmptyView()  // backend not provisioned — stay hidden, like the web
            }
        }
        .task { if data == nil { data = await Leaderboard.fetch(day: day) } }
    }

    private func card(_ d: LeaderboardData) -> some View {
        VStack(spacing: 8) {
            Text("🏆 Global Leaderboard").font(Theme.rounded(15, .bold)).foregroundColor(Theme.headerText)
            if d.entries.isEmpty {
                Text("Be the first to post a score!").font(Theme.rounded(13, .medium)).foregroundColor(Theme.mutedText)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(d.entries.prefix(10).enumerated()), id: \.element.id) { i, e in
                        HStack {
                            Text("\(i + 1)").font(Theme.rounded(13, .bold)).foregroundColor(Theme.dimText).frame(width: 22, alignment: .leading)
                            Text(e.name).font(Theme.rounded(14, e.you ? .heavy : .semibold))
                                .foregroundColor(e.you ? Theme.positive : Theme.headerText).lineLimit(1)
                            Spacer()
                            Text(String(format: "%04d", e.score)).font(Theme.rounded(14, .bold)).foregroundColor(Theme.headerText)
                        }
                    }
                }
            }
            if let rank = d.rank { Text("Your rank today: #\(rank)").font(Theme.rounded(12, .medium)).foregroundColor(Theme.mutedText) }
            if posted {
                Text("Posted! ✅").font(Theme.rounded(13, .semibold)).foregroundColor(Theme.positive)
            } else {
                Button(action: { Task { await post() } }) {
                    Text(posting ? "Posting…" : "Post my score")
                        .font(Theme.rounded(14, .bold)).foregroundColor(Theme.headerText)
                }
                .disabled(posting)
            }
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.panelBorder, lineWidth: 1))
    }

    private func post() async {
        posting = true
        let finalName = name.trimmingCharacters(in: .whitespaces)
        let updated = await Leaderboard.submit(day: day, score: score, name: finalName.isEmpty ? "Anonymous" : finalName)
        data = updated
        posted = updated.configured
        posting = false
    }
}

// MARK: - Shared

struct NameField: View {
    @Binding var name: String
    var body: some View {
        TextField("Your name", text: $name)
            .multilineTextAlignment(.center)
            .font(Theme.rounded(16, .semibold))
            .foregroundColor(Theme.headerText)
            .padding(.vertical, 11).padding(.horizontal, 14)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.panelBorder, lineWidth: 1))
            .padding(.horizontal, 24)
            .onChange(of: name) { v in if v.count > 16 { name = String(v.prefix(16)) } }
    }
}

/// Wrapping flow of found-word chips. Each chip hugs its own content (word +
/// points) so the word never wraps to a second line and never overflows the
/// capsule — chips just wrap onto the next row when they run out of width.
struct FlowChips: View {
    let words: [FoundWord]
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(words) { fw in
                HStack(spacing: 5) {
                    Text(fw.word == "QU" ? "Qu" : fw.word.replacingOccurrences(of: "QU", with: "Qu"))
                        .font(Theme.rounded(14, .bold))
                        .lineLimit(1)
                    Text("\(fw.points)").font(Theme.rounded(11, .semibold)).opacity(0.55)
                        .lineLimit(1)
                }
                .fixedSize()
                .foregroundColor(Theme.tileText)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Theme.tileGradient, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A simple left-to-right wrapping layout: places subviews at their natural
/// size, moving to a new row whenever the next one won't fit the available
/// width. Used so found-word chips hug their content instead of being forced
/// into equal-width grid columns (which made 4-letter words wrap mid-word).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0 && rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: maxWidth.isFinite ? maxWidth : totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
