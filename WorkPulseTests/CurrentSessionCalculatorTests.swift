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

        let duration = calculator.sessionDuration(
            startTime: startTime,
            endTime: nil,
            now: now
        )

        #expect(duration == 9_930)
    }

    @Test
    func returnsFixedDurationWhenEndTimeExists() throws {
        let calculator = CurrentSessionCalculator()
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let laterNow = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T20:00:00+09:00")
        )

        let duration = calculator.sessionDuration(
            startTime: startTime,
            endTime: endTime,
            now: laterNow
        )

        #expect(duration == 34_200)
    }
}
