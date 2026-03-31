import Foundation
import Testing
@testable import WorkPulse

@Suite("CurrentSessionCalculator")
struct CurrentSessionCalculatorTests {
    @Test
    func returnsElapsedDurationWhenStartTimeExistsAndSessionIsInProgress() throws {
        let calculator = CurrentSessionCalculator()
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:30+09:00")
        )

        let duration = calculator.runningDuration(
            startTime: startTime,
            now: now
        )

        #expect(duration == 9_930)
    }
}
