import AppKit
import Foundation
import SwiftData
import Testing
@testable import WorkPulse

@Suite("CurrentSessionCalculator")
struct CurrentSessionCalculatorTests {
    @Test
    func returnsElapsedDurationWhenStartTimeExistsAndSessionIsInProgress() throws {
        let calculator = CurrentSessionCalculator(
            workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
        )
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
    func subtractsLunchBreakFromInProgressSessionAfterLunchWindow() throws {
        let calculator = CurrentSessionCalculator(
            workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T14:00:00+09:00")
        )

        let duration = calculator.sessionDuration(
            startTime: startTime,
            endTime: nil,
            now: now
        )

        #expect(duration == 14_400)
    }

    @Test
    func subtractsLunchBreakFromEachSpannedDayInProgressSession() throws {
        let calculator = CurrentSessionCalculator(
            workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T14:00:00+09:00")
        )

        let duration = calculator.sessionDuration(
            startTime: startTime,
            endTime: nil,
            now: now
        )

        #expect(duration == 97_200)
    }

    @Test
    func returnsFixedDurationWhenEndTimeExists() throws {
        let calculator = CurrentSessionCalculator(
            workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
        )
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

        #expect(duration == 30_600)
    }

    @Test
    func deductsLunchBreakOverlapFromCompletedWorkday() throws {
        let calculator = WorkedDurationCalculator(calendar: makeSeoulCalendar())
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00")
        )

        let duration = calculator.workedDuration(
            startTime: startTime,
            endTime: endTime
        )

        #expect(duration == 28_800)
    }

    @Test
    func deductsLunchBreakAcrossEachSpannedDay() throws {
        let calculator = WorkedDurationCalculator(calendar: makeSeoulCalendar())
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T14:00:00+09:00")
        )

        let duration = calculator.workedDuration(
            startTime: startTime,
            endTime: endTime
        )

        #expect(duration == 97_200)
    }

}

@Suite("MainPopoverCurrentSessionRuntime")
struct MainPopoverCurrentSessionRuntimeTests {
    @Test
    @MainActor
    func beginUsesPlaceholderAndDoesNotScheduleWithoutStartTime() {
        let scheduler = RuntimeFakeRepeatingScheduler()
        var receivedTexts: [String] = []
        let runtime = MainPopoverCurrentSessionRuntime(
            currentTimeProvider: { Date(timeIntervalSince1970: 0) },
            currentSessionScheduler: scheduler,
            onChange: { text, _ in receivedTexts.append(text) }
        )

        runtime.begin(startTime: nil, endTime: nil)

        #expect(receivedTexts == ["--:--:--"])
        #expect(scheduler.scheduleCallCount == 0)
    }

    @Test
    @MainActor
    func beginEmitsElapsedTimeImmediatelyAndOnEveryTick() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        var now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:30+09:00")
        )
        let scheduler = RuntimeFakeRepeatingScheduler()
        var receivedTexts: [String] = []
        let runtime = MainPopoverCurrentSessionRuntime(
            currentTimeProvider: { now },
            currentSessionScheduler: scheduler,
            onChange: { text, _ in receivedTexts.append(text) }
        )

        runtime.begin(startTime: startTime, endTime: nil)

        #expect(receivedTexts == ["02:45:30"])
        #expect(scheduler.scheduleCallCount == 1)

        now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:31+09:00")
        )
        scheduler.fire()

        #expect(receivedTexts == ["02:45:30", "02:45:31"])
    }

    @Test
    @MainActor
    func beginEmitsFixedDurationAndDoesNotScheduleWhenEndTimeExists() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let scheduler = RuntimeFakeRepeatingScheduler()
        var receivedTexts: [String] = []
        let runtime = MainPopoverCurrentSessionRuntime(
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
            ),
            currentTimeProvider: {
                ISO8601DateFormatter().date(from: "2026-03-31T20:00:00+09:00")
                ?? Date(timeIntervalSince1970: 0)
            },
            currentSessionScheduler: scheduler,
            onChange: { text, _ in receivedTexts.append(text) }
        )

        runtime.begin(startTime: startTime, endTime: endTime)

        #expect(receivedTexts == ["08:30:00"])
        #expect(scheduler.scheduleCallCount == 0)
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

        #expect(total == 28_800)
    }

    @Test
    func weeklyTotalDerivesLunchDeductionFromPassedCalendar() throws {
        let utc = try #require(TimeZone(secondsFromGMT: 0))
        let calculator = AttendanceRecordTotalsCalculator()
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let records = [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00"))
            )
        ]

        let seoulTotal = calculator.weeklyTotal(
            records: records,
            referenceDate: referenceDate,
            calendar: Self.seoulCalendar
        )
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = utc
        utcCalendar.locale = Locale(identifier: "ko_KR")

        let utcTotal = calculator.weeklyTotal(
            records: records,
            referenceDate: referenceDate,
            calendar: utcCalendar
        )

        #expect(seoulTotal == 28_800)
        #expect(utcTotal == 32_400)
    }

    @Test
    func weeklyTotalDeductsLunchBreakForEachSpannedDay() throws {
        let calculator = AttendanceRecordTotalsCalculator()
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let records = [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T14:00:00+09:00"))
            )
        ]

        let total = calculator.weeklyTotal(
            records: records,
            referenceDate: referenceDate,
            calendar: Self.seoulCalendar
        )

        #expect(total == 97_200)
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

        #expect(total == 55_800)
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}

