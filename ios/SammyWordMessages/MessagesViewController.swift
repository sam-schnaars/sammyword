import UIKit
import Messages
import SwiftUI

/// Hosts the SwiftUI game and bridges it to Messages. This is the only place
/// that imports UIKit/Messages; the game logic stays portable.
final class MessagesViewController: MSMessagesAppViewController {
    private let session = GameSession()
    private var hosting: UIHostingController<RootView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        session.requestExpand = { [weak self] in
            self?.requestPresentationStyle(.expanded)
        }
        session.sendResult = { [weak self] payload, caption in
            self?.send(payload: payload, caption: caption)
        }

        let host = UIHostingController(rootView: RootView(session: session))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hosting = host
    }

    // MARK: - Conversation lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        updateIncoming(from: conversation.selectedMessage)
        syncPresentation()
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        updateIncoming(from: message)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        syncPresentation(presentationStyle)
    }

    private func syncPresentation(_ style: MSMessagesAppPresentationStyle? = nil) {
        session.presentation = (style ?? presentationStyle) == .expanded ? .expanded : .compact
    }

    private func updateIncoming(from message: MSMessage?) {
        session.incoming = GameMessage.decode(message?.url)
    }

    // MARK: - Sending

    private func send(payload: GamePayload, caption: String) {
        guard let conversation = activeConversation else { return }

        // Reuse the existing game's session so prior bubbles collapse (GamePigeon
        // style); otherwise start a new one.
        let msgSession = conversation.selectedMessage?.session ?? MSSession()
        let message = MSMessage(session: msgSession)

        let layout = MSMessageTemplateLayout()
        layout.caption = caption
        layout.image = BoardImageRenderer.image(for: payload.board)
        message.layout = layout
        message.url = GameMessage.encode(payload)

        conversation.insert(message) { _ in }
        requestPresentationStyle(.compact)
    }
}

/// Renders a small board preview for the message bubble. UIKit lives here, not
/// in the game model.
enum BoardImageRenderer {
    static func image(for board: GameBoard, size: CGFloat = 320) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Orange background
            cg.setFillColor(UIColor(red: 0.96, green: 0.65, blue: 0.13, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: size, height: size))

            let pad: CGFloat = size * 0.08
            let gap: CGFloat = size * 0.03
            let cell = (size - pad * 2 - gap * 3) / 4
            let tileColor = UIColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1)
            let letterColor = UIColor(red: 0.29, green: 0.23, blue: 0.16, alpha: 1)

            for i in 0..<GameBoard.cellCount {
                let r = CGFloat(i / 4)
                let c = CGFloat(i % 4)
                let x = pad + c * (cell + gap)
                let y = pad + r * (cell + gap)
                let rect = CGRect(x: x, y: y, width: cell, height: cell)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: cell * 0.18)
                tileColor.setFill()
                path.fill()

                let raw = board.tiles[i].letter
                let text = raw == "QU" ? "Qu" : raw
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: cell * 0.42, weight: .heavy),
                    .foregroundColor: letterColor,
                ]
                let str = NSAttributedString(string: text, attributes: attrs)
                let textSize = str.size()
                str.draw(at: CGPoint(
                    x: rect.midX - textSize.width / 2,
                    y: rect.midY - textSize.height / 2
                ))
            }
        }
    }
}
