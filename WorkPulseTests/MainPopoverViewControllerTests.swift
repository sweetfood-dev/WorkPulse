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
        let controller = makeController(currentTimeProvider: { now })

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
        let controller = makeController(currentTimeProvider: { now })

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: startTime, endTime: nil)
        let snapshot = controller.snapshot

        #expect(snapshot.currentSession.valueText == "09:30:00")
        #expect(abs(snapshot.currentSession.progressFraction - 0.94) < 0.001)
    }

    @Test
    @MainActor
    func refreshingCurrentSessionKeepsPlaceholderWhenStartTimeIsMissing() {
        let controller = makeController(
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
        let controller = makeController(
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
        let controller = makeController(
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
        let controller = makeController(
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
        let controller = makeController(
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
    func applyingStateRefreshesHeaderAndSummarySections() {
        let controller = makeController()
        let state = MainPopoverViewState(
            dateText: "Wednesday, Apr 1",
            checkedInSummaryText: "Checked in at 08:45",
            currentSessionText: "--:--:--",
            startTimeText: "08:45",
            endTimeText: "--:--",
            weeklyTotalText: "09:05",
            monthlyTotalText: "--"
        )

        controller.loadViewIfNeeded()
        controller.apply(state: state)
        let snapshot = controller.snapshot

        #expect(snapshot.header.dateText == "Wednesday, Apr 1")
        #expect(snapshot.header.checkedInSummaryText == "Checked in at 08:45")
        #expect(snapshot.summary.weeklyValueText == "09:05")
        #expect(snapshot.summary.monthlyValueText == "--")
    }

    @MainActor
    private func makeController(
        state: MainPopoverViewState = MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
        currentTimeProvider: @escaping () -> Date = Date.init,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler()
    ) -> MainPopoverViewController {
        MainPopoverViewController(
            state: state,
            currentTimeProvider: currentTimeProvider,
            currentSessionScheduler: currentSessionScheduler
        )
    }
}

@Suite("MainPopoverTodayTimesBinder")
struct MainPopoverTodayTimesBinderTests {
    @Test
    @MainActor
    func beginningStartTimeEditingShowsPickerInTheSameRow() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let (binder, section) = makeBinderAndSection()

        binder.loadSavedTimes(startTime: startTime, endTime: nil)
        binder.beginEditing(.startTime)
        section.sectionView.apply(
            binder.makeRenderModel(
                viewState: makeViewState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackTime: Date(timeIntervalSince1970: 0)
            )
        )
        let snapshot = section.snapshot

        #expect(snapshot.startRow.isValueVisible == false)
        #expect(snapshot.startRow.isPickerVisible)
        #expect(snapshot.startRow.pickerDateValue == startTime)
        #expect(snapshot.isStartApplyVisible)
        #expect(snapshot.isApplyEnabled)
        #expect(snapshot.isStartCancelVisible)
        #expect(snapshot.endRow.isValueVisible)
    }

    @Test
    @MainActor
    func cancelingStartTimeEditingReturnsToReadOnlyMode() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let (binder, section) = makeBinderAndSection()

        binder.loadSavedTimes(startTime: startTime, endTime: nil)
        binder.beginEditing(.startTime)
        binder.cancelEditing()
        section.sectionView.apply(
            binder.makeRenderModel(
                viewState: makeViewState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackTime: Date(timeIntervalSince1970: 0)
            )
        )
        let snapshot = section.snapshot

        #expect(snapshot.startRow.isValueVisible)
        #expect(snapshot.startRow.isPickerVisible == false)
        #expect(snapshot.isStartApplyVisible == false)
        #expect(snapshot.isStartCancelVisible == false)
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
        let (binder, section) = makeBinderAndSection()
        var appliedTimes: MainPopoverAppliedTodayTimes?

        binder.onDidApplyTimes = { applied in
            appliedTimes = applied
        }
        binder.loadSavedTimes(startTime: originalStartTime, endTime: nil)
        binder.beginEditing(.startTime)
        binder.setPickerDate(editedStartTime, for: .startTime)
        binder.applyEditing()
        section.sectionView.apply(
            binder.makeRenderModel(
                viewState: makeViewState(startTimeText: "08:30", endTimeText: "--:--"),
                fallbackTime: editedStartTime
            )
        )
        let snapshot = section.snapshot

        #expect(appliedTimes?.startTime == editedStartTime)
        #expect(appliedTimes?.endTime == nil)
        #expect(snapshot.startRow.valueText == "08:30")
        #expect(snapshot.startRow.isValueVisible)
        #expect(snapshot.startRow.isPickerVisible == false)
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
        let (binder, section) = makeBinderAndSection()
        var appliedTimes: MainPopoverAppliedTodayTimes?

        binder.onDidApplyTimes = { applied in
            appliedTimes = applied
        }
        binder.loadSavedTimes(startTime: startTime, endTime: originalEndTime)
        binder.beginEditing(.endTime)
        binder.setPickerDate(editedEndTime, for: .endTime)
        binder.applyEditing()
        section.sectionView.apply(
            binder.makeRenderModel(
                viewState: makeViewState(startTimeText: "09:00", endTimeText: "17:45"),
                fallbackTime: editedEndTime
            )
        )
        let snapshot = section.snapshot

        #expect(appliedTimes?.startTime == startTime)
        #expect(appliedTimes?.endTime == editedEndTime)
        #expect(snapshot.endRow.valueText == "17:45")
        #expect(snapshot.endRow.isValueVisible)
        #expect(snapshot.endRow.isPickerVisible == false)
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
        let (binder, section) = makeBinderAndSection()
        var applyCallCount = 0

        binder.onDidApplyTimes = { _ in
            applyCallCount += 1
        }
        binder.loadSavedTimes(startTime: startTime, endTime: nil)
        binder.beginEditing(.endTime)
        binder.setPickerDate(invalidEndTime, for: .endTime)
        binder.applyEditing()
        section.sectionView.apply(
            binder.makeRenderModel(
                viewState: makeViewState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackTime: invalidEndTime
            )
        )
        let snapshot = section.snapshot

        #expect(applyCallCount == 0)
        #expect(snapshot.endRow.valueText == "--:--")
        #expect(snapshot.endRow.isValueVisible == false)
        #expect(snapshot.endRow.isPickerVisible)
        #expect(snapshot.isEndApplyVisible)
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
        let (binder, section) = makeBinderAndSection()

        binder.loadSavedTimes(startTime: startTime, endTime: previousEndTime)
        binder.loadSavedTimes(startTime: startTime, endTime: nil)
        binder.beginEditing(.endTime)
        section.sectionView.apply(
            binder.makeRenderModel(
                viewState: makeViewState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackTime: currentTime
            )
        )

        #expect(section.snapshot.endRow.pickerDateValue == currentTime)
    }

    @MainActor
    private func makeBinderAndSection() -> (MainPopoverTodayTimesBinder, MainPopoverViewSnapshottingSection) {
        let section = MainPopoverViewSnapshottingSection()
        let binder = MainPopoverTodayTimesBinder(
            sectionView: section.sectionView,
            copy: .english
        )
        return (binder, section)
    }

    private func makeViewState(
        startTimeText: String,
        endTimeText: String
    ) -> MainPopoverViewState {
        MainPopoverViewState(
            dateText: "Wednesday, Apr 1",
            checkedInSummaryText: "Checked in at 08:45",
            currentSessionText: "--:--:--",
            startTimeText: startTimeText,
            endTimeText: endTimeText,
            weeklyTotalText: "09:05",
            monthlyTotalText: "--"
        )
    }
}

private struct MainPopoverViewSnapshottingSection {
    let sectionView = MainPopoverTodayTimesSectionView(frame: NSRect(x: 0, y: 0, width: 392, height: 146))

    var snapshot: MainPopoverTodayTimesSectionSnapshot {
        sectionView.snapshot
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
