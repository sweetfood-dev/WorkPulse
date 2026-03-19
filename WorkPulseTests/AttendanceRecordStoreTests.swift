import Foundation
import Testing
@testable import WorkPulse

struct AttendanceRecordStoreTests {
    @Test("store updates the existing record when saving another record on the same day")
    func storeUpdatesExistingRecordOnTheSameDay() throws {
        let calendar = testCalendar()
        let originalStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let originalEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0))
        )
        let updatedStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 30))
        )
        let updatedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 5))
        )
        let store = InMemoryAttendanceRecordStore()
        store.records = [
            AttendanceRecord(startTime: originalStartTime, endTime: originalEndTime)
        ]

        store.upsertRecord(
            AttendanceRecord(startTime: updatedStartTime, endTime: updatedEndTime),
            calendar: calendar
        )

        #expect(store.records == [
            AttendanceRecord(startTime: updatedStartTime, endTime: updatedEndTime)
        ])
    }

    @Test("store appends a new record when saving a different day's record")
    func storeAppendsRecordForDifferentDay() throws {
        let calendar = testCalendar()
        let mondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let mondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let tuesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 10, minute: 0))
        )
        let tuesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 16, minute: 30))
        )
        let store = InMemoryAttendanceRecordStore()
        store.records = [
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime)
        ]

        store.upsertRecord(
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime),
            calendar: calendar
        )

        #expect(store.records == [
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime),
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime)
        ])
    }

    @Test("store returns only records that match the requested period predicate")
    func storeReturnsOnlyRecordsThatMatchTheRequestedPeriodPredicate() throws {
        let calendar = testCalendar()
        let monthMatcher = AttendanceMonthMatcher(calendar: calendar)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let currentMonthStart = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let currentMonthEnd = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let previousMonthStart = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 29, hour: 9, minute: 0))
        )
        let previousMonthEnd = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 29, hour: 12, minute: 0))
        )
        let store = InMemoryAttendanceRecordStore()
        store.records = [
            AttendanceRecord(startTime: currentMonthStart, endTime: currentMonthEnd),
            AttendanceRecord(startTime: previousMonthStart, endTime: previousMonthEnd)
        ]

        let records = store.records(
            containing: referenceDate,
            matches: monthMatcher.contains
        )

        #expect(records == [
            AttendanceRecord(startTime: currentMonthStart, endTime: currentMonthEnd)
        ])
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

private final class InMemoryAttendanceRecordStore: AttendanceRecordStore {
    var records: [AttendanceRecord] = []
}
