import CoreGraphics
import Foundation

struct MainPopoverCurrentSessionProgressPolicy {
    static let defaultGoalDuration: TimeInterval = 8 * 60 * 60
    static let defaultMaximumVisibleFraction: CGFloat = 0.94

    let goalDuration: TimeInterval
    let maximumVisibleFraction: CGFloat

    init(
        goalDuration: TimeInterval = Self.defaultGoalDuration,
        maximumVisibleFraction: CGFloat = Self.defaultMaximumVisibleFraction
    ) {
        self.goalDuration = goalDuration
        self.maximumVisibleFraction = maximumVisibleFraction
    }

    func fraction(for duration: TimeInterval?) -> CGFloat {
        guard let duration else { return 0 }

        let rawFraction = CGFloat(duration / goalDuration)
        if rawFraction >= 1 {
            return maximumVisibleFraction
        }

        return max(0, rawFraction)
    }

    func isOverGoal(_ duration: TimeInterval?) -> Bool {
        guard let duration else { return false }
        return displayedWholeSeconds(duration) > goalDuration
    }

    private func displayedWholeSeconds(_ duration: TimeInterval) -> TimeInterval {
        TimeInterval(max(0, Int(duration.rounded(.down))))
    }
}
