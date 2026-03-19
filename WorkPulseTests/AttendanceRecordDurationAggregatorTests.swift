import Foundation
import Testing
@testable import WorkPulse

struct AttendanceRecordDurationAggregatorTests {
    @Test("aggregator sums durations and keeps the latest record for the same day")
    func aggregatorSumsDurationsAndKeepsTheLatestRecordForTheSameDay() throws {
        let calendar = testCalendar()
        let aggregator = AttendanceRecordDurationAggregator(calendar: calendar)
        let originalMondayStart = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let originalMondayEnd = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let updatedMondayStart = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 30))
        )
        let updatedMondayEnd = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 19, minute: 0))
        )
        let tuesdayStart = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 10, minute: 0))
        )
        let tuesdayEnd = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 16, minute: 30))
        )

        let workedDuration = try #require(
            aggregator.workedDuration(records: [
                AttendanceRecord(startTime: originalMondayStart, endTime: originalMondayEnd),
                AttendanceRecord(startTime: updatedMondayStart, endTime: updatedMondayEnd),
                AttendanceRecord(startTime: tuesdayStart, endTime: tuesdayEnd)
            ])
        )

        #expect(workedDuration == TimeInterval(16 * 60 * 60))
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
