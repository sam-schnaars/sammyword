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
        session.requestCollapse = { [weak self] in
            self?.requestPresentationStyle(.compact)
        }
        session.openURL = { [weak self] url in
            self?.extensionContext?.open(url, completionHandler: nil)
        }
        session.sendNow = { [weak self] payload, done in
            guard let self else { return done("closed") }
            self.sendNow(payload, done: done)
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
        updateIncoming(from: conversation.selectedMessage, in: conversation)
        syncPresentation()
    }

    /// Opening the app fresh goes full height onto the home screen (game of the
    /// day up top), and a friend's bubble goes straight into that game. Only on
    /// activation, so swiping down still collapses.
    override func didBecomeActive(with conversation: MSConversation) {
        super.didBecomeActive(with: conversation)
        guard presentationStyle == .compact else { return }
        session.launchMode = session.incoming?.game
        requestPresentationStyle(.expanded)
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        updateIncoming(from: message, in: conversation)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        syncPresentation(presentationStyle)
    }

    private func syncPresentation(_ style: MSMessagesAppPresentationStyle? = nil) {
        session.presentation = (style ?? presentationStyle) == .expanded ? .expanded : .compact
    }

    private func updateIncoming(from message: MSMessage?, in conversation: MSConversation) {
        session.incomingIsMine = message.map { $0.senderParticipantIdentifier == conversation.localParticipantIdentifier } ?? false
        session.incoming = GameMessage.decode(message?.url)
    }

    // MARK: - Sending

    private func makeMessage(_ payload: ScorePayload, in conversation: MSConversation) -> MSMessage {
        // Reuse the tapped bubble's session so earlier bubbles in the thread
        // collapse; otherwise start a new one.
        let message = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
        let layout = MSMessageTemplateLayout()
        layout.caption = payload.caption
        layout.image = ScoreImageRenderer.image(for: payload)
        message.layout = layout
        message.url = GameMessage.encode(payload)
        return message
    }

    /// Send without the extra tap. Apple only lets `MSConversation.send` through
    /// while the extension is visible and has had a recent touch, and it can
    /// refuse (or never answer). Whatever happens the player ends up looking at
    /// the chat: on success the bubble is in the transcript; otherwise it is
    /// staged in the input field, one tap on the arrow from sent.
    private func sendNow(_ payload: ScorePayload, done: @escaping (String?) -> Void) {
        guard let conversation = activeConversation else { return done("no chat") }
        let message = makeMessage(payload, in: conversation)
        var settled = false
        let settle: (String?) -> Void = { [weak self] failure in
            DispatchQueue.main.async {
                guard !settled else { return }
                settled = true
                if failure != nil { conversation.insert(message) { _ in } }
                done(failure)
                self?.requestPresentationStyle(.compact)
            }
        }
        conversation.send(message) { error in
            settle(error.map { "error \(($0 as NSError).code)" })
        }
        // No answer from Messages counts as a refusal.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { settle("timeout") }
    }
}
