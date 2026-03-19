import Foundation
import Testing
@testable import WorkPulse

struct WeeklyWorkedTimeCalculatorTests {
    @Test("calculator returns nil when no record belongs to the current week")
    func calculatorReturnsNilWhenNoRecordBelongsToCurrentWeek() throws {
        let calendar = testCalendar()
        let calculator = WeeklyWorkedTimeCalculator(calendar: calendar)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let previousWeekStart = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 29, hour: 9, minute: 0))
        )
        let previousWeekEnd = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 29, hour: 18, minute: 0))
        )

        let workedDuration = calculator.workedDuration(
            records: [
                AttendanceRecord(startTime: previousWeekStart, endTime: previousWeekEnd)
            ],
            referenceDate: referenceDate
        )

        #expect(workedDuration == nil)
    }

    @Test("calculator sums this week's records and keeps the latest record for the same day")
    func calculatorSumsThisWeeksRecordsAndKeepsLatestRecordForSameDay() throws {
        let calendar = testCalendar()
        let calculator = WeeklyWorkedTimeCalculator(calendar: calendar)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
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
        let nextWeekStart = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 8, hour: 9, minute: 0))
        )
        let nextWeekEnd = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 8, hour: 12, minute: 0))
        )

        let workedDuration = try #require(
            calculator.workedDuration(
                records: [
                    AttendanceRecord(startTime: originalMondayStart, endTime: originalMondayEnd),
                    AttendanceRecord(startTime: updatedMondayStart, endTime: updatedMondayEnd),
                    AttendanceRecord(startTime: tuesdayStart, endTime: tuesdayEnd),
                    AttendanceRecord(startTime: nextWeekStart, endTime: nextWeekEnd)
                ],
                referenceDate: referenceDate
            )
        )

        let expectedDuration = TimeInterval(16 * 60 * 60)

        #expect(workedDuration == expectedDuration)
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
