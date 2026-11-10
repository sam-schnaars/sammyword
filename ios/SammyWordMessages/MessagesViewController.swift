import UIKit
import Messages
import SwiftUI

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

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
        session.send = { [weak self] game, caption, collapse in
            self?.send(game: game, caption: caption, collapse: collapse)
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

    private func send(game: DecodedGame, caption: String, collapse: Bool) {
        guard let conversation = activeConversation else { return }

        // Reuse the existing game's session so prior bubbles collapse (GamePigeon
        // style); otherwise start a new one.
        let msgSession = conversation.selectedMessage?.session ?? MSSession()
        let message = MSMessage(session: msgSession)

        let layout = MSMessageTemplateLayout()
        layout.caption = caption
        switch game {
        case let .wordHunt(payload):
            layout.image = BoardImageRenderer.image(for: payload.board)
        case let .flagMatch(payload):
            layout.image = FlagImageRenderer.image(for: payload.seed)
        case let .deepCut(payload):
            layout.image = DeepCutImageRenderer.image(for: payload.seed)
        }
        message.layout = layout
        message.url = GameMessage.encode(game)

        conversation.insert(message) { _ in }
        // Note: Messages extensions can only *stage* a message into the input
        // field — Apple gives no API to actually send it, so the user still taps
        // the send arrow. Collapsing to compact surfaces that staged bubble.
        if collapse { requestPresentationStyle(.compact) }
    }
}

/// Renders the message-bubble board preview to match the Sammy Word web app:
/// a near-black framed panel with a steel rim and brushed-metal tiles. UIKit
/// lives here, not in the game model.
enum BoardImageRenderer {
    static func image(for board: GameBoard, size: CGFloat = 320) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let full = CGRect(x: 0, y: 0, width: size, height: size)

            // Near-black background with faint diagonal stripes.
            UIColor(hex: 0x0E0E14).setFill()
            cg.fill(full)
            cg.saveGState()
            cg.clip(to: full)
            UIColor(hex: 0x111118).setFill()
            let stripe: CGFloat = size * 0.044
            var sx = -size
            while sx < size {
                let band = UIBezierPath()
                band.move(to: CGPoint(x: sx, y: 0))
                band.addLine(to: CGPoint(x: sx + stripe, y: 0))
                band.addLine(to: CGPoint(x: sx + stripe - size, y: size))
                band.addLine(to: CGPoint(x: sx - size, y: size))
                band.close()
                band.fill()
                sx += stripe * 2
            }
            cg.restoreGState()

            // Framed board panel + steel rim.
            let margin = size * 0.035
            let frame = full.insetBy(dx: margin, dy: margin)
            let rim = size * 0.03
            let radius = size * 0.085
            let panel = UIBezierPath(roundedRect: frame, cornerRadius: radius)
            UIColor(hex: 0x16171E).setFill()
            panel.fill()
            let rimPath = UIBezierPath(
                roundedRect: frame.insetBy(dx: rim / 2, dy: rim / 2),
                cornerRadius: radius - rim / 2
            )
            UIColor(hex: 0x3C3F52).setStroke()
            rimPath.lineWidth = rim
            rimPath.stroke()

