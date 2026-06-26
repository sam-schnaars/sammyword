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

    /// The challenge decoded from a tapped message, if the extension was opened
    /// from one. `nil` means "start a fresh game."
    @Published var incoming: GamePayload?

    /// Ask the host to grow to the expanded presentation.
    var requestExpand: () -> Void = {}

    /// Compose and insert a message carrying `payload` with the given caption.
    var sendResult: (_ payload: GamePayload, _ caption: String) -> Void = { _, _ in }
}