@Suite("MainPopoverStateLoader")
struct MainPopoverStateLoaderTests {
    @Test
    func loadsTodayRecordAndStoredWeeklyMonthlyTotals() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let todayRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: nil
        )
        let store = InMemoryAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-30T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T09:00:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T18:00:00+09:00"))
            ),
            todayRecord,
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-03T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T09:30:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T18:00:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T09:00:00+09:00")),
                endTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T17:00:00+09:00"))
            )
        ])
        let loader = MainPopoverStateLoader(
            recordStore: store,
            viewStateFactory: MainPopoverViewStateFactory(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
            ),
            calendar: Self.seoulCalendar
        )

        let loadedState = loader.load(referenceDate: referenceDate)

        #expect(loadedState.todayRecord == todayRecord)
        #expect(loadedState.viewState.dateText == "3월 31일 Tuesday")
        #expect(loadedState.viewState.checkedInSummaryText == "출근 09:00")
        #expect(loadedState.viewState.attendanceState == .checkedIn)
        #expect(loadedState.viewState.startTimeText == "09:00")
        #expect(loadedState.viewState.endTimeText == "--:--")
        #expect(loadedState.viewState.weeklyTotalText == "15:00")
        #expect(loadedState.viewState.monthlyTotalText == "15:30")
    }

    @Test
    func usesPlaceholderStateWhenStoreHasNoMatchingRecords() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let loader = MainPopoverStateLoader(
            recordStore: InMemoryAttendanceRecordStore(records: []),
            viewStateFactory: MainPopoverViewStateFactory(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
            ),
            calendar: Self.seoulCalendar
        )

        let loadedState = loader.load(referenceDate: referenceDate)

        #expect(loadedState.todayRecord == nil)
        #expect(loadedState.viewState.checkedInSummaryText == "출근 전")
        #expect(loadedState.viewState.attendanceState == .notCheckedIn)
        #expect(loadedState.viewState.startTimeText == "--:--")
        #expect(loadedState.viewState.endTimeText == "--:--")
        #expect(loadedState.viewState.weeklyTotalText == "--")
        #expect(loadedState.viewState.monthlyTotalText == "--")
    }

    @Test
    func excludesInvalidStoredDurationFromWeeklyAndMonthlyTotals() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let loader = MainPopoverStateLoader(
            recordStore: InMemoryAttendanceRecordStore(records: [
                AttendanceRecord(
                    date: try #require(ISO8601DateFormatter().date(from: "2026-03-30T00:00:00+09:00")),
                    startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T09:00:00+09:00")),
                    endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T18:00:00+09:00"))
                ),
                AttendanceRecord(
                    date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                    startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00")),
                    endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00"))
                ),
                AttendanceRecord(
                    date: try #require(ISO8601DateFormatter().date(from: "2026-03-03T00:00:00+09:00")),
                    startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T09:30:00+09:00")),
                    endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T18:00:00+09:00"))
                )
            ]),
            viewStateFactory: MainPopoverViewStateFactory(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
            ),
            calendar: Self.seoulCalendar
        )

        let loadedState = loader.load(referenceDate: referenceDate)

        #expect(loadedState.viewState.weeklyTotalText == "08:00")
        #expect(loadedState.viewState.monthlyTotalText == "15:30")
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}

@Suite("UserDefaultsAttendanceRecordStore")
struct UserDefaultsAttendanceRecordStoreTests {
    @Test
    func upsertRecordAppendsWhenDayDoesNotExist() throws {
        let userDefaults = try makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: try! #require(userDefaultsSuiteName)) }
        let store = UserDefaultsAttendanceRecordStore(userDefaults: userDefaults)
        let record = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: nil
        )

        try store.upsertRecord(record)

