import SwiftUI

/// Minimal container app. It exists only because an iMessage extension needs a
/// host app — the actual game lives in the SammyWordMessages extension. This
/// screen just points the user at Messages.
@main
struct SammyWordApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.65, blue: 0.13),
                         Color(red: 0.91, green: 0.51, blue: 0.12)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Sammy Word")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("Open Messages, tap the apps icon next to the text field, and pick Sammy Word to play.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 32)
            }
        }
    }
}
