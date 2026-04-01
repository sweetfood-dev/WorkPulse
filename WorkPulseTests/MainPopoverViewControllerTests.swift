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
        controller.view.layoutSubtreeIfNeeded()

        #expect(controller.headerSectionView.dateLabel.stringValue == "Today")
        #expect(controller.headerSectionView.checkedInSummaryLabel.stringValue == "Checked in at --:--")
        #expect(controller.currentSessionSectionView.titleLabel.stringValue == "CURRENT SESSION")
        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "--:--:--")
        #expect(controller.currentSessionSectionView.leadingCaptionLabel.stringValue == "0H")
        #expect(controller.currentSessionSectionView.trailingCaptionLabel.stringValue == "Goal: 8h")
        #expect(controller.currentSessionSectionView.progressBar.progressFraction == 0)
        #expect(controller.currentSessionSectionView.progressBar.trackBorderWidth > 0)
        #expect(controller.todayTimesSectionView.startRowView.titleLabel.stringValue == "Start Time")
        #expect(controller.todayTimesSectionView.startRowView.valueLabel.stringValue == "--:--")
        #expect(controller.todayTimesSectionView.endRowView.titleLabel.stringValue == "End Time")
        #expect(controller.todayTimesSectionView.endRowView.valueLabel.stringValue == "--:--")
        #expect(controller.summarySectionView.weeklyTitleLabel.stringValue == "This Week")
        #expect(controller.summarySectionView.weeklyValueLabel.stringValue == "--")
        #expect(controller.summarySectionView.monthlyTitleLabel.stringValue == "This Month")
        #expect(controller.summarySectionView.monthlyValueLabel.stringValue == "--")
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

        #expect(controller.headerSectionView.dateLabel.stringValue == "Thursday, Mar 31")
        #expect(controller.headerSectionView.checkedInSummaryLabel.stringValue == "Checked in at 09:00")
        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "02:15:30")
        #expect(controller.todayTimesSectionView.startRowView.valueLabel.stringValue == "09:00")
        #expect(controller.todayTimesSectionView.endRowView.valueLabel.stringValue == "--:--")
        #expect(controller.summarySectionView.weeklyValueLabel.stringValue == "08:30")
        #expect(controller.summarySectionView.monthlyValueLabel.stringValue == "42:10")
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

        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "02:45:30")
        #expect(abs(controller.currentSessionSectionView.progressBar.progressFraction - 0.3448) < 0.001)
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

        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "09:30:00")
        #expect(abs(controller.currentSessionSectionView.progressBar.progressFraction - 0.94) < 0.001)
    }

    @Test
    @MainActor
    func refreshingCurrentSessionKeepsPlaceholderWhenStartTimeIsMissing() {
        let controller = MainPopoverViewController(
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: nil, endTime: nil)

        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "--:--:--")
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

        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "02:45:30")
        #expect(scheduler.scheduleCallCount == 1)

        now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:31+09:00")
        )
        scheduler.fire()

        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "02:45:31")
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

        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "02:45:30")
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

        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "--:--:--")
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

        #expect(controller.currentSessionSectionView.valueLabel.stringValue == "09:30:00")
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

        #expect(controller.todayTimesSectionView.startRowView.valueLabel.isHidden)
        #expect(controller.todayTimesSectionView.startRowView.picker.isHidden == false)
        #expect(controller.todayTimesSectionView.startRowView.picker.dateValue == startTime)
        #expect(controller.todayTimesSectionView.startTimeApplyButton.isHidden == false)
        #expect(controller.todayTimesSectionView.startTimeApplyButton.isEnabled)
        #expect(controller.todayTimesSectionView.startTimeCancelButton.isHidden == false)
        #expect(controller.todayTimesSectionView.endRowView.valueLabel.isHidden == false)
        #expect(controller.currentSessionSectionView.valueLabel.isHidden == false)
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

        #expect(controller.todayTimesSectionView.startRowView.valueLabel.isHidden == false)
        #expect(controller.todayTimesSectionView.startRowView.picker.isHidden)
        #expect(controller.todayTimesSectionView.startTimeApplyButton.isHidden)
        #expect(controller.todayTimesSectionView.startTimeCancelButton.isHidden)
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

        #expect(controller.todayTimesSectionView.endRowView.valueLabel.isHidden)
        #expect(controller.todayTimesSectionView.endRowView.picker.isHidden == false)
        #expect(controller.todayTimesSectionView.endRowView.picker.dateValue == endTime)
        #expect(controller.todayTimesSectionView.endTimeApplyButton.isHidden == false)
        #expect(controller.todayTimesSectionView.endTimeApplyButton.isEnabled)
        #expect(controller.todayTimesSectionView.endTimeCancelButton.isHidden == false)
        #expect(controller.todayTimesSectionView.startRowView.valueLabel.isHidden == false)
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
        controller.todayTimesSectionView.startRowView.picker.dateValue = editedStartTime
        controller.applyEditingTime()

        #expect(appliedStartTime == editedStartTime)
        #expect(appliedEndTime == nil)
        #expect(controller.todayTimesSectionView.startRowView.valueLabel.stringValue == "08:30")
        #expect(controller.todayTimesSectionView.startRowView.valueLabel.isHidden == false)
        #expect(controller.todayTimesSectionView.startRowView.picker.isHidden)
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
        controller.todayTimesSectionView.endRowView.picker.dateValue = editedEndTime
        controller.applyEditingTime()

        #expect(appliedStartTime == startTime)
        #expect(appliedEndTime == editedEndTime)
        #expect(controller.todayTimesSectionView.endRowView.valueLabel.stringValue == "17:45")
        #expect(controller.todayTimesSectionView.endRowView.valueLabel.isHidden == false)
        #expect(controller.todayTimesSectionView.endRowView.picker.isHidden)
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
        controller.todayTimesSectionView.endRowView.picker.dateValue = invalidEndTime
        controller.applyEditingTime()

        #expect(applyCallCount == 0)
        #expect(controller.todayTimesSectionView.endRowView.valueLabel.stringValue == "--:--")
        #expect(controller.todayTimesSectionView.endRowView.valueLabel.isHidden)
        #expect(controller.todayTimesSectionView.endRowView.picker.isHidden == false)
        #expect(controller.todayTimesSectionView.endTimeApplyButton.isHidden == false)
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

        #expect(controller.todayTimesSectionView.endRowView.picker.dateValue == currentTime)
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
