import SwiftUI

/// The container app. An iMessage extension needs a host app; the games live
/// in the SammyWordMessages extension. This screen shows today's game and how
/// to find Sammy Word in Messages, in the same pixel-art style.
@main
struct SammyWordApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    var today = Date()

    var body: some View {
        ZStack {
            PixelSky()
            ScrollView { content }
        }
    }

    var content: some View {
        let featured = Daily.game(for: today)
        return VStack(spacing: 22) {
            VStack(spacing: 10) {
                PixelText("SAMMY WORD", scale: 4, color: Pixel.gold, shadow: Pixel.goldDark)
                Text("A game of the day for your group chat")
                    .font(Pixel.mono(14, .semibold))
                    .foregroundColor(Pixel.muted)
            }
            .padding(.top, 36)

            VStack(spacing: 12) {
                PixelText("TODAY: \(featured.title)", scale: 2, color: Pixel.gold)
                PixelSprite(art: featured.sprite, scale: 6)
                Text(featured.blurb)
                    .font(Pixel.mono(13))
                    .foregroundColor(Pixel.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .pixelBox(Pixel.featured, step: 4)

            VStack(alignment: .leading, spacing: 12) {
                PixelText("HOW TO PLAY", scale: 2, color: Pixel.muted, shadow: nil)
                step(1, "Open a chat in Messages.")
                step(2, "Tap + next to the text field, then More, and pick Sammy Word.")
                step(3, "Hit PLAY. When you finish, your score drops into the chat.")
            }

            if let messages = URL(string: "sms:") {
                Link(destination: messages) {
                    PixelText("▶ OPEN MESSAGES", scale: 3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PixelButtonStyle(step: 4))
            }

            VStack(alignment: .leading, spacing: 10) {
                PixelText("THE GAMES", scale: 2, color: Pixel.muted, shadow: nil)
                ForEach(WebGame.allCases, id: \.self) { game in
                    HStack(spacing: 12) {
                        PixelSprite(art: game.sprite, scale: 2)
                            .frame(width: 26)
                        PixelText(game.title, scale: 2)
                        Spacer()
                    }
                }
                Text("The daily games are made by their own creators and open in an in-app browser. Sammy Word isn't affiliated with them.")
                    .font(Pixel.mono(11))
                    .foregroundColor(Pixel.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelBox(Pixel.row)

            HStack(spacing: 20) {
                Link("Support", destination: URL(string: "https://samarei.com/sammyword/support")!)
                Link("Privacy", destination: URL(string: "https://samarei.com/sammyword/privacy")!)
            }
            .font(Pixel.mono(13, .semibold))
            .tint(Pixel.gold)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 60)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PixelText("\(n)", scale: 3, color: Pixel.gold)
                .frame(width: 22)
            Text(text)
                .font(Pixel.mono(14, .medium))
                .foregroundColor(Pixel.cream)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelBox(Pixel.row)
    }
}
