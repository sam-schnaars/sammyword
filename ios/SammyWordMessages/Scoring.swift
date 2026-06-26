import Foundation

/// Word Hunt scoring. Length is the number of *letters* in the word, so the
/// "QU" tile contributes 2.
enum Scoring {
    static func points(forLength length: Int) -> Int {
        switch length {
        case ..<3: return 0
        case 3: return 100
        case 4: return 400
        case 5: return 800
        case 6: return 1400
        case 7: return 1800
        default: return 2200 // 8+ letters
        }
    }
}
