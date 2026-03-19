import Foundation
import Testing
@testable import WorkPulse

struct WeeklyTargetProgressCalculatorTests {
    @Test("calculator returns nil when there is no weekly total")
    func calculatorReturnsNilWhenThereIsNoWeeklyTotal() {
        let calculator = WeeklyTargetProgressCalculator(
            targetDuration: WeeklyTargetConfiguration.standard.duration
        )

        let progress = calculator.progress(totalWorkedDuration: nil)

        #expect(progress == nil)
    }

    @Test("calculator returns remaining duration when weekly total is under target")
    func calculatorReturnsRemainingDurationWhenWeeklyTotalIsUnderTarget() throws {
        let calculator = WeeklyTargetProgressCalculator(
            targetDuration: WeeklyTargetConfiguration.standard.duration
        )

        let progress = try #require(
            calculator.progress(totalWorkedDuration: 31.5 * 60 * 60)
        )

        #expect(progress.totalWorkedDuration == 31.5 * 60 * 60)
        #expect(progress.status == .remaining(8.5 * 60 * 60))
    }

    @Test("calculator returns met state when weekly total reaches target")
    func calculatorReturnsMetStateWhenWeeklyTotalReachesTarget() throws {
        let calculator = WeeklyTargetProgressCalculator(
            targetDuration: WeeklyTargetConfiguration.standard.duration
        )

        let progress = try #require(
            calculator.progress(totalWorkedDuration: WeeklyTargetConfiguration.standard.duration)
        )

        #expect(progress.totalWorkedDuration == WeeklyTargetConfiguration.standard.duration)
        #expect(progress.status == .met)
    }

    @Test("calculator returns overtime duration when weekly total exceeds target")
    func calculatorReturnsOvertimeDurationWhenWeeklyTotalExceedsTarget() throws {
        let calculator = WeeklyTargetProgressCalculator(
            targetDuration: WeeklyTargetConfiguration.standard.duration
        )

        let progress = try #require(
            calculator.progress(totalWorkedDuration: 44.25 * 60 * 60)
        )

        #expect(progress.totalWorkedDuration == 44.25 * 60 * 60)
        #expect(progress.status == .overtime(4.25 * 60 * 60))
    }
}
