import AppKit
import Testing
@testable import WorkPulse

@Suite("MainPopoverViewController")
struct MainPopoverViewControllerTests {
    @Test
    @MainActor
    func refreshingCurrentSessionUsesStartTimeAndClockProvider() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:30+09:00")
        )
        let controller = MainPopoverViewController(
            currentTimeProvider: { now }
        )

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: startTime, endTime: nil)
        let snapshot = controller.snapshot

        #expect(snapshot.currentSession.valueText == "02:45:30")
        #expect(abs(snapshot.currentSession.progressFraction - 0.3448) < 0.001)
    }

    @Test
    @MainActor
    func refreshingCurrentSessionLeavesVisibleTrackWhenSessionExceedsGoal() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T08:00:00+09:00")
        )
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T17:30:00+09:00")
        )
        let controller = MainPopoverViewController(
            currentTimeProvider: { now }
        )

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: startTime, endTime: nil)
        let snapshot = controller.snapshot

        #expect(snapshot.currentSession.valueText == "09:30:00")
        #expect(abs(snapshot.currentSession.progressFraction - 0.94) < 0.001)
    }

    @Test
    @MainActor
    func refreshingCurrentSessionKeepsPlaceholderWhenStartTimeIsMissing() {
        let controller = MainPopoverViewController(
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: nil, endTime: nil)

        #expect(controller.snapshot.currentSession.valueText == "--:--:--")
    }

    @Test
    @MainActor
    func beginningCurrentSessionUpdatesRefreshesImmediatelyAndOnEveryTick() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        var now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:30+09:00")
        )
        let scheduler = FakeRepeatingScheduler()
        let controller = MainPopoverViewController(
            currentTimeProvider: { now },
            currentSessionScheduler: scheduler
        )

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: nil)

        #expect(controller.snapshot.currentSession.valueText == "02:45:30")
        #expect(scheduler.scheduleCallCount == 1)

        now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:31+09:00")
        )
        scheduler.fire()

        #expect(controller.snapshot.currentSession.valueText == "02:45:31")
    }

    @Test
    @MainActor
    func stoppingCurrentSessionUpdatesCancelsRepeatingRefresh() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        var now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:30+09:00")
        )
        let scheduler = FakeRepeatingScheduler()
        let controller = MainPopoverViewController(
            currentTimeProvider: { now },
            currentSessionScheduler: scheduler
        )

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: nil)
        controller.stopCurrentSessionUpdates()

        #expect(scheduler.cancellable.cancelCallCount == 1)

        now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:31+09:00")
        )
        scheduler.fire()

        #expect(controller.snapshot.currentSession.valueText == "02:45:30")
    }

    @Test
    @MainActor
    func beginningCurrentSessionUpdatesDoesNotScheduleWithoutStartTime() {
        let scheduler = FakeRepeatingScheduler()
        let controller = MainPopoverViewController(
            currentTimeProvider: { Date(timeIntervalSince1970: 0) },
            currentSessionScheduler: scheduler
        )

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: nil, endTime: nil)

        #expect(controller.snapshot.currentSession.valueText == "--:--:--")
        #expect(scheduler.scheduleCallCount == 0)
    }

    @Test
    @MainActor
    func beginningCurrentSessionUpdatesShowsFixedDurationAndDoesNotScheduleWhenEndTimeExists() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let scheduler = FakeRepeatingScheduler()
        let controller = MainPopoverViewController(
            currentTimeProvider: {
                ISO8601DateFormatter().date(from: "2026-03-31T20:00:00+09:00")
                ?? Date(timeIntervalSince1970: 0)
            },
            currentSessionScheduler: scheduler
        )

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: endTime)

        #expect(controller.snapshot.currentSession.valueText == "09:30:00")
        #expect(scheduler.scheduleCallCount == 0)
    }

    @Test
    @MainActor
    func beginningStartTimeEditingShowsPickerInTheSameRow() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let controller = MainPopoverViewController()

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: nil)
        controller.beginEditingStartTime()
        let snapshot = controller.snapshot

        #expect(snapshot.todayTimes.startRow.isValueVisible == false)
        #expect(snapshot.todayTimes.startRow.isPickerVisible)
        #expect(snapshot.todayTimes.startRow.pickerDateValue == startTime)
        #expect(snapshot.todayTimes.isStartApplyVisible)
        #expect(snapshot.todayTimes.isApplyEnabled)
        #expect(snapshot.todayTimes.isStartCancelVisible)
        #expect(snapshot.todayTimes.endRow.isValueVisible)
    }

    @Test
    @MainActor
    func cancelingStartTimeEditingReturnsToReadOnlyMode() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let controller = MainPopoverViewController()

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: nil)
        controller.beginEditingStartTime()
        controller.cancelEditingTime()
        let snapshot = controller.snapshot

        #expect(snapshot.todayTimes.startRow.isValueVisible)
        #expect(snapshot.todayTimes.startRow.isPickerVisible == false)
        #expect(snapshot.todayTimes.isStartApplyVisible == false)
        #expect(snapshot.todayTimes.isStartCancelVisible == false)
    }

    @Test
    @MainActor
    func beginningEndTimeEditingShowsEndPickerInTheSameRow() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let controller = MainPopoverViewController()

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: endTime)
        controller.beginEditingEndTime()
        let snapshot = controller.snapshot

        #expect(snapshot.todayTimes.endRow.isValueVisible == false)
        #expect(snapshot.todayTimes.endRow.isPickerVisible)
        #expect(snapshot.todayTimes.endRow.pickerDateValue == endTime)
        #expect(snapshot.todayTimes.isEndApplyVisible)
        #expect(snapshot.todayTimes.isApplyEnabled)
        #expect(snapshot.todayTimes.isEndCancelVisible)
        #expect(snapshot.todayTimes.startRow.isValueVisible)
    }

    @Test
    @MainActor
    func applyingStartTimeEditEmitsUpdatedTodayTimesAndReturnsToReadOnlyMode() throws {
        let originalStartTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let editedStartTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T08:30:00+09:00")
        )
        let controller = MainPopoverViewController()
        var appliedStartTime: Date?
        var appliedEndTime: Date?
        controller.onApplyEditedTimes = { startTime, endTime in
            appliedStartTime = startTime
            appliedEndTime = endTime
        }

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: originalStartTime, endTime: nil)
        controller.beginEditingStartTime()
        controller.setPickerDate(editedStartTime, for: .startTime)
        controller.applyEditingTime()
        let snapshot = controller.snapshot

        #expect(appliedStartTime == editedStartTime)
        #expect(appliedEndTime == nil)
        #expect(snapshot.todayTimes.startRow.valueText == "08:30")
        #expect(snapshot.todayTimes.startRow.isValueVisible)
        #expect(snapshot.todayTimes.startRow.isPickerVisible == false)
    }

    @Test
    @MainActor
    func applyingEndTimeEditEmitsUpdatedTodayTimesAndReturnsToReadOnlyMode() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let originalEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let editedEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T17:45:00+09:00")
        )
        let controller = MainPopoverViewController()
        var appliedStartTime: Date?
        var appliedEndTime: Date?
        controller.onApplyEditedTimes = { startTime, endTime in
            appliedStartTime = startTime
            appliedEndTime = endTime
        }

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: originalEndTime)
        controller.beginEditingEndTime()
        controller.setPickerDate(editedEndTime, for: .endTime)
        controller.applyEditingTime()
        let snapshot = controller.snapshot

        #expect(appliedStartTime == startTime)
        #expect(appliedEndTime == editedEndTime)
        #expect(snapshot.todayTimes.endRow.valueText == "17:45")
        #expect(snapshot.todayTimes.endRow.isValueVisible)
        #expect(snapshot.todayTimes.endRow.isPickerVisible == false)
    }

    @Test
    @MainActor
    func applyingEndTimeEarlierThanStartTimeDoesNotEmitInvalidTimes() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let invalidEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T08:30:00+09:00")
        )
        let controller = MainPopoverViewController()
        var applyCallCount = 0
        controller.onApplyEditedTimes = { _, _ in
            applyCallCount += 1
        }

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: nil)
        controller.beginEditingEndTime()
        controller.setPickerDate(invalidEndTime, for: .endTime)
        controller.applyEditingTime()
        let snapshot = controller.snapshot

        #expect(applyCallCount == 0)
        #expect(snapshot.todayTimes.endRow.valueText == "--:--")
        #expect(snapshot.todayTimes.endRow.isValueVisible == false)
        #expect(snapshot.todayTimes.endRow.isPickerVisible)
        #expect(snapshot.todayTimes.isEndApplyVisible)
    }

    @Test
    @MainActor
    func beginningEditingEmptyEndTimeResetsPickerAwayFromPreviousStaleValue() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let previousEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let currentTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T14:15:00+09:00")
        )
        let controller = MainPopoverViewController(
            currentTimeProvider: { currentTime }
        )

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: previousEndTime)
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: nil)
        controller.beginEditingEndTime()

        #expect(controller.snapshot.todayTimes.endRow.pickerDateValue == currentTime)
    }

}

