import CoreGraphics
import Foundation

struct MainPopoverCurrentSessionProgressPolicy {
    let goalDuration: TimeInterval
    let maximumVisibleFraction: CGFloat

    func fraction(for duration: TimeInterval?) -> CGFloat {
        guard let duration else { return 0 }

        let rawFraction = CGFloat(duration / goalDuration)
        if rawFraction >= 1 {
            return maximumVisibleFraction
        }

        return max(0, rawFraction)
    }
}
