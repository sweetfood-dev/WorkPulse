import Foundation
import Testing
@testable import WorkPulse

struct AttendanceMonthMatcherTests {
    @Test("matcher returns true for dates within the same month")
    func matcherReturnsTrueForDatesWithinTheSameMonth() throws {
        let calendar = testCalendar()
        let matcher = AttendanceMonthMatcher(calendar: calendar)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 15, hour: 12, minute: 0))
        )
        let dateInSameMonth = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )

        #expect(matcher.contains(dateInSameMonth, inSameMonthAs: referenceDate))
    }

    @Test("matcher returns false for dates outside the month")
    func matcherReturnsFalseForDatesOutsideTheMonth() throws {
        let calendar = testCalendar()
        let matcher = AttendanceMonthMatcher(calendar: calendar)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 15, hour: 12, minute: 0))
        )
        let dateOutsideMonth = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 12, minute: 0))
        )

        #expect(!matcher.contains(dateOutsideMonth, inSameMonthAs: referenceDate))
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
