import Foundation

/// The Word Hunt state carried inside an `MSMessage.url`.
struct GamePayload: Equatable {
    var mapId: String                // which board shape
    var letters: [String]            // the playable tiles, in cell order
    var challengerScore: Int?        // score to beat (nil for a fresh board)
    var challengerName: String?
    var challengerWords: [String]    // the words the challenger found (uppercased)

    init(
        mapId: String,
        letters: [String],
        challengerScore: Int? = nil,
        challengerName: String? = nil,
        challengerWords: [String] = []
    ) {
        self.mapId = mapId
        self.letters = letters
        self.challengerScore = challengerScore
        self.challengerName = challengerName
        self.challengerWords = challengerWords
    }

    var isChallenge: Bool { challengerScore != nil }

    var map: GameMap { GameMap.map(id: mapId) }
    var board: GameBoard { GameBoard.from(map: map, letters: letters) }
}

/// The Flag Match state carried inside an `MSMessage.url`. A seed replays the
/// exact same quiz, so we only carry the seed + the challenger's score.
struct FlagPayload: Equatable {
    var seed: Int
    var challengerScore: Int?
    var challengerName: String?

    init(seed: Int, challengerScore: Int? = nil, challengerName: String? = nil) {
        self.seed = seed
        self.challengerScore = challengerScore
        self.challengerName = challengerName
    }

    var isChallenge: Bool { challengerScore != nil }
}

/// The Deep Cut state carried inside an `MSMessage.url`: the seed replays the
/// same prompts; `challengerAnswers` are the sender's locked-in answers (one per
/// prompt, "" for none) so the recipient sees them head-to-head.
struct DeepCutPayload: Equatable {
    var seed: Int
    var challengerScore: Int?
    var challengerName: String?
    var challengerAnswers: [String]

    init(seed: Int, challengerScore: Int? = nil, challengerName: String? = nil, challengerAnswers: [String] = []) {
        self.seed = seed
        self.challengerScore = challengerScore
        self.challengerName = challengerName
        self.challengerAnswers = challengerAnswers
    }

    var isChallenge: Bool { challengerScore != nil }
}

/// Which game a tapped message carries.
enum DecodedGame: Equatable {
    case wordHunt(GamePayload)
    case flagMatch(FlagPayload)
    case deepCut(DeepCutPayload)
}

enum GameMessage {
    /// Shared query keys: g = game ("w" Word Hunt default, "f" Flag Match),
    /// cs = challenger score, cn = challenger name.
    /// Word Hunt: m = map id, b = board (tiles joined by "-"), cw = words ("."-joined).
    /// Flag Match: fs = quiz seed.
    /// Deep Cut (g = "d"): ds = round seed, ca = answers ("|"-joined).
    static func encode(_ game: DecodedGame) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "sammyword.app"
        components.path = "/play"
        var items: [URLQueryItem] = []

        switch game {
        case let .wordHunt(payload):
            items.append(URLQueryItem(name: "m", value: payload.mapId))
            items.append(URLQueryItem(name: "b", value: payload.letters.joined(separator: "-")))
            if let score = payload.challengerScore {
                items.append(URLQueryItem(name: "cs", value: String(score)))
            }
            if let name = payload.challengerName, !name.isEmpty {
                items.append(URLQueryItem(name: "cn", value: name))
            }
            if !payload.challengerWords.isEmpty {
                items.append(URLQueryItem(name: "cw", value: payload.challengerWords.joined(separator: ".")))
            }
        case let .flagMatch(payload):
            items.append(URLQueryItem(name: "g", value: "f"))
            items.append(URLQueryItem(name: "fs", value: String(payload.seed)))
            if let score = payload.challengerScore {
                items.append(URLQueryItem(name: "cs", value: String(score)))
            }
            if let name = payload.challengerName, !name.isEmpty {
                items.append(URLQueryItem(name: "cn", value: name))
            }
        case let .deepCut(payload):
            items.append(URLQueryItem(name: "g", value: "d"))
            items.append(URLQueryItem(name: "ds", value: String(payload.seed)))
            if let score = payload.challengerScore {
                items.append(URLQueryItem(name: "cs", value: String(score)))
            }
            if let name = payload.challengerName, !name.isEmpty {
                items.append(URLQueryItem(name: "cn", value: name))
            }
            if !payload.challengerAnswers.isEmpty {
                items.append(URLQueryItem(name: "ca", value: payload.challengerAnswers.joined(separator: "|")))
            }
        }

        components.queryItems = items
        return components.url ?? URL(string: "https://sammyword.app/play")!
    }

    static func decode(_ url: URL?) -> DecodedGame? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return nil }

        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }

        let score = value("cs").flatMap { Int($0) }
        let name = value("cn")

        // Flag Match challenge.
        if value("g") == "f" {
            guard let seed = value("fs").flatMap({ Int($0) }) else { return nil }
            return .flagMatch(FlagPayload(seed: seed, challengerScore: score, challengerName: name))
        }

        // Deep Cut challenge.
        if value("g") == "d" {
            guard let seed = value("ds").flatMap({ Int($0) }) else { return nil }
            let answers = value("ca")?
                .split(separator: "|", omittingEmptySubsequences: false)
                .map(String.init) ?? []
            return .deepCut(DeepCutPayload(
                seed: seed, challengerScore: score, challengerName: name, challengerAnswers: answers
            ))
        }

        // Word Hunt (default).
        guard let boardString = value("b") else { return nil }
        let letters = boardString
            .split(separator: "-", omittingEmptySubsequences: false)
            .map { $0.uppercased() }
        let mapId = value("m") ?? "classic"
        let map = GameMap.map(id: mapId)
        guard letters.count == map.activeCount else { return nil }
        let words = value("cw")?
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { $0.uppercased() } ?? []
        return .wordHunt(GamePayload(
            mapId: map.id,
            letters: letters,
            challengerScore: score,
            challengerName: name,
            challengerWords: words
        ))
    }
}
