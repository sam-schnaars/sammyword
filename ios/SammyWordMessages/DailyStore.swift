import Foundation

/// Local, per-device persistence: the player's display name, shown on the
/// result bubbles they send, and which games they've finished each day.
enum DailyStore {
    private static let defaults = UserDefaults.standard
    private static let nameKey = "sw-name"
    private static let playedKey = "sw-played"   // ["2026-11-18|k": "465"]

    /// A random id for this device, sent to the caption board so it can allow
    /// one caption and one vote a day. Not tied to the player in any other way.
    static var clientId: String {
        if let id = defaults.string(forKey: "sw-cid") { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: "sw-cid")
        return id
    }

    /// Caption authors this player reported; their captions stay hidden here.
    static var mutedAuthors: Set<String> {
        get { Set(defaults.stringArray(forKey: "sw-muted") ?? []) }
        set { defaults.set(Array(newValue), forKey: "sw-muted") }
    }

    static var playerName: String {
        get { defaults.string(forKey: nameKey) ?? "" }
        set { defaults.set(newValue, forKey: nameKey) }
    }

    /// The score text of `game` finished on `date`, or nil if not played.
    static func played(_ game: Game, on date: Date = Date()) -> String? {
        let all = defaults.dictionary(forKey: playedKey) as? [String: String] ?? [:]
        return all["\(Daily.stamp(date))|\(game.rawValue)"]
    }

    /// Remember today's result (keeps about two months).
    static func record(_ result: ScorePayload, on date: Date = Date()) {
        var all = defaults.dictionary(forKey: playedKey) as? [String: String] ?? [:]
        all["\(Daily.stamp(date))|\(result.game.rawValue)"] = result.scoreText
        let cutoff = Daily.stamp(Daily.calendar.date(byAdding: .day, value: -60, to: date) ?? date)
        all = all.filter { $0.key >= cutoff }
        defaults.set(all, forKey: playedKey)
    }
}

/// Game of the day: Sammy Word features one of its games each day, in turn.
enum Daily {
    static var calendar: Calendar { Calendar.current }

    /// Day 1 = 18 Nov 2026, the day the game of the day started.
    static func number(_ date: Date = Date()) -> Int {
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18)) ?? date
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        return days + 1
    }

    /// The games that take turns being featured. App Store builds feature only
    /// our own games (the web ones are listed below them); TestFlight builds
    /// rotate through the web games too.
    #if HOSTED_EMBED
    static let rotation: [Game] = [.wordHunt, .krillion, .flagMatch, .magnitudle, .hundredOfUs, .eraly]
    #else
    static let rotation: [Game] = [.wordHunt, .flagMatch]
    #endif

    static func game(for date: Date = Date()) -> Game {
        let all = rotation
        let i = ((number(date) - 1) % all.count + all.count) % all.count
        return all[i]
    }

    /// "TUE NOV 18".
    static func label(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.dateFormat = "EEE MMM d"
        return f.string(from: date).uppercased()
    }

    /// Days in a row the game of the day was finished. Today not being played
    /// yet doesn't break the run.
    static func streak(_ today: Date = Date()) -> Int {
        var day = today
        if DailyStore.played(game(for: day), on: day) == nil {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var n = 0
        while n < 400, DailyStore.played(game(for: day), on: day) != nil {
            n += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return n
    }

    /// "2026-11-18" in the local calendar (sorts as text).
    static func stamp(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
