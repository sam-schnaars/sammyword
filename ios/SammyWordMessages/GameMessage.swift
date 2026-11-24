import Foundation

/// Every game in Sammy Word. Three are ours (Word Hunt, Flag Match, Doodle);
/// four are daily games that live on their creators' websites.
enum Game: String, Equatable, CaseIterable {
    case wordHunt = "w"      // trace words on today's letter grid, 80 s
    case flagMatch = "f"     // today's 12 flags, 60 s
    case doodle = "d"        // draw a secret word on a pixel grid; friends guess it
    case krillion = "k"      // krillion.io: daily rare-answer dive
    case magnitudle = "m"    // magnitudle.com/daily: one estimate a day, scored /100
    case hundredOfUs = "h"   // logicers.com/100-of-us: "of 100 people, how many…?"
    case eraly = "e"         // eraly.io: guess the year of 7 moments, up to 700

    /// Our own games, in menu order.
    static let own: [Game] = [.wordHunt, .flagMatch, .doodle]
    /// The daily games that live on other people's websites.
    static let web: [Game] = [.krillion, .magnitudle, .hundredOfUs, .eraly]

    /// Played on its creator's site rather than inside Sammy Word.
    var isWeb: Bool { Game.web.contains(self) }

    /// Has one puzzle a day (Doodle is turn-based instead).
    var isDaily: Bool { self != .doodle }

    var title: String {
        switch self {
        case .wordHunt: return "Word Hunt"
        case .flagMatch: return "Flag Match"
        case .doodle: return "Doodle"
        case .krillion: return "Krillion"
        case .magnitudle: return "Magnitudle"
        case .hundredOfUs: return "100 of Us"
        case .eraly: return "Eraly"
        }
    }

    var emoji: String {
        switch self {
        case .wordHunt: return "🔤"
        case .flagMatch: return "🚩"
        case .doodle: return "🎨"
        case .krillion: return "🦐"
        case .magnitudle: return "🧮"
        case .hundredOfUs: return "🌍"
        case .eraly: return "⏳"
        }
    }

    /// One line for the game menu.
    var blurb: String {
        switch self {
        case .wordHunt: return "Today's letter grid: drag to spell as many words as you can in 80 seconds"
        case .flagMatch: return "Today's 12 flags: name each country before the minute runs out"
        case .doodle: return "Draw a secret word in pixels, then see who in the chat can guess it"
        case .krillion: return "Today's dive: the rarer your answers, the bigger the score"
        case .magnitudle: return "One mind-bending number a day. Guess it, scored out of 100"
        case .hundredOfUs: return "Of 100 people in the world, how many…? Get closest"
        case .eraly: return "Seven moments from history: guess the year of each, up to 700"
        }
    }

    var invite: String {
        switch self {
        case .wordHunt: return "Hunt today's words with me"
        case .flagMatch: return "Name today's flags with me"
        case .doodle: return "Guess my doodle"
        case .krillion: return "Dive into today's Krillion with me"
        case .magnitudle: return "Try today's Magnitudle question"
        case .hundredOfUs: return "Guess today's 100 of Us with me"
        case .eraly: return "Time-travel through today's Eraly with me"
        }
    }

    /// Where a web game lives.
    var site: URL? {
        switch self {
        case .krillion: return URL(string: "https://krillion.io/")
        case .magnitudle: return URL(string: "https://magnitudle.com/daily")
        case .hundredOfUs: return URL(string: "https://logicers.com/100-of-us/")
        case .eraly: return URL(string: "https://eraly.io/")
        default: return nil
        }
    }

    /// The most a round can score, when there's a ceiling.
    var maxScore: Int? {
        switch self {
        case .flagMatch: return Flags.questions
        case .magnitudle: return 100
        case .eraly: return 700
        case .hundredOfUs: return 100
        default: return nil
        }
    }
}

