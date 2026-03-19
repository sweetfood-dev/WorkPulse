import Foundation
import Testing
@testable import WorkPulse

struct AttendanceDayMatcherTests {
    @Test("isInSameDay returns true when two times are on the same local calendar day")
    func isInSameDayReturnsTrueForSameDay() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let matcher = AttendanceDayMatcher(calendar: calendar)

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let sameDayDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 8, minute: 30))
        )

        #expect(matcher.isInSameDay(sameDayDate, as: referenceDate))
    }

    @Test("isInSameDay returns false when two times are on different local calendar days")
    func isInSameDayReturnsFalseForDifferentDay() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let matcher = AttendanceDayMatcher(calendar: calendar)

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let differentDayDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 23, minute: 59))
        )

        #expect(!matcher.isInSameDay(differentDayDate, as: referenceDate))
    }
}
