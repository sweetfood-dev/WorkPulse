import AppKit
import Testing
@testable import WorkPulse

@Suite("MainPopoverViewController")
struct MainPopoverViewControllerTests {
    @Test
    @MainActor
    func loadsReadOnlyDashboardPlaceholderState() {
        let controller = MainPopoverViewController()

        controller.loadViewIfNeeded()

        #expect(controller.dateLabel.stringValue == "Today")
        #expect(controller.checkedInSummaryLabel.stringValue == "Checked in at --:--")
        #expect(controller.currentSessionTitleLabel.stringValue == "Current Session")
        #expect(controller.currentSessionValueLabel.stringValue == "--:--:--")
        #expect(controller.startTimeTitleLabel.stringValue == "Start Time")
        #expect(controller.startTimeValueLabel.stringValue == "--:--")
        #expect(controller.endTimeTitleLabel.stringValue == "End Time")
        #expect(controller.endTimeValueLabel.stringValue == "--:--")
        #expect(controller.weeklyTitleLabel.stringValue == "This Week")
        #expect(controller.weeklyValueLabel.stringValue == "--")
        #expect(controller.monthlyTitleLabel.stringValue == "This Month")
        #expect(controller.monthlyValueLabel.stringValue == "--")
    }

    @Test
    @MainActor
    func applyingReadOnlyDashboardStateUpdatesDisplayedValues() {
        let controller = MainPopoverViewController()
        let state = MainPopoverViewState(
            dateText: "Thursday, Mar 31",
            checkedInSummaryText: "Checked in at 09:00",
            currentSessionText: "02:15:30",
            startTimeText: "09:00",
            endTimeText: "--:--",
            weeklyTotalText: "08:30",
            monthlyTotalText: "42:10"
        )

        controller.loadViewIfNeeded()
        controller.apply(state: state)

        #expect(controller.dateLabel.stringValue == "Thursday, Mar 31")
        #expect(controller.checkedInSummaryLabel.stringValue == "Checked in at 09:00")
        #expect(controller.currentSessionValueLabel.stringValue == "02:15:30")
        #expect(controller.startTimeValueLabel.stringValue == "09:00")
        #expect(controller.endTimeValueLabel.stringValue == "--:--")
        #expect(controller.weeklyValueLabel.stringValue == "08:30")
        #expect(controller.monthlyValueLabel.stringValue == "42:10")
    }

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

        #expect(controller.currentSessionValueLabel.stringValue == "02:45:30")
    }

    @Test
    @MainActor
    func refreshingCurrentSessionKeepsPlaceholderWhenStartTimeIsMissing() {
        let controller = MainPopoverViewController(
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: nil, endTime: nil)

        #expect(controller.currentSessionValueLabel.stringValue == "--:--:--")
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

        #expect(controller.currentSessionValueLabel.stringValue == "02:45:30")
        #expect(scheduler.scheduleCallCount == 1)

        now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:31+09:00")
        )
        scheduler.fire()

        #expect(controller.currentSessionValueLabel.stringValue == "02:45:31")
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

        #expect(controller.currentSessionValueLabel.stringValue == "--:--:--")
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

        #expect(controller.currentSessionValueLabel.stringValue == "09:30:00")
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

        #expect(controller.startTimeValueLabel.isHidden)
        #expect(controller.startTimePicker.isHidden == false)
        #expect(controller.startTimePicker.dateValue == startTime)
        #expect(controller.startTimeApplyButton.isHidden == false)
        #expect(controller.startTimeApplyButton.isEnabled == false)
        #expect(controller.startTimeCancelButton.isHidden == false)
        #expect(controller.endTimeValueLabel.isHidden == false)
        #expect(controller.currentSessionValueLabel.isHidden == false)
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

        #expect(controller.startTimeValueLabel.isHidden == false)
        #expect(controller.startTimePicker.isHidden)
        #expect(controller.startTimeApplyButton.isHidden)
        #expect(controller.startTimeCancelButton.isHidden)
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

        #expect(controller.endTimeValueLabel.isHidden)
        #expect(controller.endTimePicker.isHidden == false)
        #expect(controller.endTimePicker.dateValue == endTime)
        #expect(controller.endTimeApplyButton.isHidden == false)
        #expect(controller.endTimeApplyButton.isEnabled == false)
        #expect(controller.endTimeCancelButton.isHidden == false)
        #expect(controller.startTimeValueLabel.isHidden == false)
    }
}

private final class FakeRepeatingScheduler: CurrentSessionScheduling {
    private(set) var scheduleCallCount = 0
    private var action: (() -> Void)?

    func scheduleRepeating(every interval: TimeInterval, action: @escaping () -> Void) -> any CurrentSessionCancellable {
        scheduleCallCount += 1
        self.action = action
        return FakeCurrentSessionCancellable()
    }

    func fire() {
        action?()
    }
}

private struct FakeCurrentSessionCancellable: CurrentSessionCancellable {
    func cancel() {}
}

@Suite("MainPopoverViewStateFactory")
struct MainPopoverViewStateFactoryTests {
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
