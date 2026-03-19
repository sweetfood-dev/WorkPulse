import Foundation
import Testing
@testable import WorkPulse

struct AttendanceTimeStoreTodayRecordTests {
    @Test("todayRecord returns nil when no start time exists")
    func todayRecordReturnsNilWhenNoStartTimeExists() throws {
        let store = InMemoryAttendanceTimeStore()
        let matcher = AttendanceDayMatcher(calendar: testCalendar())
        let referenceDate = try #require(
            testCalendar().date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )

        #expect(
            store.todayRecord(referenceDate: referenceDate, dayMatcher: matcher) == nil
        )
    }

    @Test("todayRecord returns nil when saved start time is from a different day")
    func todayRecordReturnsNilForDifferentDayStartTime() throws {
        let calendar = testCalendar()
        let matcher = AttendanceDayMatcher(calendar: calendar)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let previousDayStart = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let store = InMemoryAttendanceTimeStore()
        store.startTime = previousDayStart

        #expect(
            store.todayRecord(referenceDate: referenceDate, dayMatcher: matcher) == nil
        )
    }

    @Test("todayRecord returns start and end time when saved start time is from today")
    func todayRecordReturnsStartAndEndTimeForToday() throws {
        let calendar = testCalendar()
        let matcher = AttendanceDayMatcher(calendar: calendar)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let todayStart = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let todayEnd = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0))
        )
        let store = InMemoryAttendanceTimeStore()
        store.startTime = todayStart
        store.endTime = todayEnd

        let record = store.todayRecord(referenceDate: referenceDate, dayMatcher: matcher)

        #expect(record?.startTime == todayStart)
        #expect(record?.endTime == todayEnd)
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

private final class InMemoryAttendanceTimeStore: AttendanceTimeStore {
    var startTime: Date?
    var endTime: Date?
}
