import SwiftUI

/// A daily game that lives on its creator's website (Krillion, Magnitudle,
/// 100 of Us, Eraly). Sammy Word doesn't show the site: it opens it in Safari,
/// and when you come back you paste the game's share text (or type your score)
/// to post a bubble to the chat.
struct ExternalGameView: View {
    let game: Game
    let incoming: ScorePayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    @State private var scoreText = ""
    @State private var day: Int?
    @State private var status: SendStatus = .idle
    @FocusState private var typing: Bool

    private var playedToday: String? { DailyStore.played(game) }

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(game: game, onHome: onHome)
            ScrollView {
                VStack(spacing: 18) {
                    if let friend = incoming { FriendBanner(friend: friend) }
                    card
                    PixelActionButton(title: "▶ PLAY ON \(host)") {
                        if let site = game.site { session.openURL(site) }
                    }
                    report
                }
                .padding(18)
            }
        }
    }

    private var host: String {
        (game.site?.host ?? game.title).replacingOccurrences(of: "www.", with: "").uppercased()
    }

    private var card: some View {
        VStack(spacing: 12) {
            PixelSprite(art: game.sprite, scale: 6)
            PixelText(game.title, scale: 3.5)
            Text(game.blurb)
                .font(Pixel.mono(13))
                .foregroundColor(Pixel.muted)
                .multilineTextAlignment(.center)
            Text("Made by its own creators. It opens on their website in Safari.")
                .font(Pixel.mono(11))
                .foregroundColor(Pixel.muted.opacity(0.8))
                .multilineTextAlignment(.center)
            if let done = playedToday {
                PixelText("✓ TODAY: \(done)", scale: 2, color: Pixel.green)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .pixelBox(Pixel.panel, step: 4)
    }

    // MARK: Reporting a score

    private var report: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText("BACK FROM PLAYING?", scale: 2, color: Pixel.gold)
            Text("Use the game's Share button, then paste it here. Or just type your score.")
                .font(Pixel.mono(12))
                .foregroundColor(Pixel.muted)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    PixelText(scoreLabel, scale: 1.5, color: Pixel.muted, shadow: nil)
                    TextField("", text: $scoreText, prompt: Text("0").foregroundColor(Pixel.muted.opacity(0.5)))
                        .font(Pixel.mono(22, .bold))
                        .foregroundColor(Pixel.cream)
                        .keyboardType(.numberPad)
                        .focused($typing)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .pixelBox(Pixel.row, step: 2)
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    let parsed = ScoreParser.parse(text, for: game)
                    DispatchQueue.main.async {
                        if let s = parsed.score { scoreText = String(s) }
                        day = parsed.day
                    }
                }
                .tint(Color(hex: 0x3D3478))
                .labelStyle(.titleAndIcon)
            }
            NameField()
            SendButton(title: "SEND \(game.title) SCORE", payload: payload, session: session, status: $status,
                       onSend: { typing = false; DailyStore.record(payload) })
                .disabled(score == nil)
                .opacity(score == nil ? 0.5 : 1)
        }
        .padding(14)
        .pixelBox(Pixel.row, step: 3)
    }

    private var scoreLabel: String {
        switch game {
        case .magnitudle: return "SCORE OUT OF 100"
        case .eraly: return "SCORE OUT OF 700"
        case .hundredOfUs: return "HOW FAR OFF WERE YOU?"
        default: return "YOUR SCORE"
        }
    }

    /// The typed score, if it's a sensible number for this game.
    private var score: Int? {
        guard let n = Int(scoreText.filter(\.isNumber)) else { return nil }
        if let max = game.maxScore, n > max { return nil }
        return n
    }

    private var payload: ScorePayload {
        ScorePayload(game: game, score: score, day: day)
    }
}

/// Reads a score (and puzzle number) out of a game's pasted share text. The
/// player can always correct the number before sending.
enum ScoreParser {
    static func parse(_ text: String, for game: Game) -> (score: Int?, day: Int?) {
        let day = first(#"#\s*(\d+)"#, in: text) ?? first(#"(?i)day\s*(\d+)"#, in: text)
        let score: Int?
        switch game {
        case .magnitudle: score = first(#"(\d+)\s*/\s*100\b"#, in: text)
        case .eraly: score = first(#"(\d+)\s*/\s*700\b"#, in: text)
        case .hundredOfUs: score = first(#"(?i)off by\s*(\d+)"#, in: text)
            ?? (text.range(of: "spot on", options: .caseInsensitive) != nil ? 0 : nil)
        default: score = first(#"(?i)(\d[\d,]*)\s*(?:pts|points)"#, in: text)
            ?? first(#"(?i)score\D{0,3}(\d[\d,]*)"#, in: text)
        }
        return (score ?? firstLooseNumber(text, skipping: day), day)
    }

    private static func first(_ pattern: String, in text: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text)
        else { return nil }
        return Int(text[r].filter(\.isNumber))
    }

    /// Last resort: the first number in the text that isn't the puzzle number.
    private static func firstLooseNumber(_ text: String, skipping day: Int?) -> Int? {
        guard let re = try? NSRegularExpression(pattern: #"(?<![#\d])(\d[\d,]*)"#) else { return nil }
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let r = Range(m.range(at: 1), in: text), let n = Int(text[r].filter(\.isNumber)) else { continue }
            if n != day { return n }
        }
        return nil
    }
}
