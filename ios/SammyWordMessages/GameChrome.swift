import SwiftUI

/// Shared pixel-art pieces for the game screens: the top bar, the friend's
/// score to beat, the big score card and the send button.

/// Top bar: back to the home screen, the game's sprite and title, and an
/// optional item on the right (a timer, a score).
struct GameHeader<Trailing: View>: View {
    let game: Game
    let onHome: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onHome) {
                PixelText("◀", scale: 2, color: Pixel.cream)
                    .padding(.horizontal, 6).padding(.vertical, 4)
            }
            .buttonStyle(PixelButtonStyle(palette: Pixel.row, step: 2))
            PixelSprite(art: game.sprite, scale: 2)
            PixelText(game.title, scale: 2)
            Spacer(minLength: 4)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

extension GameHeader where Trailing == EmptyView {
    init(game: Game, onHome: @escaping () -> Void) {
        self.init(game: game, onHome: onHome) { EmptyView() }
    }
}

/// A small boxed stat, e.g. TIME 0:42.
struct PixelStat: View {
    let label: String
    let value: String
    var warn = false

    var body: some View {
        VStack(spacing: 4) {
            PixelText(label, scale: 1.5, color: Pixel.muted, shadow: nil)
            PixelText(value, scale: 2.5, color: warn ? Color(hex: 0xFF6B6B) : Pixel.cream)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .pixelBox(warn ? PixelPalette(fill: 0x3A1424, light: 0x8A2030, dark: 0x200A12) : Pixel.row, step: 2)
    }
}

/// "ALEX: 1400 · BEAT IT" — shown when a game was opened from a friend's bubble.
struct FriendBanner: View {
    let friend: ScorePayload

    var body: some View {
        if friend.score != nil {
            HStack(spacing: 8) {
                PixelText("★", scale: 2, color: Pixel.gold)
                Text("\(friend.senderName ?? "A friend") \(friend.brag). Beat it!")
                    .font(Pixel.mono(13, .bold))
                    .foregroundColor(Pixel.cream)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(10)
            .pixelBox(Pixel.featured, step: 2)
        }
    }
}

/// The end-of-round card: a big headline number with a line under it.
struct ScoreCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            PixelText(title, scale: 2, color: Pixel.gold)
            PixelText(value, scale: 7)
            Text(detail)
                .font(Pixel.mono(13))
                .foregroundColor(Pixel.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .pixelBox(Pixel.featured, step: 4)
    }
}

/// How sending a bubble went.
enum SendStatus: Equatable {
    case idle, sending, sent
    case staged   // Messages said no; the bubble waits in the text field
}

/// Puts a result into the conversation. Sends straight away where Messages
/// allows it; otherwise the bubble is left in the text field, one tap on the
/// send arrow from sent.
enum Delivery {
    static func send(_ payload: ScorePayload, session: GameSession, status: Binding<SendStatus>) {
        guard status.wrappedValue != .sending else { return }
        var mine = payload
        let name = DailyStore.playerName.trimmingCharacters(in: .whitespaces)
        mine.senderName = name.isEmpty ? nil : name
        status.wrappedValue = .sending
        session.sendNow(mine) { failure in
            status.wrappedValue = failure == nil ? .sent : .staged
        }
    }
}

/// The big green "send to the chat" button, which reports how sending went.
struct SendButton: View {
    let title: String
    let payload: ScorePayload
    @ObservedObject var session: GameSession
    @Binding var status: SendStatus
    /// Runs just before sending (e.g. to record today's result).
    var onSend: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            Button { onSend(); Delivery.send(payload, session: session, status: $status) } label: {
                PixelText(label, scale: 2.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PixelButtonStyle(palette: status == .sent ? Pixel.row : Pixel.button, step: 3))
            .disabled(status == .sending || status == .sent)
            if status == .staged {
                Text("It's waiting in the text field. Tap the send arrow.")
                    .font(Pixel.mono(12))
                    .foregroundColor(Pixel.muted)
            }
        }
    }

    private var label: String {
        switch status {
        case .idle, .staged: return title
        case .sending: return "SENDING..."
        case .sent: return "SENT ✓"
        }
    }
}

/// The player's name, shown on the bubbles they send.
struct NameField: View {
    var prompt = "Your name"
    @State private var name = DailyStore.playerName

    var body: some View {
        HStack(spacing: 10) {
            PixelText("NAME", scale: 1.5, color: Pixel.muted, shadow: nil)
            TextField("", text: $name, prompt: Text(prompt).foregroundColor(Pixel.muted.opacity(0.6)))
                .font(Pixel.mono(15, .bold))
                .foregroundColor(Pixel.cream)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onChange(of: name) { DailyStore.playerName = $0 }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .pixelBox(Pixel.row, step: 2)
    }
}

/// A full-width pixel button with a label.
struct PixelActionButton: View {
    let title: String
    var palette: PixelPalette = Pixel.button
    var scale: CGFloat = 2.5
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PixelText(title, scale: scale)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(PixelButtonStyle(palette: palette, step: 3))
    }
}

func clockText(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
