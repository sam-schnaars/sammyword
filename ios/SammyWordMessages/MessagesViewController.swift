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
        session.sendNow = { [weak self] game, caption in
            self?.sendNow(game: game, caption: caption)
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

    /// Opening the app fresh (or from a Krillion bubble) goes straight into
    /// Krillion, full height — no bar, no menu. Other challenges keep their
    /// "tap to play" bar. Only on activation, so swiping down still collapses.
    override func didBecomeActive(with conversation: MSConversation) {
        super.didBecomeActive(with: conversation)
        guard presentationStyle == .compact else { return }
        switch session.incoming {
        case nil, .krillion:
            session.launchMode = .krillion
            requestPresentationStyle(.expanded)
        default:
            break
        }
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

    private func makeMessage(game: DecodedGame, caption: String, in conversation: MSConversation) -> MSMessage {
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
        case let .krillion(payload):
            layout.image = KrillionImageRenderer.image(for: payload)
        }
        message.layout = layout
        message.url = GameMessage.encode(game)
        return message
    }

    private func send(game: DecodedGame, caption: String, collapse: Bool) {
        guard let conversation = activeConversation else { return }
        conversation.insert(makeMessage(game: game, caption: caption, in: conversation)) { _ in }
        // Staged in the input field; collapsing to compact surfaces it next to
        // the send arrow.
        if collapse { requestPresentationStyle(.compact) }
    }

    /// Send without the extra tap. `MSConversation.send` only succeeds while the
    /// extension is on screen and the player has interacted with it. When it
    /// works the player stays on their results; if Messages refuses, stage the
    /// bubble and collapse so one tap on the arrow sends it.
    private func sendNow(game: DecodedGame, caption: String) {
        guard let conversation = activeConversation else { return }
        let message = makeMessage(game: game, caption: caption, in: conversation)
        conversation.send(message) { [weak self] error in
            guard error != nil else { return }
            DispatchQueue.main.async {
                conversation.insert(message) { _ in }
                self?.requestPresentationStyle(.compact)
            }
        }
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

/// Bubble preview for a Krillion result: the score in huge type over a
/// deep-sea gradient, with one colored block per prompt showing how rare each
/// answer was. Plain shapes and text only.
enum KrillionImageRenderer {
    private static func color(for tier: String) -> UIColor {
        switch tier {
        case "plankton": return UIColor(hex: 0x7BD88F)
        case "schooler": return UIColor(hex: 0x4FC3F7)
        case "rare": return UIColor(hex: 0xB388FF)
        case "deepcut": return UIColor(hex: 0xFF6AD5)
        case "krillion": return UIColor(hex: 0xFFD23F)
        default: return UIColor(white: 1, alpha: 0.14)
        }
    }

    static func image(for payload: KrillionPayload, size: CGFloat = 320) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(hex: 0x0B3A5C).cgColor, UIColor(hex: 0x040B1C).cgColor]
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size), options: [])
            }
            UIColor(white: 1, alpha: 0.16).setFill()
            for (x, y, s) in [(0.10, 0.62, 0.03), (0.16, 0.48, 0.02), (0.88, 0.30, 0.025), (0.82, 0.16, 0.015), (0.90, 0.66, 0.02)] {
                cg.fill(CGRect(x: size * x, y: size * y, width: size * s, height: size * s))
            }

            let center = NSMutableParagraphStyle()
            center.alignment = .center
            func draw(_ text: String, font: UIFont, color: UIColor, y: CGFloat, h: CGFloat, kern: CGFloat = 0) {
                NSAttributedString(string: text, attributes: [
                    .font: font, .foregroundColor: color, .kern: kern, .paragraphStyle: center,
                ]).draw(in: CGRect(x: size * 0.04, y: size * y, width: size * 0.92, height: size * h))
            }

            let title = "🦐 KRILLION" + (payload.day.map { " #\($0)" } ?? "")
            draw(title, font: .monospacedSystemFont(ofSize: size * 0.065, weight: .heavy),
                 color: UIColor(hex: 0x6FE3FF), y: 0.08, h: 0.1, kern: 2)

            guard let score = payload.score else {
                draw("Today's dive", font: .systemFont(ofSize: size * 0.13, weight: .heavy), color: .white, y: 0.36, h: 0.2)
                draw("tap to play", font: .systemFont(ofSize: size * 0.065, weight: .semibold),
                     color: UIColor(white: 1, alpha: 0.8), y: 0.58, h: 0.1)
                return
            }

            draw(String(score), font: .monospacedDigitSystemFont(ofSize: size * 0.34, weight: .black),
                 color: .white, y: 0.2, h: 0.42)
            draw("\(payload.senderName ?? "My") \(payload.senderName == nil ? "score" : "scored") · can you beat it?",
                 font: .systemFont(ofSize: size * 0.055, weight: .semibold),
                 color: UIColor(white: 1, alpha: 0.85), y: 0.63, h: 0.09)

            // One block per prompt, colored by how rare the answer was.
            let tiers = payload.tiers
            if !tiers.isEmpty {
                let gap = size * 0.02
                let block = min(size * 0.1, (size * 0.84 - gap * CGFloat(tiers.count - 1)) / CGFloat(tiers.count))
                let total = block * CGFloat(tiers.count) + gap * CGFloat(tiers.count - 1)
                var x = (size - total) / 2
                for tier in tiers {
                    color(for: tier).setFill()
                    cg.fill(CGRect(x: x, y: size * 0.78, width: block, height: block))
                    x += block + gap
                }
            }
        }
    }
}