        #expect(store.loadRecords() == [record])
    }

    @Test
    func upsertRecordReplacesExistingRecordForSameDay() throws {
        let userDefaults = try makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: try! #require(userDefaultsSuiteName)) }
        let store = UserDefaultsAttendanceRecordStore(userDefaults: userDefaults)
        let originalRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: nil
        )
        let editedRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T08:30:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00"))
        )

        try store.upsertRecord(originalRecord)
        try store.upsertRecord(editedRecord)

        #expect(store.loadRecords() == [editedRecord])
    }

    @Test
    func recordReturnsLatestStoredRecordForReferenceDay() throws {
        let userDefaults = try makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: try! #require(userDefaultsSuiteName)) }
        let store = UserDefaultsAttendanceRecordStore(userDefaults: userDefaults)
        let originalRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: nil
        )
        let editedRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T08:30:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00"))
        )
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )

        try store.upsertRecord(originalRecord)
        try store.upsertRecord(editedRecord)

        #expect(store.record(on: referenceDate, calendar: Self.seoulCalendar) == editedRecord)
    }

    @Test
    func recordsReturnsOnlyEntriesMatchingRequestedGranularity() throws {
        let userDefaults = try makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: try! #require(userDefaultsSuiteName)) }
        let store = UserDefaultsAttendanceRecordStore(userDefaults: userDefaults)
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let weeklyRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-30T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T18:00:00+09:00"))
        )
        let monthlyRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-03T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T18:00:00+09:00"))
        )
        let nextMonthRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T18:00:00+09:00"))
        )

        try store.upsertRecord(weeklyRecord)
        try store.upsertRecord(monthlyRecord)
        try store.upsertRecord(nextMonthRecord)

        let weeklyRecords = store.records(
            equalTo: referenceDate,
            toGranularity: .weekOfYear,
            calendar: Self.seoulCalendar
        ).sorted { $0.date < $1.date }
        let monthlyRecords = store.records(
            equalTo: referenceDate,
            toGranularity: .month,
            calendar: Self.seoulCalendar
        ).sorted { $0.date < $1.date }

        #expect(weeklyRecords.count == 2)
        #expect(monthlyRecords.count == 2)
        #expect(weeklyRecords.contains { $0 == weeklyRecord })
        #expect(weeklyRecords.contains { $0 == nextMonthRecord })
        #expect(monthlyRecords.contains { $0 == weeklyRecord })
        #expect(monthlyRecords.contains { $0 == monthlyRecord })
    }

    private func makeUserDefaults() throws -> UserDefaults {
        let suiteName = try #require(userDefaultsSuiteName)
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private var userDefaultsSuiteName: String? {
        "UserDefaultsAttendanceRecordStoreTests.\(UUID().uuidString)"
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}

@Suite("SwiftDataAttendanceRecordStore")
struct SwiftDataAttendanceRecordStoreTests {
    @Test
    func upsertRecordAppendsWhenDayDoesNotExist() throws {
        let store = try makeStore()
        let record = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: nil
        )

        try store.upsertRecord(record)

        #expect(store.loadRecords() == [record])
    }

    @Test
    func upsertRecordReplacesExistingRecordForSameDay() throws {
        let store = try makeStore()
        let originalRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: nil
        )
        let editedRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T08:30:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00"))
        )

        try store.upsertRecord(originalRecord)
        try store.upsertRecord(editedRecord)

        #expect(store.loadRecords() == [editedRecord])
    }

    @Test
    func recordsReturnsOnlyEntriesMatchingRequestedGranularity() throws {
        let store = try makeStore()
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let weeklyRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-30T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T18:00:00+09:00"))
        )
        let monthlyRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-03T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-03T18:00:00+09:00"))
        )
        let nextMonthRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T18:00:00+09:00"))
        )

        try store.upsertRecord(weeklyRecord)
        try store.upsertRecord(monthlyRecord)
        try store.upsertRecord(nextMonthRecord)

        let weeklyRecords = store.records(
            equalTo: referenceDate,
            toGranularity: .weekOfYear,
            calendar: Self.seoulCalendar
        )
        let monthlyRecords = store.records(
            equalTo: referenceDate,
            toGranularity: .month,
            calendar: Self.seoulCalendar
        )

        #expect(weeklyRecords.count == 2)
        #expect(monthlyRecords.count == 2)
        #expect(weeklyRecords.contains { $0 == weeklyRecord })
        #expect(weeklyRecords.contains { $0 == nextMonthRecord })
        #expect(monthlyRecords.contains { $0 == weeklyRecord })
        #expect(monthlyRecords.contains { $0 == monthlyRecord })
    }

    @Test
    func migratesLegacyUserDefaultsRecordsWhenStoreStartsEmpty() throws {
        let legacyRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00"))
        )
        let legacyUserDefaults = try makeUserDefaults()
        defer { legacyUserDefaults.removePersistentDomain(forName: try! #require(userDefaultsSuiteName)) }
        let legacyStore = UserDefaultsAttendanceRecordStore(userDefaults: legacyUserDefaults)
        try legacyStore.upsertRecord(legacyRecord)

        let configuration = ModelConfiguration(
            for: AttendanceRecordEntity.self,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: AttendanceRecordEntity.self,
            configurations: configuration
        )
        let store = try SwiftDataAttendanceRecordStore(
            modelContainer: container,
            calendar: Self.seoulCalendar,
            legacyRecords: legacyStore.loadRecords()
        )

        #expect(store.loadRecords() == [legacyRecord])
    }

    @Test
    func deleteRecordRemovesAllSameDayRows() throws {
        let duplicateDate = try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00"))
        let firstRecord = AttendanceRecord(
            date: duplicateDate,
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: nil
        )
        let duplicateRecord = AttendanceRecord(
            date: duplicateDate,
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T08:30:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00"))
        )
        let configuration = ModelConfiguration(
            for: AttendanceRecordEntity.self,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: AttendanceRecordEntity.self,
            configurations: configuration
        )
        let store = try SwiftDataAttendanceRecordStore(
            modelContainer: container,
            calendar: Self.seoulCalendar,
            legacyRecords: [firstRecord, duplicateRecord]
        )

        try store.deleteRecord(on: duplicateDate, calendar: Self.seoulCalendar)

        #expect(store.record(on: duplicateDate, calendar: Self.seoulCalendar) == nil)
        #expect(store.loadRecords().isEmpty)
    }

    private func makeStore() throws -> SwiftDataAttendanceRecordStore {
        let configuration = ModelConfiguration(
            for: AttendanceRecordEntity.self,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: AttendanceRecordEntity.self,
            configurations: configuration
        )
        return try SwiftDataAttendanceRecordStore(
            modelContainer: container,
            calendar: Self.seoulCalendar
        )
    }

    private func makeUserDefaults() throws -> UserDefaults {
        let suiteName = try #require(userDefaultsSuiteName)
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private var userDefaultsSuiteName: String? {
        "SwiftDataAttendanceRecordStoreTests.\(UUID().uuidString)"
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}

@Suite("MirroredAttendanceRecordStore")
struct MirroredAttendanceRecordStoreTests {
    @Test
    func upsertRecordKeepsLegacyFallbackSynchronizedAfterMigration() throws {
        let originalRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: nil
        )
        let editedRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00"))
        )
        let legacyUserDefaults = try makeUserDefaults()
        defer { legacyUserDefaults.removePersistentDomain(forName: try! #require(userDefaultsSuiteName)) }
        let legacyStore = UserDefaultsAttendanceRecordStore(
            userDefaults: legacyUserDefaults,
            calendar: Self.seoulCalendar
        )
        try legacyStore.upsertRecord(originalRecord)

        let configuration = ModelConfiguration(
            for: AttendanceRecordEntity.self,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: AttendanceRecordEntity.self,
            configurations: configuration
        )
        let primaryStore = try SwiftDataAttendanceRecordStore(
            modelContainer: container,
            calendar: Self.seoulCalendar,
            legacyRecords: legacyStore.loadRecords()
        )
        let store = MirroredAttendanceRecordStore(
            primary: primaryStore,
            fallback: legacyStore
        )

        try store.upsertRecord(editedRecord)

        #expect(primaryStore.loadRecords() == [editedRecord])
        #expect(legacyStore.loadRecords() == [editedRecord])
    }

    @Test
    func recordFallsBackWhenPrimaryHasNoMatchingDay() throws {
        let fallbackRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00"))
        )
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let legacyUserDefaults = try makeUserDefaults()
        defer { legacyUserDefaults.removePersistentDomain(forName: try! #require(userDefaultsSuiteName)) }
        let legacyStore = UserDefaultsAttendanceRecordStore(
            userDefaults: legacyUserDefaults,
            calendar: Self.seoulCalendar
        )
        try legacyStore.upsertRecord(fallbackRecord)

        let store = MirroredAttendanceRecordStore(
            primary: try makePrimaryStore(),
            fallback: legacyStore
        )

        #expect(
            store.record(on: referenceDate, calendar: Self.seoulCalendar) == fallbackRecord
        )
    }

    @Test
    func recordsFallBackWhenPrimaryReturnsNoMatches() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T12:00:00+09:00")
        )
        let weeklyRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-30T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T18:00:00+09:00"))
        )
        let nextMonthRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-04-01T18:00:00+09:00"))
        )
        let legacyUserDefaults = try makeUserDefaults()
        defer { legacyUserDefaults.removePersistentDomain(forName: try! #require(userDefaultsSuiteName)) }
        let legacyStore = UserDefaultsAttendanceRecordStore(
            userDefaults: legacyUserDefaults,
            calendar: Self.seoulCalendar
        )
        try legacyStore.upsertRecord(weeklyRecord)
        try legacyStore.upsertRecord(nextMonthRecord)

        let store = MirroredAttendanceRecordStore(
            primary: try makePrimaryStore(),
            fallback: legacyStore
        )

        let weeklyRecords = store.records(
            equalTo: referenceDate,
            toGranularity: .weekOfYear,
            calendar: Self.seoulCalendar
        )

        #expect(weeklyRecords.count == 2)
        #expect(weeklyRecords.contains { $0 == weeklyRecord })
        #expect(weeklyRecords.contains { $0 == nextMonthRecord })
    }

    @Test
    func upsertRecordRethrowsPrimaryFailureWithoutUpdatingFallback() throws {
        let editedRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00"))
        )
        let legacyUserDefaults = try makeUserDefaults()
        defer { legacyUserDefaults.removePersistentDomain(forName: try! #require(userDefaultsSuiteName)) }
        let legacyStore = UserDefaultsAttendanceRecordStore(
            userDefaults: legacyUserDefaults,
            calendar: Self.seoulCalendar
        )
        let store = MirroredAttendanceRecordStore(
            primary: ThrowingAttendanceRecordStore(records: []),
            fallback: legacyStore
        )

        #expect(throws: ThrowingAttendanceRecordStore.TestError.self) {
            try store.upsertRecord(editedRecord)
        }
        #expect(legacyStore.loadRecords().isEmpty)
    }

    private func makeUserDefaults() throws -> UserDefaults {
        let suiteName = try #require(userDefaultsSuiteName)
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private func makePrimaryStore() throws -> SwiftDataAttendanceRecordStore {
        let configuration = ModelConfiguration(
            for: AttendanceRecordEntity.self,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: AttendanceRecordEntity.self,
            configurations: configuration
        )
        return try SwiftDataAttendanceRecordStore(
            modelContainer: container,
            calendar: Self.seoulCalendar
        )
    }

    private var userDefaultsSuiteName: String? {
        "MirroredAttendanceRecordStoreTests.\(UUID().uuidString)"
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}

@Suite("AppDelegate")
struct AppDelegateTests {
    @Test
    @MainActor
    func applyingEditedTimesPersistsTodayRecordAndRefreshesVisibleSummaries() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T20:00:00+09:00")
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let mondayRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-30T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T17:00:00+09:00"))
        )
        let store = InMemoryAttendanceRecordStore(records: [
            mondayRecord,
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                startTime: startTime,
                endTime: nil
            )
        ])
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
            ),
            currentTimeProvider: { referenceDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { referenceDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: store
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: referenceDate)
        controller.beginEditing(.endTime)
        controller.setEditingPickerDate(endTime, for: .endTime)
        controller.applyEditing()
        let snapshot = controller.snapshot

        let persistedTodayRecord = try #require(
            store.loadRecords().last(where: { Self.seoulCalendar.isDate($0.date, inSameDayAs: referenceDate) })
        )
        #expect(persistedTodayRecord.startTime == startTime)
        #expect(persistedTodayRecord.endTime == endTime)
        #expect(snapshot.todayTimes.endRow.valueText == "18:30")
        #expect(snapshot.currentSession.valueText == "08:30:00")
        #expect(snapshot.currentSession.progressFraction == 1)
        #expect(snapshot.summary.weeklyValueText == "15:30")
        #expect(snapshot.summary.monthlyValueText == "15:30")
    }

    @Test
    @MainActor
    func deletingSavedEndTimeResumesCurrentSessionAndDropsTodayFromSummaries() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T17:00:00+09:00")
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let originalEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T16:00:00+09:00")
        )
        let mondayRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-30T00:00:00+09:00")),
            startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T09:00:00+09:00")),
            endTime: try #require(ISO8601DateFormatter().date(from: "2026-03-30T17:00:00+09:00"))
        )
        let store = InMemoryAttendanceRecordStore(records: [
            mondayRecord,
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                startTime: startTime,
                endTime: originalEndTime
            )
        ])
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
            ),
            currentTimeProvider: { referenceDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { referenceDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: store
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: referenceDate)
        controller.beginEditing(.endTime)
        controller.deleteEndTime()
        let snapshot = controller.snapshot

        let persistedTodayRecord = try #require(
            store.loadRecords().last(where: { Self.seoulCalendar.isDate($0.date, inSameDayAs: referenceDate) })
        )
        #expect(persistedTodayRecord.startTime == startTime)
        #expect(persistedTodayRecord.endTime == nil)
        #expect(snapshot.todayTimes.endRow.valueText == "--:--")
        #expect(snapshot.currentSession.valueText == "07:00:00")
        #expect(abs(snapshot.currentSession.progressFraction - 0.875) < 0.001)
        #expect(snapshot.summary.weeklyValueText == "07:00")
        #expect(snapshot.summary.monthlyValueText == "07:00")
    }

    @Test
    @MainActor
    func configurePopoverUsesInjectedCalendarLocaleAndTimeZone() throws {
        let seoulTimeZone = try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T15:30:00Z")
        )
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { referenceDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: seoulTimeZone,
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { referenceDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: InMemoryAttendanceRecordStore(records: [])
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: referenceDate)

        #expect(controller.snapshot.header.dateText == "4월 1일 Wednesday")
    }

    @Test
    @MainActor
    func applyingEditedTimesAdvancesToCurrentClockDateWhenDisplayedReferenceDateIsStale() throws {
        let displayedReferenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T20:00:00+09:00")
        )
        let currentClockDate = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T00:05:00+09:00")
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let store = InMemoryAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                startTime: startTime,
                endTime: nil
            )
        ])
        var currentDate = displayedReferenceDate
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
            ),
            currentTimeProvider: { currentDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { currentDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: store
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: displayedReferenceDate)
        currentDate = currentClockDate
        controller.beginEditing(.endTime)
        controller.setEditingPickerDate(endTime, for: .endTime)
        controller.applyEditing()

        let currentDayRecord = try #require(
            store.loadRecords().last(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: currentClockDate)
            })
        )
        #expect(currentDayRecord.startTime == startTime)
        #expect(currentDayRecord.endTime == endTime)
        #expect(controller.snapshot.header.dateText == "4월 1일 Wednesday")
        #expect(
            store.loadRecords().contains(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: displayedReferenceDate) &&
                $0.endTime == endTime
            }) == false
        )
    }

    @Test
    @MainActor
    func openingPopoverOnNewDayCancelsEditingBeforeRefreshingReferenceDate() throws {
        let displayedReferenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T20:00:00+09:00")
        )
        let currentClockDate = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T00:05:00+09:00")
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let staleDraftEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let store = InMemoryAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                startTime: startTime,
                endTime: nil
            )
        ])
        var currentDate = displayedReferenceDate
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: WorkedDurationCalculator(calendar: Self.seoulCalendar)
            ),
            currentTimeProvider: { currentDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { currentDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: store
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: displayedReferenceDate)
        controller.beginEditing(.endTime)
        controller.setEditingPickerDate(staleDraftEndTime, for: .endTime)

        currentDate = currentClockDate
        appDelegate.handlePopoverWillOpen()
        let snapshot = controller.snapshot

        #expect(snapshot.todayTimes.isEndApplyVisible == false)
        #expect(snapshot.todayTimes.isEndCancelVisible == false)
        #expect(snapshot.header.dateText == "4월 1일 Wednesday")
        #expect(snapshot.todayTimes.endRow.valueText == "--:--")

        controller.applyEditing()

        #expect(
            store.loadRecords().contains(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: currentClockDate)
            }) == false
        )
    }

    @Test
    @MainActor
    func openingPopoverAfterCloseRefreshesCurrentSessionAgainstCurrentClock() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T10:00:00+09:00")
        )
        let laterDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T10:05:00+09:00")
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let store = InMemoryAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                startTime: startTime,
                endTime: nil
            )
        ])
        var currentDate = referenceDate
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { currentDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { currentDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: store
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: referenceDate)

        #expect(controller.snapshot.currentSession.valueText == "01:00:00")

        controller.stopCurrentSessionUpdates()
        currentDate = laterDate
        appDelegate.handlePopoverWillOpen()

        #expect(controller.snapshot.currentSession.valueText == "01:05:00")
    }

    @Test
    @MainActor
    func applyingEditedTimesKeepsStoredSnapshotWhenSaveFails() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T20:00:00+09:00")
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let persistedRecord = AttendanceRecord(
            date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
            startTime: startTime,
            endTime: nil
        )
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
            ),
            currentTimeProvider: { referenceDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { referenceDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: ThrowingAttendanceRecordStore(records: [persistedRecord])
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: referenceDate)
        controller.beginEditing(.endTime)
        controller.setEditingPickerDate(endTime, for: .endTime)
        controller.applyEditing()

        let snapshot = controller.snapshot
        #expect(snapshot.todayTimes.endRow.valueText == "--:--")
        #expect(snapshot.currentSession.valueText == "10:00:00")
        #expect(snapshot.todayTimes.isEndApplyVisible == false)
        #expect(snapshot.todayTimes.isEndCancelVisible == false)
    }

    @Test
    @MainActor
    func selectingPastDayFromWeeklyDetailEditsThatDayWithoutLeavingWeeklyDetail() throws {
        let currentDate = try #require(
            ISO8601DateFormatter().date(from: "2026-04-03T12:00:00+09:00")
        )
        let selectedPastDate = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T12:00:00+09:00")
        )
        let pastStartTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T08:30:00+09:00")
        )
        let editedPastEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T17:45:00+09:00")
        )
        let currentDayStart = try #require(
            ISO8601DateFormatter().date(from: "2026-04-03T09:00:00+09:00")
        )
        let store = InMemoryAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+09:00")),
                startTime: pastStartTime,
                endTime: nil
            ),
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-04-03T00:00:00+09:00")),
                startTime: currentDayStart,
                endTime: nil
            ),
        ])
        let scheduler = FakeRepeatingScheduler()
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: WorkedDurationCalculator(calendar: Self.seoulCalendar)
            ),
            currentTimeProvider: { currentDate },
            currentSessionScheduler: scheduler
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { currentDate },
                currentSessionScheduler: scheduler
            ),
            recordStore: store
        )
        let weeklyState = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: Self.seoulCalendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
            calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
            currentDateProvider: { currentDate }
        ).load(referenceDate: currentDate)
        let selectedIndex = try #require(
            weeklyState.days.firstIndex(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: selectedPastDate)
            })
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: currentDate)
        controller.showWeeklyDetail(weeklyState)
        controller.simulateSelectWeeklyDetailDay(at: selectedIndex)

        let selectedSnapshot = controller.snapshot
        #expect(selectedSnapshot.isShowingWeeklyDetail)
        #expect(selectedSnapshot.weeklyDetail.isShowingEditor)
        #expect(selectedSnapshot.weeklyDetail.editorDateText == "4월 1일 Wednesday")

        controller.beginEditingSelectedDetailDay(.endTime)
        controller.setSelectedDetailPickerDate(editedPastEndTime, for: .endTime)
        controller.applySelectedDetailEditing()

        let persistedPastRecord = try #require(
            store.loadRecords().last(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: selectedPastDate)
            })
        )
        let persistedCurrentRecord = try #require(
            store.loadRecords().last(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: currentDate)
            })
        )
        #expect(persistedPastRecord.startTime == pastStartTime)
        #expect(persistedPastRecord.endTime == editedPastEndTime)
        #expect(persistedCurrentRecord.startTime == currentDayStart)
        #expect(persistedCurrentRecord.endTime == nil)
        #expect(controller.snapshot.isShowingWeeklyDetail)
        #expect(controller.snapshot.weeklyDetail.isShowingEditor)
        #expect(controller.snapshot.weeklyDetail.editorDateText == "4월 1일 Wednesday")
    }

    @Test
    @MainActor
    func editingCurrentDayFromWeeklyDetailRefreshesMainRouteBeforeReturning() throws {
        let currentDate = try #require(
            ISO8601DateFormatter().date(from: "2026-04-03T20:00:00+09:00")
        )
        let currentDayStart = try #require(
            ISO8601DateFormatter().date(from: "2026-04-03T08:10:00+09:00")
        )
        let editedCurrentDayEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-03T17:30:00+09:00")
        )
        let store = InMemoryAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-04-03T00:00:00+09:00")),
                startTime: currentDayStart,
                endTime: nil
            ),
        ])
        let scheduler = FakeRepeatingScheduler()
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: WorkedDurationCalculator(calendar: Self.seoulCalendar)
            ),
            currentTimeProvider: { currentDate },
            currentSessionScheduler: scheduler
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { currentDate },
                currentSessionScheduler: scheduler
            ),
            recordStore: store
        )
        let weeklyState = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: Self.seoulCalendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
            calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
            currentDateProvider: { currentDate }
        ).load(referenceDate: currentDate)
        let selectedIndex = try #require(
            weeklyState.days.firstIndex(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: currentDate)
            })
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: currentDate)
        controller.showWeeklyDetail(weeklyState)
        controller.simulateSelectWeeklyDetailDay(at: selectedIndex)
        controller.beginEditingSelectedDetailDay(.endTime)
        controller.setSelectedDetailPickerDate(editedCurrentDayEndTime, for: .endTime)
        controller.applySelectedDetailEditing()
        controller.showMainView()

        let snapshot = controller.snapshot
        #expect(snapshot.todayTimes.endRow.valueText == "17:30")
        #expect(snapshot.currentSession.valueText == "08:20:00")
        #expect(scheduler.scheduleCallCount == 1)
        #expect(scheduler.cancellable.cancelCallCount == 1)
    }

    @Test
    @MainActor
    func selectingPastDayFromMonthlyDetailEditsThatDayWithoutLeavingMonthlyDetail() throws {
        let currentDate = try #require(
            ISO8601DateFormatter().date(from: "2026-04-03T12:00:00+09:00")
        )
        let selectedPastDate = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T12:00:00+09:00")
        )
        let pastStartTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T08:30:00+09:00")
        )
        let editedPastEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-01T17:45:00+09:00")
        )
        let currentDayStart = try #require(
            ISO8601DateFormatter().date(from: "2026-04-03T09:00:00+09:00")
        )
        let store = InMemoryAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+09:00")),
                startTime: pastStartTime,
                endTime: nil
            ),
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-04-03T00:00:00+09:00")),
                startTime: currentDayStart,
                endTime: nil
            ),
        ])
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: WorkedDurationCalculator(calendar: Self.seoulCalendar)
            ),
            currentTimeProvider: { currentDate },
            currentSessionScheduler: FakeRepeatingScheduler()
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { currentDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: store
        )
        let monthlyState = MonthlyHistoryLoader(
            recordStore: store,
            calendar: Self.seoulCalendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
            calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
            currentDateProvider: { currentDate }
        ).load(referenceDate: currentDate)
        let selectedIndex = try #require(
            monthlyState.cells.firstIndex(where: { cell in
                guard let date = cell.date else { return false }
                return Self.seoulCalendar.isDate(date, inSameDayAs: selectedPastDate)
            })
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: currentDate)
        controller.showMonthlyHistory(monthlyState)
        controller.simulateSelectMonthlyDetailDay(at: selectedIndex)

        let selectedSnapshot = controller.snapshot
        #expect(selectedSnapshot.isShowingMonthlyDetail)
        #expect(selectedSnapshot.monthlyDetail.isShowingEditor)
        #expect(selectedSnapshot.monthlyDetail.editorDateText == "4월 1일 Wednesday")

        controller.beginEditingSelectedDetailDay(.endTime)
        controller.setSelectedDetailPickerDate(editedPastEndTime, for: .endTime)
        controller.applySelectedDetailEditing()

        let persistedPastRecord = try #require(
            store.loadRecords().last(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: selectedPastDate)
            })
        )
        let persistedCurrentRecord = try #require(
            store.loadRecords().last(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: currentDate)
            })
        )
        #expect(persistedPastRecord.startTime == pastStartTime)
        #expect(persistedPastRecord.endTime == editedPastEndTime)
        #expect(persistedCurrentRecord.startTime == currentDayStart)
        #expect(persistedCurrentRecord.endTime == nil)
        #expect(controller.snapshot.isShowingMonthlyDetail)
        #expect(controller.snapshot.monthlyDetail.isShowingEditor)
        #expect(controller.snapshot.monthlyDetail.editorDateText == "4월 1일 Wednesday")
    }

    @Test
    @MainActor
    func calendarDayChangeNotificationResyncsMenuBarAttendanceState() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00")
        )
        let notificationCenter = NotificationCenter()
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { referenceDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: InMemoryAttendanceRecordStore(records: []),
            notificationCenter: notificationCenter
        )
        var syncCallCount = 0
        appDelegate.onDidSyncMenuBarAttendanceStateForTesting = {
            syncCallCount += 1
        }

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        #expect(syncCallCount == 1)

        notificationCenter.post(name: .NSCalendarDayChanged, object: nil)
        #expect(syncCallCount == 2)
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}

