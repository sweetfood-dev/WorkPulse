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

@Suite("AttendanceRecordTotalsCalculator")
struct AttendanceRecordTotalsCalculatorTests {
    @Test
    func weeklyTotalIncludesOnlyCompletedRecordsInSameWeek() throws {
        let calculator = AttendanceRecordTotalsCalculator()
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let records = [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-30T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T09:00:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T18:00:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T10:00:00+09:00")),
                endTime: nil
            ),
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-22T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-22T09:00:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-22T17:00:00+09:00"))
            )
        ]

        let total = calculator.weeklyTotal(
            records: records,
            referenceDate: referenceDate,
            calendar: Self.seoulCalendar
        )

        #expect(total == 32_400)
    }

    @Test
    func monthlyTotalIncludesOnlyCompletedRecordsInSameMonth() throws {
        let calculator = AttendanceRecordTotalsCalculator()
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let records = [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-03T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T09:00:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T18:00:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-04T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-04T09:30:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-04T18:00:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T09:00:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T17:00:00+09:00"))
            )
        ]

        let total = calculator.monthlyTotal(
            records: records,
            referenceDate: referenceDate,
            calendar: Self.seoulCalendar
        )

        #expect(total == 63_000)
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}
