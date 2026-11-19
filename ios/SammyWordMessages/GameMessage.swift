import Foundation

/// A daily web game that runs on its own site inside the iMessage app (we host
/// the real site in a web view and only trade the finished result).
enum WebGame: String, Equatable, CaseIterable {
    case krillion = "k"      // krillion.io: daily rare-answer dive
    case magnitudle = "m"    // magnitudle.com/daily: one estimate a day, scored /100
    case hundredOfUs = "h"   // logicers.com/100-of-us: "of 100 people, how many…?"
    case eraly = "e"         // eraly.io: guess the year of 7 moments, up to 700

    var title: String {
        switch self {
        case .krillion: return "Krillion"
        case .magnitudle: return "Magnitudle"
        case .hundredOfUs: return "100 of Us"
        case .eraly: return "Eraly"
        }
    }

    var emoji: String {
        switch self {
        case .krillion: return "🦐"
        case .magnitudle: return "🧮"
        case .hundredOfUs: return "🌍"
        case .eraly: return "⏳"
        }
    }

    /// One line for the game menu.
    var blurb: String {
        switch self {
        case .krillion: return "Today's dive: the rarer your answers, the bigger the score"
        case .magnitudle: return "One mind-bending number a day. Guess it, scored out of 100"
        case .hundredOfUs: return "Of 100 people in the world, how many…? Get closest"
        case .eraly: return "Seven moments from history: guess the year of each, up to 700"
        }
    }

    var invite: String {
        switch self {
        case .krillion: return "Dive into today's Krillion with me"
        case .magnitudle: return "Try today's Magnitudle question"
        case .hundredOfUs: return "Guess today's 100 of Us with me"
        case .eraly: return "Time-travel through today's Eraly with me"
        }
    }
}

/// A web-game result traded in chat (nil score = a plain invite).
///
/// `score` is the game's own headline number: Krillion points, Magnitudle
/// points out of 100, Eraly points out of 700, and for 100 of Us how far off
/// the guess was (lower wins).
struct WebScorePayload: Equatable {
    var game: WebGame
    var score: Int?
    var day: Int?             // the site's own puzzle number
    var marks: [String] = []  // detail: Krillion tier ids; 100 of Us [guess, answer]; Eraly round points
    var senderName: String?

    /// "465", "92/100", or "off by 8".
    var scoreText: String {
        guard let score else { return "" }
        switch game {
        case .krillion: return String(score)
        case .magnitudle: return "\(score)/100"
        case .hundredOfUs: return score == 0 ? "spot on" : "off by \(score)"
        case .eraly: return "\(score)/700"
        }
    }

    /// "scored 92/100" / "was off by 8" / "nailed it".
    var brag: String {
        guard game == .hundredOfUs else { return "scored \(scoreText)" }
        return score == 0 ? "nailed it" : "was \(scoreText)"
    }

    /// Bubble caption.
    var caption: String {
        guard score != nil else { return game.invite }
        return "\(senderName ?? "I") \(brag) on \(game.title)\(day.map { " #\($0)" } ?? "") — your turn"
    }
}

enum GameMessage {
    /// Query keys: g = game ("k" Krillion, "m" Magnitudle, "h" 100 of Us,
    /// "e" Eraly),
    /// ks = score, kd = puzzle number, kr = detail ("."-joined), cn = sender name.
    static func encode(_ payload: WebScorePayload) -> URL {
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
        components.queryItems = items
        return components.url ?? URL(string: "https://sammyword.app/play")!
    }

    /// Bubbles from games that were removed (Word Hunt, Flag Match, Deep Cut,
    /// Size It Up) decode to nil, which simply opens the app fresh.
    static func decode(_ url: URL?) -> WebScorePayload? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return nil }
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }
        guard let game = value("g").flatMap(WebGame.init(rawValue:)) else { return nil }
        return WebScorePayload(
            game: game,
            score: value("ks").flatMap { Int($0) },
            day: value("kd").flatMap { Int($0) },
            marks: value("kr")?.split(separator: ".").map(String.init) ?? [],
            senderName: value("cn")
        )
    }
}