@Suite("MainPopoverCoordinator")
struct MainPopoverCoordinatorTests {
    @Test
    @MainActor
    func syncingMenuBarAttendanceStatePublishesCurrentDayState() throws {
        let currentDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T20:00:00+09:00")
        )
        let store = InMemoryAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")),
                startTime: try #require(ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")),
                endTime: nil
            )
        ])
        let coordinator = MainPopoverCoordinator(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { currentDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: store
        )
        var publishedAttendanceState: MainPopoverAttendanceState?

        coordinator.onDidUpdateAttendanceState = { attendanceState in
            publishedAttendanceState = attendanceState
        }

        coordinator.syncMenuBarAttendanceState()

        #expect(publishedAttendanceState == .checkedIn)
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}

private func makeSeoulCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
    return calendar
}

@Suite("TodayTimeEditModeState")
struct TodayTimeEditModeStateTests {
    @Test
    func beginEditingStartTimeEntersStartEditModeWithSavedDrafts() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00")
        )
        var state = TodayTimeEditModeState()
        state.loadSavedTimes(startTime: startTime, endTime: endTime)

        state.beginEditing(.startTime)

        #expect(state.editingField == .startTime)
        #expect(state.draftStartTime == startTime)
        #expect(state.draftEndTime == endTime)
        #expect(state.isEditingStartTime)
        #expect(state.isEditingEndTime == false)
    }

    @Test
    func applyPromotesDraftsToSavedTimesAndReturnsUpdatedValues() throws {
        let savedStartTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let editedStartTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T08:30:00+09:00")
        )
        var state = TodayTimeEditModeState()
        state.loadSavedTimes(startTime: savedStartTime, endTime: nil)
        state.beginEditing(.startTime)
        state.updateDraftStartTime(editedStartTime)

        let appliedTimes = state.apply()

        #expect(appliedTimes?.startTime == editedStartTime)
        #expect(appliedTimes?.endTime == nil)
        #expect(state.savedStartTime == editedStartTime)
        #expect(state.savedEndTime == nil)
        #expect(state.editingField == nil)
    }

    @Test
    func cancelRestoresDraftsBackToSavedTimes() throws {
        let savedStartTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let editedStartTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T08:30:00+09:00")
        )
        var state = TodayTimeEditModeState()
        state.loadSavedTimes(startTime: savedStartTime, endTime: nil)
        state.beginEditing(.startTime)
        state.updateDraftStartTime(editedStartTime)

        state.cancel()

        #expect(state.savedStartTime == savedStartTime)
        #expect(state.draftStartTime == savedStartTime)
        #expect(state.editingField == nil)
        #expect(state.isEditingStartTime == false)
    }

    @Test
    func endTimeWithoutStartTimeIsInvalid() throws {
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00")
        )
        var state = TodayTimeEditModeState()
        state.loadSavedTimes(startTime: nil, endTime: nil)
        state.beginEditing(.endTime)
        state.updateDraftEndTime(endTime)

        #expect(state.hasValidDraftTimes == false)
    }

    @Test
    func selectingVacationClearsTimesAndMakesDraftValid() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00")
        )
        var state = TodayTimeEditModeState()
        state.loadSavedTimes(startTime: startTime, endTime: endTime)

        let appliedTimes = state.setVacation(true)

        #expect(appliedTimes.startTime == nil)
        #expect(appliedTimes.endTime == nil)
        #expect(state.savedStartTime == nil)
        #expect(state.savedEndTime == nil)
        #expect(state.isVacationSelected)
        #expect(state.hasValidDraftTimes)
    }
}

