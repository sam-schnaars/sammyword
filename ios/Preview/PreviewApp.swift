import SwiftUI

/// Simulator-only preview of the iMessage games. The simulator's Messages app
/// can't open iMessage apps, so this runs the extension's SwiftUI screens in a
/// plain app instead, for demos and screenshots. Never archived or shipped:
/// `Scripts/archive.sh` builds only the SammyWord scheme. Sending to the chat
/// isn't available here, so results stay "waiting in the text field".
@main
struct SammyWordPreviewApp: App {
    @StateObject private var session: GameSession = {
        let s = GameSession()
        s.presentation = .expanded
        return s
    }()

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                .preferredColorScheme(.dark)
        }
    }
}