            // Brushed-metal tiles — laid out for the board's shape (only the
            // playable cells are drawn), centered in the framed panel.
            let map = board.map
            let cols = map.cols, rows = map.rows
            let pad = rim + size * 0.04
            let content = frame.insetBy(dx: pad, dy: pad)
            let gap = size * 0.022
            let cellW = (content.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (content.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            let cell = min(cellW, cellH)
            let gridW = cell * CGFloat(cols) + gap * CGFloat(cols - 1)
            let gridH = cell * CGFloat(rows) + gap * CGFloat(rows - 1)
            let ox = content.minX + (content.width - gridW) / 2
            let oy = content.minY + (content.height - gridH) / 2
            let letterColor = UIColor(hex: 0xDDE3F0)

            for i in 0..<map.cellCount {
                guard let raw = board.cells[i] else { continue }
                let r = CGFloat(i / cols)
                let c = CGFloat(i % cols)
                let rect = CGRect(
                    x: ox + c * (cell + gap),
                    y: oy + r * (cell + gap),
                    width: cell, height: cell
                )
                let tile = UIBezierPath(roundedRect: rect, cornerRadius: cell * 0.18)

                // Vertical steel gradient (top highlight → dark base).
                cg.saveGState()
                tile.addClip()
                let colors = [UIColor(hex: 0x545A6A).cgColor, UIColor(hex: 0x363B48).cgColor]
                if let grad = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors as CFArray, locations: [0, 1]
                ) {
                    cg.drawLinearGradient(
                        grad,
                        start: CGPoint(x: rect.midX, y: rect.minY),
                        end: CGPoint(x: rect.midX, y: rect.maxY),
                        options: []
                    )
                }
                cg.restoreGState()

                // Subtle top bevel highlight.
                UIColor(white: 1, alpha: 0.10).setStroke()
                tile.lineWidth = 1
                tile.stroke()

                let text = raw == "QU" ? "Qu" : raw
                let shadow = NSShadow()
                shadow.shadowColor = UIColor(white: 0, alpha: 0.6)
                shadow.shadowOffset = CGSize(width: 0, height: 1)
                shadow.shadowBlurRadius = 2
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: cell * 0.42, weight: .heavy),
                    .foregroundColor: letterColor,
                    .shadow: shadow,
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

/// Renders the message-bubble preview for a Flag Match challenge: a 2×2 of the
/// quiz's first flags on the same near-black striped background as the board.
enum FlagImageRenderer {
    static func image(for seed: Int, size: CGFloat = 320) -> UIImage {
        let flags = Flags.buildQuiz(seed: seed).prefix(4).map { $0.flag }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let full = CGRect(x: 0, y: 0, width: size, height: size)

            // Near-black background with faint diagonal stripes (matches the board).
            UIColor(hex: 0x0E0E14).setFill()
            cg.fill(full)
            cg.saveGState()
            cg.clip(to: full)
            UIColor(hex: 0x111118).setFill()
            let stripe: CGFloat = size * 0.044
            var sx = -size
            while sx < size {
                let band = UIBezierPath()
                band.move(to: CGPoint(x: sx, y: 0))
                band.addLine(to: CGPoint(x: sx + stripe, y: 0))
                band.addLine(to: CGPoint(x: sx + stripe - size, y: size))
                band.addLine(to: CGPoint(x: sx - size, y: size))
                band.close()
                band.fill()
                sx += stripe * 2
            }
            cg.restoreGState()

            // 2×2 flag emoji.
            let glyph = size * 0.34
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: glyph)
            ]
            let centers = [
                CGPoint(x: size * 0.30, y: size * 0.30),
                CGPoint(x: size * 0.70, y: size * 0.30),
                CGPoint(x: size * 0.30, y: size * 0.70),
                CGPoint(x: size * 0.70, y: size * 0.70),
            ]
            for (i, flag) in flags.enumerated() where i < centers.count {
                let str = NSAttributedString(string: flag, attributes: attrs)
                let sz = str.size()
                str.draw(at: CGPoint(x: centers[i].x - sz.width / 2, y: centers[i].y - sz.height / 2))
            }
        }
    }
}

/// Renders the message-bubble preview for a Deep Cut challenge: the round's
/// first prompt in big type on the same near-black background, under a gem.
enum DeepCutImageRenderer {
    static func image(for seed: Int, size: CGFloat = 320) -> UIImage {
        let first = DeepCut.buildRound(seed: seed).first
        let prompt = first.map { DeepCut.prompts[$0].q } ?? "Deep Cut"
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let full = CGRect(x: 0, y: 0, width: size, height: size)
            UIColor(hex: 0x0E0E14).setFill()
            ctx.cgContext.fill(full)

            let center = NSMutableParagraphStyle()
            center.alignment = .center

            let gem = NSAttributedString(string: "💎", attributes: [.font: UIFont.systemFont(ofSize: size * 0.2)])
            let gs = gem.size()
            gem.draw(at: CGPoint(x: (size - gs.width) / 2, y: size * 0.1))

            let title = NSAttributedString(string: "DEEP CUT", attributes: [
                .font: UIFont.systemFont(ofSize: size * 0.075, weight: .heavy),
                .foregroundColor: UIColor(hex: 0xFFD23F),
                .kern: 3,
                .paragraphStyle: center,
            ])
            title.draw(in: CGRect(x: 0, y: size * 0.36, width: size, height: size * 0.1))

            let body = NSAttributedString(string: prompt, attributes: [
                .font: UIFont.systemFont(ofSize: size * 0.085, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: center,
            ])
            body.draw(in: CGRect(x: size * 0.08, y: size * 0.52, width: size * 0.84, height: size * 0.4))
        }
    }
}
