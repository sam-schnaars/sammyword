import Foundation

/// Local, per-device persistence — the iOS counterpart to the web app's
/// `localStorage` helpers in `share.js` / `leaderboard.js`:
///   - per-day personal best for the Map of the Day,
///   - the player's display name,
///   - a stable anonymous client id for the global leaderboard.
enum DailyStore {
    private static let defaults = UserDefaults.standard
    private static let nameKey = "sw-name"
    private static let clientKey = "sw-cid"

    // MARK: Per-day personal best

    static func best(_ day: String) -> Int {
        defaults.integer(forKey: "sw-best-" + day)
    }

    /// Save `score` if it beats the stored best for `day`. Returns true if it was
    /// a new best.
    @discardableResult
    static func saveBest(_ day: String, _ score: Int) -> Bool {
        guard score > best(day) else { return false }
        defaults.set(score, forKey: "sw-best-" + day)
        return true
    }

    // MARK: Player identity

    static var playerName: String {
        get { defaults.string(forKey: nameKey) ?? "" }
        set { defaults.set(newValue, forKey: nameKey) }
    }

    /// A stable anonymous id so the leaderboard can track this device's best.
    static var clientId: String {
        if let existing = defaults.string(forKey: clientKey) { return existing }
        let id = UUID().uuidString
        defaults.set(id, forKey: clientKey)
        return id
    }
}
