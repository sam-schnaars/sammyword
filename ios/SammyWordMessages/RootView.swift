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

/// The small bar shown above the keyboard. On a fresh open it offers every game
/// directly; if opened from a friend's bubble, it's a single "tap to play".
struct CompactView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        if let p = session.incoming {
            Button { session.requestExpand() } label: {
                VStack(spacing: 4) {
                    Text("Sammy Word")
                        .font(Theme.rounded(26, .heavy))
                    Text(p.score == nil
                         ? "\(p.senderName ?? "A friend") wants to play \(p.game.title) — tap to play"
                         : "\(p.senderName ?? "A friend") \(p.brag) on \(p.game.title) — tap to beat it")
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
                ForEach(WebGame.allCases, id: \.self) { game in
                    gameButton(game) { session.launch(game) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
        }
    }

    private func gameButton(_ game: WebGame, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(game.emoji).font(.system(size: 24))
                Text(game.title)
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
}

/// The expanded sheet: the game menu, or one game's site.
struct ExpandedView: View {
    @ObservedObject var session: GameSession

    enum Screen: Equatable { case menu, web(WebGame) }
    @State private var screen: Screen = .menu
    @State private var kicked = false

    var body: some View {
        Group {
            switch screen {
            case .menu:
                GameMenu { screen = .web($0) }
            case let .web(game):
                WebGameView(
                    game: game,
                    incoming: session.incoming.flatMap { $0.game == game ? $0 : nil },
                    session: session,
                    onHome: { screen = .menu }
                )
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
            screen = .web(game)
        }
        session.launchMode = nil
    }

    /// A tapped bubble jumps straight into its game. Returns whether it did.
    @discardableResult
    private func routeIncoming() -> Bool {
        guard let p = session.incoming else { return false }
        screen = .web(p.game)
        return true
    }
}

/// Home screen: pick a game.
struct GameMenu: View {
    let onPick: (WebGame) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Sammy Word")
                    .font(Theme.rounded(30, .heavy))
                    .foregroundColor(Theme.headerText)
                    .padding(.top, 16)
                Text("Pick today's game")
                    .font(Theme.rounded(15, .medium))
                    .foregroundColor(Theme.mutedText)

                ForEach(WebGame.allCases, id: \.self) { game in
                    tile(game)
                }
            }
            .padding(20)
        }
    }

    private func tile(_ game: WebGame) -> some View {
        Button { onPick(game) } label: {
            HStack(spacing: 14) {
                Text(game.emoji).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.title).font(Theme.rounded(19, .bold)).foregroundColor(Theme.headerText)
                    Text(game.blurb).font(Theme.rounded(13, .medium)).foregroundColor(Theme.mutedText)
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
        .buttonStyle(PressButtonStyle())
    }
}

/// Press feedback for cards.
struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
