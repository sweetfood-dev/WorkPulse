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
            totalsCalculator: AttendanceRecordTotalsCalculator(),
            calendar: Self.seoulCalendar
        )

        let loadedState = loader.load(referenceDate: referenceDate)

        #expect(loadedState.todayRecord == todayRecord)
        #expect(loadedState.viewState.dateText == "Tuesday, Mar 31")
        #expect(loadedState.viewState.checkedInSummaryText == "Checked in at 09:00")
        #expect(loadedState.viewState.startTimeText == "09:00")
        #expect(loadedState.viewState.endTimeText == "--:--")
        #expect(loadedState.viewState.weeklyTotalText == "17:00")
        #expect(loadedState.viewState.monthlyTotalText == "17:30")
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
            totalsCalculator: AttendanceRecordTotalsCalculator(),
            calendar: Self.seoulCalendar
        )

        let loadedState = loader.load(referenceDate: referenceDate)

        #expect(loadedState.todayRecord == nil)
        #expect(loadedState.viewState.checkedInSummaryText == "Checked in at --:--")
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
            totalsCalculator: AttendanceRecordTotalsCalculator(),
            calendar: Self.seoulCalendar
        )

        let loadedState = loader.load(referenceDate: referenceDate)

        #expect(loadedState.viewState.weeklyTotalText == "09:00")
        #expect(loadedState.viewState.monthlyTotalText == "17:30")
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

        store.upsertRecord(record)

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

        store.upsertRecord(originalRecord)
        store.upsertRecord(editedRecord)

        #expect(store.loadRecords() == [editedRecord])
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
            currentTimeProvider: { referenceDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                currentDateProvider: { referenceDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: store
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: referenceDate)
        controller.beginEditingEndTime()
        controller.endTimePicker.dateValue = endTime
        controller.applyEditingTime()

        let persistedTodayRecord = try #require(
            store.loadRecords().last(where: { Calendar.current.isDate($0.date, inSameDayAs: referenceDate) })
        )
        #expect(persistedTodayRecord.startTime == startTime)
        #expect(persistedTodayRecord.endTime == endTime)
        #expect(controller.endTimeValueLabel.stringValue == "18:30")
        #expect(controller.currentSessionValueLabel.stringValue == "09:30:00")
        #expect(controller.weeklyValueLabel.stringValue == "17:30")
        #expect(controller.monthlyValueLabel.stringValue == "17:30")
    }

    @Test
    @MainActor
    func configurePopoverUsesInjectedCalendarLocaleAndTimeZone() throws {
        let seoulTimeZone = try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T15:30:00Z")
        )
        let controller = MainPopoverViewController(
            currentTimeProvider: { referenceDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: seoulTimeZone,
                currentDateProvider: { referenceDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: InMemoryAttendanceRecordStore(records: [])
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: referenceDate)

        #expect(controller.dateLabel.stringValue == "Wednesday, Apr 1")
    }

    @Test
    @MainActor
    func applyingEditedTimesUsesDisplayedReferenceDateInsteadOfCurrentClockDate() throws {
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
        let controller = MainPopoverViewController(
            currentTimeProvider: { currentClockDate }
        )
        let appDelegate = AppDelegate(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: Self.seoulCalendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                currentDateProvider: { currentClockDate },
                currentSessionScheduler: FakeRepeatingScheduler()
            ),
            recordStore: store
        )

        controller.loadViewIfNeeded()
        appDelegate.configurePopoverViewController(controller, referenceDate: displayedReferenceDate)
        controller.beginEditingEndTime()
        controller.endTimePicker.dateValue = endTime
        controller.applyEditingTime()

        let displayedDayRecord = try #require(
            store.loadRecords().last(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: displayedReferenceDate)
            })
        )
        #expect(displayedDayRecord.endTime == endTime)
        #expect(
            store.loadRecords().contains(where: {
                Self.seoulCalendar.isDate($0.date, inSameDayAs: currentClockDate)
            }) == false
        )
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
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
}

private final class InMemoryAttendanceRecordStore: AttendanceRecordStore {
    private var records: [AttendanceRecord]

    init(records: [AttendanceRecord]) {
        self.records = records
    }

    func loadRecords() -> [AttendanceRecord] {
        records
    }

    func upsertRecord(_ record: AttendanceRecord) {
        if let index = records.lastIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: record.date) }) {
            records[index] = record
            return
        }

        records.append(record)
    }
}