final class FakeRepeatingScheduler: CurrentSessionScheduling {
    private(set) var scheduleCallCount = 0
    let cancellable = FakeCurrentSessionCancellable()
    private var action: (() -> Void)?

    func scheduleRepeating(every interval: TimeInterval, action: @escaping () -> Void) -> any CurrentSessionCancellable {
        scheduleCallCount += 1
        self.action = action
        return cancellable
    }

    func fire() {
        guard cancellable.cancelCallCount == 0 else { return }
        action?()
    }
}

final class FakeCurrentSessionCancellable: CurrentSessionCancellable {
    private(set) var cancelCallCount = 0

    func cancel() {
        cancelCallCount += 1
    }
}

@Suite("MainPopoverViewStateFactory")
struct MainPopoverViewStateFactoryTests {
    @Test
    func makesPlaceholderStateFromCopy() {
        let copy = MainPopoverCopy(
            placeholderDateText: "Placeholder Day",
            checkedInSummaryPrefix: "Arrived",
            currentSessionPlaceholderText: "00:00:00",
            timePlaceholderText: "--.--",
            totalPlaceholderText: "n/a",
            currentSessionTitle: "SESSION",
            currentSessionLeadingCaption: "0H",
            startTimeTitle: "In",
            endTimeTitle: "Out",
            weeklyTitle: "Week",
            monthlyTitle: "Month",
            currentSessionGoalLabelPrefix: "Goal:"
        )
        let state = MainPopoverViewStateFactory(copy: copy).makePlaceholder()

        #expect(state.dateText == "Placeholder Day")
        #expect(state.checkedInSummaryText == "Arrived --.--")
        #expect(state.currentSessionText == "00:00:00")
        #expect(state.startTimeText == "--.--")
        #expect(state.endTimeText == "--.--")
        #expect(state.weeklyTotalText == "n/a")
        #expect(state.monthlyTotalText == "n/a")
    }

