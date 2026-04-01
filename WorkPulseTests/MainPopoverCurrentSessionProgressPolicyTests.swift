import CoreGraphics
import Testing
@testable import WorkPulse

@Suite("MainPopoverCurrentSessionProgressPolicy")
struct MainPopoverCurrentSessionProgressPolicyTests {
    private let policy = MainPopoverCurrentSessionProgressPolicy()

    @Test
    func returnsZeroForMissingDuration() {
        #expect(policy.fraction(for: nil) == 0)
    }

    @Test
    func clampsOverGoalDurationToConfiguredVisibleFraction() {
        #expect(policy.fraction(for: 9.5 * 60 * 60) == MainPopoverCurrentSessionProgressPolicy.defaultMaximumVisibleFraction)
    }

    @Test
    func treatsOnlyStrictlyGreaterThanGoalAsOvertime() {
        #expect(policy.isOverGoal(8 * 60 * 60) == false)
        #expect(policy.isOverGoal((8 * 60 * 60) + 1) == true)
    }
}