/// A result (or an invite, when `score` is nil) traded in chat.
///
/// `score` is each game's headline number: Word Hunt points, Flag Match flags
/// right out of 12, Doodle guesses taken (0 = gave up), Krillion points,
/// Magnitudle points out of 100, Eraly points out of 700, and for 100 of Us how
/// far off the guess was (lower wins).
struct ScorePayload: Equatable {
    var game: Game
    var score: Int?
    var day: Int?             // puzzle number (ours: Sammy Word day; web: the site's own)
    var marks: [String] = []  // detail: Word Hunt best words; Krillion tiers; 100 of Us [guess, answer]; Eraly rounds; Doodle [word]
    var senderName: String?
    var drawing: String?      // Doodle: the 12×12 picture, one palette digit per cell
    var secret: Int?          // Doodle: the hidden word, lightly scrambled

    /// "1400", "9/12", "92/100", "off by 8", "got it in 2".
    var scoreText: String {
        guard let score else { return "" }
        switch game {
        case .wordHunt, .krillion: return String(score)
        case .flagMatch: return "\(score)/\(Flags.questions)"
        case .doodle: return score == 0 ? "gave up" : "got it in \(score)"
        case .magnitudle: return "\(score)/100"
        case .hundredOfUs: return score == 0 ? "spot on" : "off by \(score)"
        case .eraly: return "\(score)/700"
        }
    }

    /// "scored 92/100" / "was off by 8" / "guessed CAT in 2".
    var brag: String {
        switch game {
        case .hundredOfUs: return score == 0 ? "nailed it" : "was \(scoreText)"
        case .doodle:
            let word = marks.first.map { $0.uppercased() } ?? "it"
            return score == 0 ? "couldn't guess \(word)" : "guessed \(word) in \(score ?? 0)"
        case .flagMatch: return "named \(scoreText) flags"
        default: return "scored \(scoreText)"
        }
    }

    /// Bubble caption.
    var caption: String {
        let who = senderName ?? "I"
        if game == .doodle {
            if score == nil { return "\(who) drew something. Can you guess it?" }
            return "\(who) \(brag). Your turn to draw!"
        }
        guard score != nil else { return game.invite }
        return "\(who) \(brag) on \(game.title)\(day.map { " #\($0)" } ?? "") — your turn"
    }

    /// A Doodle to guess (rather than a finished guess).
    var isDoodlePrompt: Bool { game == .doodle && score == nil && drawing != nil }
}

enum GameMessage {
    /// Query keys: g = game letter, ks = score, kd = puzzle number,
    /// kr = detail ("."-joined), cn = sender name, dg = Doodle drawing,
    /// dw = Doodle secret word.
    static func encode(_ payload: ScorePayload) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "sammyword.app"
        components.path = "/play"
        var items = [URLQueryItem(name: "g", value: payload.game.rawValue)]
        if let score = payload.score { items.append(URLQueryItem(name: "ks", value: String(score))) }
        if let day = payload.day { items.append(URLQueryItem(name: "kd", value: String(day))) }
        if !payload.marks.isEmpty {
            items.append(URLQueryItem(name: "kr", value: payload.marks.joined(separator: ".")))
        }
        if let name = payload.senderName, !name.isEmpty {
            items.append(URLQueryItem(name: "cn", value: name))
        }
        if let drawing = payload.drawing { items.append(URLQueryItem(name: "dg", value: drawing)) }
        if let secret = payload.secret { items.append(URLQueryItem(name: "dw", value: String(secret))) }
        components.queryItems = items
        return components.url ?? URL(string: "https://sammyword.app/play")!
    }

    /// Unknown or older bubbles decode to nil, which simply opens the app fresh.
    static func decode(_ url: URL?) -> ScorePayload? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return nil }
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }
        guard let game = value("g").flatMap(Game.init(rawValue:)) else { return nil }
        return ScorePayload(
            game: game,
            score: value("ks").flatMap { Int($0) },
            day: value("kd").flatMap { Int($0) },
            marks: value("kr")?.split(separator: ".").map(String.init) ?? [],
            senderName: value("cn"),
            drawing: value("dg").flatMap { Doodle.isValidDrawing($0) ? $0 : nil },
            secret: value("dw").flatMap { Int($0) }
        )
    }
}
