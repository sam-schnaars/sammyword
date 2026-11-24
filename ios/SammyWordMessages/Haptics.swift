import UIKit

/// Impact feedback for scoring a word — heavier the longer the word, with a
/// satisfying double-thump for the big ones. (No-op on devices without a Taptic
/// Engine / in the simulator.)
enum Haptics {
    static func wordScored(length: Int) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        let intensity: CGFloat
        switch length {
        case ...3: style = .medium; intensity = 1.0
        case 4:    style = .heavy;  intensity = 0.9
        case 5:    style = .heavy;  intensity = 1.0
        case 6:    style = .heavy;  intensity = 1.0
        default:   style = .heavy;  intensity = 1.0   // 7+
        }

        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)

        // Longer words get a second (and, for the biggest, a third) beat for
        // extra payoff.
        if length >= 6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                let second = UIImpactFeedbackGenerator(style: .heavy)
                second.impactOccurred(intensity: 1.0)
            }
        }
        if length >= 8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                let third = UIImpactFeedbackGenerator(style: .heavy)
                third.impactOccurred(intensity: 1.0)
            }
        }
    }
}
