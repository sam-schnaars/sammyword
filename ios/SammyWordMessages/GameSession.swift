import Foundation
import Combine

/// Bridges the SwiftUI game and the `MessagesViewController`. The view controller
/// owns one of these, wires up the callbacks, and updates `presentation` /
/// `incoming`; the SwiftUI tree only ever talks to this object (no UIKit/Messages
/// imports leak into the views).
final class GameSession: ObservableObject {
    enum Presentation {
        case compact   // small bar above the keyboard
        case expanded  // full sheet
    }

    /// Current presentation style of the extension.
    @Published var presentation: Presentation = .compact

    /// The result or invite decoded from a tapped bubble, if the extension was
    /// opened from one. `nil` means "start fresh."
    @Published var incoming: ScorePayload?

    /// The tapped bubble was sent from this device (e.g. your own doodle).
    @Published var incomingIsMine = false

    /// Which game to jump into on expand; `ExpandedView` consumes it on appear.
    var launchMode: Game?

    /// Pick a game from the compact bar: remember it, then expand into it.
    func launch(_ game: Game) {
        launchMode = game
        requestExpand()
    }

    /// Open a link outside Messages (a web game's site in Safari).
    var openURL: (URL) -> Void = { _ in }

    /// Ask the host to grow to the expanded presentation.
    var requestExpand: () -> Void = {}

    /// Ask the host to shrink to the compact bar.
    var requestCollapse: () -> Void = {}

    /// Send a result straight into the conversation with no extra tap where
    /// Messages allows it. `done` reports what really happened: nil = sent;
    /// otherwise a short reason, and the bubble was staged in the input field
    /// instead (one tap on the arrow sends it).
    var sendNow: (_ payload: ScorePayload, _ done: @escaping (String?) -> Void) -> Void = { _, done in done("unavailable") }
}
