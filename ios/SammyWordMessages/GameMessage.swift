import Foundation

/// The game state carried inside an `MSMessage.url`. Everything is
/// URL-serializable so the whole turn lives in the message itself (like
/// GamePigeon). No Messages/UIKit imports here — just URL plumbing.
struct GamePayload: Equatable {
    var letters: [String]            // the 16 tiles
    var challengerScore: Int?        // score to beat (nil for a fresh board)
    var challengerName: String?

    var isChallenge: Bool { challengerScore != nil }

    var board: GameBoard { GameBoard.from(letters: letters) }
}

enum GameMessage {
    /// Query keys: b = board (tiles joined by "-"), cs = challenger score,
    /// cn = challenger name.
    static func encode(_ payload: GamePayload) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "sammyword.app"
        components.path = "/play"
        var items = [URLQueryItem(name: "b", value: payload.letters.joined(separator: "-"))]
        if let score = payload.challengerScore {
            items.append(URLQueryItem(name: "cs", value: String(score)))
        }
        if let name = payload.challengerName, !name.isEmpty {
            items.append(URLQueryItem(name: "cn", value: name))
        }
        components.queryItems = items
        // Fall back to a minimal URL if components somehow fails to compose.
        return components.url ?? URL(string: "https://sammyword.app/play")!
    }

    static func decode(_ url: URL?) -> GamePayload? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return nil }

        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }

        guard let boardString = value("b") else { return nil }
        let letters = boardString
            .split(separator: "-", omittingEmptySubsequences: false)
            .map { $0.uppercased() }
        guard letters.count == GameBoard.cellCount else { return nil }

        let score = value("cs").flatMap { Int($0) }
        let name = value("cn")
        return GamePayload(letters: letters, challengerScore: score, challengerName: name)
    }
}
