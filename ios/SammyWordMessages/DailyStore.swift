import Foundation

/// Local, per-device persistence: the player's display name, shown on the
/// result bubbles they send.
enum DailyStore {
    private static let defaults = UserDefaults.standard
    private static let nameKey = "sw-name"

    static var playerName: String {
        get { defaults.string(forKey: nameKey) ?? "" }
        set { defaults.set(newValue, forKey: nameKey) }
    }
}
