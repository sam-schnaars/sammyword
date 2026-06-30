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
            Color(red: 0.047, green: 0.047, blue: 0.063) // #0C0C10
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Sammy Word")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.784, green: 0.831, blue: 0.918)) // #C8D4EA
                Text("Open Messages, tap the apps icon next to the text field, and pick Sammy Word to play.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.616, green: 0.659, blue: 0.745)) // #9DA8BE
                    .padding(.horizontal, 32)
            }
        }
    }
}
