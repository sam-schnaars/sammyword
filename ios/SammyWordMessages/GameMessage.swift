import Foundation

/// Every game in Sammy Word. Three are ours (Word Hunt, Flag Match, Caption the Meme);
/// four are daily games that live on their creators' websites.
enum Game: String, Equatable, CaseIterable {
    case wordHunt = "w"      // trace words on today's letter grid, 30 s
    case flagMatch = "f"     // today's 5 flags, 60 s
    case captionMeme = "c"   // caption today's pixel-art meme; friends answer with theirs
    case krillion = "k"      // krillion.io: daily rare-answer dive
    case magnitudle = "m"    // magnitudle.com/daily: one estimate a day, scored /100
    case hundredOfUs = "h"   // logicers.com/100-of-us: "of 100 people, how many…?"
    case eraly = "e"         // eraly.io: guess the year of 7 moments, up to 700

    /// Our own games, in menu order.
    static let own: [Game] = [.wordHunt, .flagMatch, .captionMeme]
    /// The daily games that live on other people's websites.
    static let web: [Game] = [.krillion, .magnitudle, .hundredOfUs, .eraly]

    /// Played on its creator's site rather than inside Sammy Word.
    var isWeb: Bool { Game.web.contains(self) }

    /// Has one puzzle a day.
    var isDaily: Bool { true }

    var title: String {
        switch self {
        case .wordHunt: return "Word Hunt"
        case .flagMatch: return "Flag Match"
        case .captionMeme: return "Caption the Meme"
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
        case .captionMeme: return "🖼️"
        case .krillion: return "🦐"
        case .magnitudle: return "🧮"
        case .hundredOfUs: return "🌍"
        case .eraly: return "⏳"
        }
    }

    /// One line for the game menu.
    var blurb: String {
        switch self {
        case .wordHunt: return "Today's letter grid: drag to spell as many words as you can in 30 seconds"
        case .flagMatch: return "Today's 5 flags: name each country before the minute runs out"
        case .captionMeme: return "Today's meme, the same for everyone: write the funniest caption"
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
        case .captionMeme: return "Caption today's meme with me"
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
/// right out of 5, Krillion points,
/// Magnitudle points out of 100, Eraly points out of 700, and for 100 of Us how
/// far off the guess was (lower wins). Caption the Meme has no score: the
/// caption itself (`captionText`) is the result.
struct ScorePayload: Equatable {
    var game: Game
    var score: Int?
    var day: Int?             // puzzle number (ours: Sammy Word day; web: the site's own)
    var marks: [String] = []  // detail: Word Hunt best words; Krillion tiers; 100 of Us [guess, answer]; Eraly rounds
    var senderName: String?
    var captionText: String?  // Caption the Meme: the caption written for day `day`

    /// "1400", "4/5", "92/100", "off by 8", "captioned".
    var scoreText: String {
        guard let score else { return "" }
        switch game {
        case .wordHunt, .krillion: return String(score)
        case .captionMeme: return "captioned"
        case .flagMatch: return "\(score)/\(Flags.questions)"
        case .magnitudle: return "\(score)/100"
        case .hundredOfUs: return score == 0 ? "spot on" : "off by \(score)"
        case .eraly: return "\(score)/700"
        }
    }

    /// "scored 92/100" / "was off by 8" / "captioned today's meme".
    var brag: String {
        switch game {
        case .hundredOfUs: return score == 0 ? "nailed it" : "was \(scoreText)"
        case .captionMeme: return "captioned today's meme"
        case .flagMatch: return "named \(scoreText) flags"
        default: return "scored \(scoreText)"
        }
    }

    /// Bubble caption.
    var caption: String {
        let who = senderName ?? "I"
        if game == .captionMeme {
            guard let text = captionText else { return game.invite }
            return "\(who) captioned today's meme: \u{201C}\(text)\u{201D} Your turn"
        }
        guard score != nil else { return game.invite }
        return "\(who) \(brag) on \(game.title)\(day.map { " #\($0)" } ?? "") — your turn"
    }
}

enum GameMessage {
    /// Query keys: g = game letter, ks = score, kd = puzzle number,
    /// kr = detail ("."-joined), cn = sender name,
    /// ct = Caption the Meme caption.
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
        if let text = payload.captionText { items.append(URLQueryItem(name: "ct", value: text)) }
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
            captionText: value("ct").map(Caption.clean).flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}
