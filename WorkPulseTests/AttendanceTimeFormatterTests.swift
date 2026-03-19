import Foundation
import Testing
@testable import WorkPulse

struct AttendanceTimeFormatterTests {
    @Test("time formatter renders HH:mm")
    func timeFormatterRendersHourMinute() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = AttendanceTimeFormatter(calendar: calendar)
        let date = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 3))
        )

        #expect(formatter.string(from: date) == "09:03")
    }

    @Test("time formatter follows calendar time zone")
    func timeFormatterFollowsCalendarTimeZone() {
        let date = Date(timeIntervalSince1970: 0)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let utcFormatter = AttendanceTimeFormatter(calendar: utcCalendar)

        var seoulCalendar = Calendar(identifier: .gregorian)
        seoulCalendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let seoulFormatter = AttendanceTimeFormatter(calendar: seoulCalendar)

        #expect(utcFormatter.string(from: date) == "00:00")
        #expect(seoulFormatter.string(from: date) == "09:00")
    }
}
