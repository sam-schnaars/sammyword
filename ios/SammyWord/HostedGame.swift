import SwiftUI
import MessageUI
import Messages

extension Game: Identifiable {
    public var id: String { rawValue }
}

/// Magnitudle or 100 of Us, played in the Sammy Word app with the site's own
/// ads (the creators' condition; ads aren't allowed inside the iMessage
/// extension). Links that leave the site, like ad clicks, open in Safari.
/// When a round finishes, a Messages sheet comes up with the score bubble.
struct HostedGameScreen: View {
    let game: Game
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var load: WebLoad = .loading
    @State private var reloadToken = 0
    @State private var result: ScorePayload?
    @State private var composing = false
    @State private var sent = false
    @State private var noMessages = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                WebGameWebView(game: game, reloadToken: reloadToken, onLoad: { load = $0 },
                               onExternalLink: { openURL($0) }) { finished, live in
                    var mine = finished
                    let name = DailyStore.playerName.trimmingCharacters(in: .whitespaces)
                    mine.senderName = name.isEmpty ? nil : name
                    result = mine
                    DailyStore.record(mine)
                    // Just finished in front of us: offer to send it straight away.
                    if live { share() }
                }
                if load != .ready { cover }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color(hex: 0x0B0A1F).ignoresSafeArea())
        .sheet(isPresented: $composing) {
            if let result {
                MessageComposer(payload: result) { didSend in sent = didSend }
                    .ignoresSafeArea()
            }
        }
        .alert("Can't send from here", isPresented: $noMessages) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device can't send iMessages, so the score can't be shared from here. It's saved in Sammy Word.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                PixelText("◀", scale: 2, color: Pixel.cream)
                    .padding(.horizontal, 6).padding(.vertical, 4)
            }
            .buttonStyle(PixelButtonStyle(palette: Pixel.row, step: 2))
            PixelSprite(art: game.sprite, scale: 2)
            PixelText(game.title, scale: 2)
            Spacer(minLength: 4)
            if let result {
                Button(action: share) {
                    Text(sent ? "Sent ✓" : "Send \(result.scoreText)")
                        .font(Pixel.mono(12, .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                }
                .buttonStyle(PixelButtonStyle(palette: sent ? Pixel.row : Pixel.button, step: 2))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Covers the page until it loads, with a way out if it never does.
    private var cover: some View {
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
                    PixelText("RELOAD", scale: 2).padding(.horizontal, 18).padding(.vertical, 8)
                }
                .buttonStyle(PixelButtonStyle())
            case .ready:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PixelSky())
    }

    private func share() {
        if MFMessageComposeViewController.canSendText() { composing = true } else { noMessages = true }
    }
}

/// The system Messages sheet, pre-filled with the score as an interactive
/// Sammy Word bubble (tapping it in the chat opens the iMessage app).
struct MessageComposer: UIViewControllerRepresentable {
    let payload: ScorePayload
    let onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        let message = MSMessage(session: MSSession())
        let layout = MSMessageTemplateLayout()
        layout.caption = payload.caption
        layout.image = ScoreImageRenderer.image(for: payload)
        message.layout = layout
        message.url = GameMessage.encode(payload)
        vc.message = message
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onFinish(result == .sent)
            controller.dismiss(animated: true)
        }
    }
}
