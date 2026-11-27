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

/// The small bar shown above the keyboard. On a fresh open it leads with the
/// game of the day; if opened from a friend's bubble, it's a single "tap to play".
struct CompactView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        if let p = session.incoming {
            Button { session.requestExpand() } label: {
                VStack(spacing: 10) {
                    PixelSprite(art: p.game.sprite, scale: 4)
                    PixelText("SAMMY WORD", scale: 3, color: Pixel.gold, shadow: Pixel.goldDark)
                    Text(p.game == .captionMeme && p.captionText != nil
                         ? "\(p.senderName ?? "A friend") captioned today's meme — tap to see it and write yours"
                         : p.score == nil
                         ? "\(p.senderName ?? "A friend") wants to play \(p.game.title) — tap to play"
                         : "\(p.senderName ?? "A friend") \(p.brag) on \(p.game.title) — tap to beat it")
                        .font(Pixel.mono(14, .semibold))
                        .foregroundColor(Pixel.cream)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            let today = Daily.game()
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Game.own + Game.web, id: \.self) { game in
                    Button { session.launch(game) } label: {
                        VStack(spacing: 6) {
                            PixelText(game == today ? "TODAY" : " ", scale: 1.5,
                                      color: Pixel.gold, shadow: nil)
                            PixelSprite(art: game.sprite, scale: 3)
                            Text(game.title)
                                .font(Pixel.mono(12, .bold))
                                .foregroundColor(Pixel.cream)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .padding(.vertical, 8)
                        .frame(width: 84)
                    }
                    .buttonStyle(PixelButtonStyle(palette: game == today ? Pixel.featured : Pixel.row))
                }
            }
            .padding(.horizontal, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The expanded sheet: the home screen, or one game's site.
struct ExpandedView: View {
    @ObservedObject var session: GameSession

    enum Screen: Equatable { case menu, play(Game) }
    @State private var screen: Screen = .menu
    @State private var kicked = false

    var body: some View {
        Group {
            switch screen {
            case .menu:
                GameMenu { screen = .play($0) }
            case let .play(game):
                GameScreen(game: game,
                           incoming: session.incoming.flatMap { $0.game == game ? $0 : nil },
                           session: session,
                           onHome: { screen = .menu })
                    .id(game)
            }
        }
        .onAppear(perform: begin)
        // A bubble tapped while the app is already open must still jump to its
        // game; without this the open screen stayed put and the tap looked dead.
        .onChange(of: session.incoming) { _ in routeIncoming() }
    }

    private func begin() {
        guard !kicked else { return }
        kicked = true
        if !routeIncoming(), let game = session.launchMode {
            screen = .play(game)
        }
        session.launchMode = nil
    }

    /// A tapped bubble jumps straight into its game. Returns whether it did.
    @discardableResult
    private func routeIncoming() -> Bool {
        guard let p = session.incoming else { return false }
        screen = .play(p.game)
        return true
    }
}

/// One game's screen. Web games open on their creators' sites in App Store
/// builds; TestFlight builds (HOSTED_EMBED) play them inside Messages.
struct GameScreen: View {
    let game: Game
    let incoming: ScorePayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    var body: some View {
        switch game {
        case .wordHunt: WordHuntView(incoming: incoming, session: session, onHome: onHome)
        case .flagMatch: FlagMatchView(incoming: incoming, session: session, onHome: onHome)
        case .captionMeme: CaptionView(incoming: incoming, session: session, onHome: onHome)
        default:
            #if HOSTED_EMBED
            WebGameView(game: game, incoming: incoming, session: session, onHome: onHome)
            #else
            ExternalGameView(game: game, incoming: incoming, session: session, onHome: onHome)
            #endif
        }
    }
}

/// Home screen: today's featured game up top, the rest below.
struct GameMenu: View {
    let onPick: (Game) -> Void
    var today = Date()

    var body: some View {
        ScrollView { content }
    }

    var content: some View {
        let featured = Daily.game(for: today)
        let streak = Daily.streak(today)
        return VStack(spacing: 20) {
            VStack(spacing: 10) {
                PixelText("SAMMY WORD", scale: 4, color: Pixel.gold, shadow: Pixel.goldDark)
                PixelText("DAY \(Daily.number(today)) · \(Daily.label(today))",
                          scale: 2, color: Pixel.muted, shadow: nil)
            }
            .padding(.top, 22)

            hero(featured)

            if streak > 0 {
                HStack(spacing: 8) {
                    PixelSprite(art: PixelSprites.flame, scale: 3)
                    PixelText("\(streak) DAY STREAK", scale: 2, color: Color(hex: 0xFFB13B))
                }
            }

            section("OUR GAMES", nil, Game.own.filter { $0 != featured })
            section("MORE DAILY GAMES", Self.webNote, Game.web.filter { $0 != featured })
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 60)
    }

    private func hero(_ game: Game) -> some View {
        let score = DailyStore.played(game, on: today)
        return VStack(spacing: 14) {
            HStack(spacing: 8) {
                PixelText("★", scale: 2, color: Pixel.gold)
                PixelText("GAME OF THE DAY", scale: 2, color: Pixel.gold)
                PixelText("★", scale: 2, color: Pixel.gold)
            }
            ZStack {
                PixelDisc(cells: 16, scale: 6, color: Color(hex: game.glow).opacity(0.28))
                PixelDisc(cells: 13, scale: 6, color: Color(hex: game.glow).opacity(0.22))
                PixelSprite(art: game.sprite, scale: 6)
            }
            PixelText(game.title, scale: game.title.count > 12 ? 3 : 4)
            Text(game.blurb)
                .font(Pixel.mono(13))
                .foregroundColor(Pixel.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let score {
                PixelText("✓ TODAY: \(score)", scale: 2, color: Pixel.green)
            }
            Button { onPick(game) } label: {
                PixelText(score == nil ? "▶ PLAY" : "▶ PLAY AGAIN", scale: 3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PixelButtonStyle(step: 4))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .pixelBox(Pixel.featured, step: 4)
    }

    #if HOSTED_EMBED
    static let webNote = "Made by their own creators."
    #else
    static let webNote = "Made by their own creators. They open on their websites."
    #endif

    private func section(_ title: String, _ note: String?, _ games: [Game]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText(title, scale: 2, color: Pixel.muted, shadow: nil)
                .padding(.leading, 2)
            if let note {
                Text(note).font(Pixel.mono(11)).foregroundColor(Pixel.muted.opacity(0.8)).padding(.leading, 2)
            }
            ForEach(games, id: \.self) { row($0) }
        }
    }

    private func row(_ game: Game) -> some View {
        let score = DailyStore.played(game, on: today)
        return Button { onPick(game) } label: {
            HStack(spacing: 14) {
                PixelSprite(art: game.sprite, scale: 3)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 5) {
                    PixelText(game.title, scale: 2)
                    Text(game.isDaily ? (score.map { "Done today · \($0)" } ?? game.blurb) : game.blurb)
                        .font(Pixel.mono(11))
                        .foregroundColor(score == nil ? Pixel.muted : Pixel.green)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                PixelText(score == nil ? "▶" : "✓", scale: 2, color: score == nil ? Pixel.gold : Pixel.green)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PixelButtonStyle(palette: Pixel.row))
    }
}