    @Test
    func makesPlaceholderStateWhenTodayRecordIsMissing() throws {
        let factory = MainPopoverViewStateFactory(
            calendar: Self.seoulCalendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        )
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )

        let state = factory.make(
            referenceDate: referenceDate,
            todayRecord: nil
        )

        #expect(state.dateText == "Tuesday, Mar 31")
        #expect(state.checkedInSummaryText == "Checked in at --:--")
        #expect(state.startTimeText == "--:--")
        #expect(state.endTimeText == "--:--")
        #expect(state.currentSessionText == "--:--:--")
    }

    @Test
    func usesTodayRecordTimesInReadOnlyState() throws {
        let factory = MainPopoverViewStateFactory(
            calendar: Self.seoulCalendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        )
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let record = AttendanceRecord(
            date: referenceDate,
            startTime: try #require(
                ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
            ),
            endTime: try #require(
                ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
            )
        )

        let state = factory.make(
            referenceDate: referenceDate,
            todayRecord: record,
            weeklyTotalText: "12:30",
            monthlyTotalText: "44:10"
        )

        #expect(state.dateText == "Tuesday, Mar 31")
        #expect(state.checkedInSummaryText == "Checked in at 09:00")
        #expect(state.startTimeText == "09:00")
        #expect(state.endTimeText == "18:30")
        #expect(state.weeklyTotalText == "12:30")
        #expect(state.monthlyTotalText == "44:10")
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}
