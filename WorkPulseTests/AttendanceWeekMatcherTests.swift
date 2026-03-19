import Foundation
import Testing
@testable import WorkPulse

struct AttendanceWeekMatcherTests {
    @Test("matcher returns true when the date belongs to the same week interval")
    func matcherReturnsTrueForDateInSameWeekInterval() throws {
        let calendar = testCalendar()
        let matcher = AttendanceWeekMatcher(calendar: calendar)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let mondayMorning = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )

        #expect(matcher.contains(mondayMorning, inSameWeekAs: referenceDate))
    }

    @Test("matcher returns false when the date is outside the reference week interval")
    func matcherReturnsFalseForDateOutsideReferenceWeekInterval() throws {
        let calendar = testCalendar()
        let matcher = AttendanceWeekMatcher(calendar: calendar)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let nextWeekBoundary = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 8, hour: 0, minute: 0))
        )

        #expect(!matcher.contains(nextWeekBoundary, inSameWeekAs: referenceDate))
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
