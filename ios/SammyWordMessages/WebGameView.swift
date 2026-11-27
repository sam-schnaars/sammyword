// The embedded versions of the web games, for TestFlight builds only. App
// Store builds open those games in Safari instead (see ExternalGameView),
// because they belong to other people. Build with HOSTED_EMBED to include this.
#if HOSTED_EMBED
import SwiftUI
import WebKit

/// A daily web game (Krillion, Magnitudle, 100 of Us, Eraly) played inside Messages. We don't
/// reimplement them: the real site runs in a web view. To keep friction near
/// zero the page is driven for the player where the site allows it, and the
/// moment a round finishes the score goes out as a bubble.
///
/// Like `MessagesViewController`, this is platform glue (WebKit), not game logic.
struct WebGameView: View {
    let game: Game
    /// A friend's result for this same game, when opened from their bubble.
    let incoming: ScorePayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    /// Today's finished result, once the page reports one.
    @State private var result: ScorePayload?
    @State private var status: SendStatus = .idle
    @State private var load: WebLoad = .loading
    @State private var reloadToken = 0

    private enum SendStatus: Equatable {
        case idle, sending, sent
        case staged(String)   // Messages refused; bubble is waiting in the input field
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onHome) {
                    PixelText("◀", scale: 2, color: Pixel.cream)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                }
                .buttonStyle(PixelButtonStyle(palette: Pixel.row, step: 2))

                PixelSprite(art: game.sprite, scale: 2)
                if let friend = incoming, friend.score != nil {
                    Text("\(friend.senderName ?? "Friend"): \(friend.scoreText)")
                        .font(Pixel.mono(13, .bold))
                        .foregroundColor(Pixel.cream)
                        .lineLimit(1)
                } else {
                    PixelText(game.title, scale: 2)
                }
                Spacer(minLength: 4)
                if let result {
                    Button { deliver(result) } label: {
                        Text(pillText(result))
                            .font(Pixel.mono(12, .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                    }
                    .buttonStyle(PixelButtonStyle(palette: status == .sent ? Pixel.row : Pixel.button, step: 2))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: 0x0B0A1F))

            ZStack {
                WebGameWebView(game: game, reloadToken: reloadToken, onLoad: { load = $0 }) { finished, live in
                    var mine = finished
                    let name = DailyStore.playerName.trimmingCharacters(in: .whitespaces)
                    mine.senderName = name.isEmpty ? nil : name
                    result = mine
                    DailyStore.record(mine)
                    // Just finished a round in front of us → send it without asking.
                    if live { deliver(mine) }
                }
                if load != .ready { loadingCover }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Covers the page until it has loaded, so a slow site reads as loading
    /// instead of a frozen screen, and offers a way out if it never arrives.
    private var loadingCover: some View {
        VStack(spacing: 14) {
            PixelSprite(art: game.sprite, scale: 6)
            switch load {
            case .loading:
                PixelText("LOADING \(game.title)", scale: 2, color: Pixel.muted)
                ProgressView().tint(Pixel.cream)
            case .slow, .failed:
                PixelText(load == .failed ? "DIDN'T LOAD" : "TAKING A WHILE", scale: 3)
                Text("Check your connection, then try again.")
                    .font(Pixel.mono(13)).foregroundColor(Pixel.muted)
                Button { load = .loading; reloadToken += 1 } label: {
                    PixelText("RELOAD", scale: 2)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                }
                .buttonStyle(PixelButtonStyle())
            case .ready:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func pillText(_ result: ScorePayload) -> String {
        switch status {
        case .idle: return "Send \(result.scoreText)"
        case .sending: return "Sending…"
        case .sent: return "Sent ✓"
        case let .staged(why): return "Tap ↑ to send (\(why))"
        }
    }

    private func deliver(_ payload: ScorePayload) {
        guard status != .sending else { return }
        status = .sending
        session.sendNow(payload) { failure in
            status = failure.map { .staged($0) } ?? .sent
        }
    }
}

#endif