private final class InMemoryAttendanceRecordStore: AttendanceRecordStore {
    private var records: [AttendanceRecord]
    private let mutationCalendar: Calendar

    init(records: [AttendanceRecord], mutationCalendar: Calendar = makeSeoulCalendar()) {
        self.records = records
        self.mutationCalendar = mutationCalendar
    }

    func record(on date: Date, calendar: Calendar) -> AttendanceRecord? {
        records.last {
            calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    func records(equalTo date: Date, toGranularity granularity: Calendar.Component, calendar: Calendar) -> [AttendanceRecord] {
        records.filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: granularity)
        }
    }

    func loadRecords() -> [AttendanceRecord] {
        records
    }

    func upsertRecord(_ record: AttendanceRecord) throws {
        if let index = records.lastIndex(where: { mutationCalendar.isDate($0.date, inSameDayAs: record.date) }) {
            records[index] = record
            return
        }

        records.append(record)
    }

    func deleteRecord(on date: Date, calendar: Calendar) throws {
        records.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

private struct ThrowingAttendanceRecordStore: AttendanceRecordStore {
    enum TestError: Error {
        case saveFailed
    }

    let records: [AttendanceRecord]

    func record(on date: Date, calendar: Calendar) -> AttendanceRecord? {
        records.last {
            calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    func records(equalTo date: Date, toGranularity granularity: Calendar.Component, calendar: Calendar) -> [AttendanceRecord] {
        records.filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: granularity)
        }
    }

    func upsertRecord(_ record: AttendanceRecord) throws {
        throw TestError.saveFailed
    }

    func deleteRecord(on date: Date, calendar: Calendar) throws {
        throw TestError.saveFailed
    }
}

final class RuntimeFakeRepeatingScheduler: CurrentSessionScheduling {
    private(set) var scheduleCallCount = 0
    private var action: (() -> Void)?

    func scheduleRepeating(every interval: TimeInterval, action: @escaping () -> Void) -> any CurrentSessionCancellable {
        scheduleCallCount += 1
        self.action = action
        return RuntimeFakeCurrentSessionCancellable()
    }

    func fire() {
        action?()
    }
}

private struct RuntimeFakeCurrentSessionCancellable: CurrentSessionCancellable {
    func cancel() {}
}
