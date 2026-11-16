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

    /// The challenge decoded from a tapped message (Word Hunt, Flag Match, or Deep Cut), if
    /// the extension was opened from one. `nil` means "start fresh."
    @Published var incoming: DecodedGame?

    /// Which game to deep-jump into. The compact bar offers both modes directly,
    /// so a tap there sets this and expands; `ExpandedView` consumes it on appear.
    enum LaunchMode { case wordHunt, flagMatch, deepCut, krillion }
    var launchMode: LaunchMode?

    /// Pick a mode from the compact bar: remember it, then expand into it.
    func launch(_ mode: LaunchMode) {
        launchMode = mode
        requestExpand()
    }

    /// Ask the host to grow to the expanded presentation.
    var requestExpand: () -> Void = {}

    /// Ask the host to shrink to the compact bar, surfacing any staged message
    /// next to the Messages send arrow (GamePigeon-style "ready to send").
    var requestCollapse: () -> Void = {}

    /// Compose and insert a message carrying `game` with the given caption.
    /// `collapse` asks the host to shrink to the compact bar afterward (so the
    /// staged message is ready to send); pass `false` to keep the current
    /// presentation, e.g. when auto-staging while the results screen is still up.
    var send: (_ game: DecodedGame, _ caption: String, _ collapse: Bool) -> Void = { _, _, _ in }

    /// Send `game` straight into the conversation with no extra tap where
    /// Messages allows it (falls back to staging it), then get out of the way.
    var sendNow: (_ game: DecodedGame, _ caption: String) -> Void = { _, _ in }
}
