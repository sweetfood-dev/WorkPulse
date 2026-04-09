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
        #expect(snapshot.currentSession.isWarningState == false)
    }

    @Test
    @MainActor
    func refreshingCurrentSessionFillsProgressWhenSessionExceedsGoal() throws {
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

        #expect(snapshot.currentSession.valueText == "08:30:00")
        #expect(snapshot.currentSession.progressFraction == 1)
        #expect(snapshot.currentSession.titleText == "🔥 CURRENT SESSION")
        #expect(snapshot.currentSession.isWarningState)
    }

    @Test
    @MainActor
    func refreshingCurrentSessionKeepsNormalStateAtExactlyEightHours() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let baseNow = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:00:00+09:00")
        )
        let now = baseNow.addingTimeInterval(0.2)
        let controller = makeController(currentTimeProvider: { now })

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: startTime, endTime: nil)
        let snapshot = controller.snapshot

        #expect(snapshot.currentSession.valueText == "08:00:00")
        #expect(snapshot.currentSession.titleText == "CURRENT SESSION")
        #expect(snapshot.currentSession.isWarningState == false)
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
        #expect(controller.snapshot.currentSession.titleText == "READY TO CHECK IN")
    }

    @Test
    @MainActor
    func refreshingCurrentSessionShowsWorkedTodayTitleAfterCheckout() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let recordDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")
        )
        let controller = makeController(
            state: MainPopoverViewStateFactory(copy: .english).make(
                referenceDate: recordDate,
                todayRecord: AttendanceRecord(
                    date: recordDate,
                    startTime: startTime,
                    endTime: endTime
                )
            )
        )

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: startTime, endTime: endTime)

        #expect(controller.snapshot.currentSession.titleText == "🔥 WORKED TODAY")
    }

    @Test
    @MainActor
    func initialLoadUsesPreloadedAttendanceState() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let recordDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")
        )
        let controller = makeController(
            state: MainPopoverViewStateFactory(copy: .english).make(
                referenceDate: recordDate,
                todayRecord: AttendanceRecord(
                    date: recordDate,
                    startTime: startTime,
                    endTime: endTime
                )
            )
        )

        controller.loadViewIfNeeded()

        #expect(controller.snapshot.currentSession.titleText == "WORKED TODAY")
    }

    @Test
    @MainActor
    func refreshingCurrentSessionKeepsReadyStateWhenOnlyEndTimeExists() throws {
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let recordDate = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T00:00:00+09:00")
        )
        let controller = makeController(
            state: MainPopoverViewStateFactory(copy: .english).make(
                referenceDate: recordDate,
                todayRecord: AttendanceRecord(
                    date: recordDate,
                    startTime: nil,
                    endTime: endTime
                )
            )
        )

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: nil, endTime: endTime)

        #expect(controller.snapshot.currentSession.titleText == "READY TO CHECK IN")
        #expect(controller.snapshot.currentSession.valueText == "--:--:--")
    }

    @Test
    @MainActor
    func refreshingCurrentSessionDoesNotShowWorkedTodayWhenEndPrecedesStart() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let controller = makeController()

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: startTime, endTime: endTime)

        #expect(controller.snapshot.currentSession.titleText == "CURRENT SESSION")
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
            currentSessionScheduler: scheduler,
            currentSessionCalculator: makeSeoulCurrentSessionCalculator()
        )

        controller.loadViewIfNeeded()
        controller.beginCurrentSessionUpdates(startTime: startTime, endTime: endTime)

        #expect(controller.snapshot.currentSession.valueText == "08:30:00")
        #expect(scheduler.scheduleCallCount == 0)
    }

    @Test
    @MainActor
    func applyingStateRefreshesHeaderAndSummarySections() {
        let controller = makeController()
        let state = MainPopoverViewState(
            attendanceState: .checkedIn,
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
        #expect(snapshot.header.reportButtonTitle == "Report")
        #expect(snapshot.summary.weeklyValueText == "09:05")
        #expect(snapshot.summary.monthlyValueText == "--")
    }

    @Test
    @MainActor
    func tappingReportInvokesCopyQuitReportCallback() {
        let controller = makeController()
        var didTapReport = false
        controller.onCopyQuitReport = {
            didTapReport = true
        }

        controller.loadViewIfNeeded()
        controller.simulateTapReport()

        #expect(didTapReport)
    }

    @MainActor
    private func makeController(
        state: MainPopoverViewState = MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
        currentTimeProvider: @escaping () -> Date = { Date(timeIntervalSince1970: 0) },
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler(),
        currentSessionCalculator: CurrentSessionCalculator = makeSeoulCurrentSessionCalculator()
    ) -> MainPopoverViewController {
        MainPopoverViewController(
            state: state,
            currentSessionCalculator: currentSessionCalculator,
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
                displayState: makeDisplayState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackStartTime: Date(timeIntervalSince1970: 0),
                fallbackEndTime: Date(timeIntervalSince1970: 0)
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
                displayState: makeDisplayState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackStartTime: Date(timeIntervalSince1970: 0),
                fallbackEndTime: Date(timeIntervalSince1970: 0)
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
        binder.setEditingDraft(
            MainPopoverTodayTimesDraft(
                startTime: editedStartTime,
                endTime: originalStartTime
            )
        )
        binder.applyEditing()
        section.sectionView.apply(
            binder.makeRenderModel(
                displayState: makeDisplayState(startTimeText: "08:30", endTimeText: "--:--"),
                fallbackStartTime: editedStartTime,
                fallbackEndTime: editedStartTime
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
        binder.setEditingDraft(
            MainPopoverTodayTimesDraft(
                startTime: startTime,
                endTime: editedEndTime
            )
        )
        binder.applyEditing()
        section.sectionView.apply(
            binder.makeRenderModel(
                displayState: makeDisplayState(startTimeText: "09:00", endTimeText: "17:45"),
                fallbackStartTime: editedEndTime,
                fallbackEndTime: editedEndTime
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
    func deletingSavedEndTimeEmitsNilEndTimeAndReturnsToReadOnlyMode() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let originalEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
        )
        let (binder, section) = makeBinderAndSection()
        var appliedTimes: MainPopoverAppliedTodayTimes?

        binder.onDidApplyTimes = { applied in
            appliedTimes = applied
        }
        binder.loadSavedTimes(startTime: startTime, endTime: originalEndTime)
        binder.beginEditing(.endTime)
        binder.deleteEndTime()
        section.sectionView.apply(
            binder.makeRenderModel(
                displayState: makeDisplayState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackStartTime: startTime,
                fallbackEndTime: startTime
            )
        )
        let snapshot = section.snapshot

        #expect(appliedTimes?.startTime == startTime)
        #expect(appliedTimes?.endTime == nil)
        #expect(snapshot.endRow.valueText == "--:--")
        #expect(snapshot.endRow.isValueVisible)
        #expect(snapshot.endRow.isPickerVisible == false)
        #expect(snapshot.isEndDeleteVisible == false)
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
        binder.setEditingDraft(
            MainPopoverTodayTimesDraft(
                startTime: startTime,
                endTime: invalidEndTime
            )
        )
        binder.applyEditing()
        section.sectionView.apply(
            binder.makeRenderModel(
                displayState: makeDisplayState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackStartTime: invalidEndTime,
                fallbackEndTime: invalidEndTime
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
                displayState: makeDisplayState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackStartTime: currentTime,
                fallbackEndTime: currentTime
            )
        )

        #expect(section.snapshot.endRow.pickerDateValue == currentTime)
    }

    @Test
    @MainActor
    func pickerChangesWhileEditingArePreservedAcrossRerender() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let editedStartTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T08:24:00+09:00")
        )
        let (binder, section) = makeBinderAndSection()

        binder.loadSavedTimes(startTime: startTime, endTime: nil)
        binder.beginEditing(.startTime)
        section.sectionView.apply(
            binder.makeRenderModel(
                displayState: makeDisplayState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackStartTime: startTime,
                fallbackEndTime: startTime
            )
        )

        section.sectionView.simulatePickerChange(editedStartTime, for: .startTime)
        section.sectionView.apply(
            binder.makeRenderModel(
                displayState: makeDisplayState(startTimeText: "09:00", endTimeText: "--:--"),
                fallbackStartTime: startTime,
                fallbackEndTime: startTime
            )
        )

        #expect(section.snapshot.startRow.pickerDateValue == editedStartTime)
        #expect(section.snapshot.isApplyEnabled)
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

    private func makeDisplayState(
        startTimeText: String,
        endTimeText: String
    ) -> MainPopoverTodayTimesDisplayState {
        MainPopoverTodayTimesDisplayState(
            startTimeText: startTimeText,
            endTimeText: endTimeText
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
            notCheckedInSummaryText: "Waiting to start",
            checkedInSummaryPrefix: "Arrived",
            checkedOutSummaryPrefix: "Left at",
            currentSessionPlaceholderText: "00:00:00",
            timePlaceholderText: "--.--",
            totalPlaceholderText: "n/a",
            currentSessionReadyTitle: "READY",
            currentSessionTitle: "SESSION",
            currentSessionWarningTitle: "🔥 SESSION",
            workedTodayTitle: "DONE",
            workedTodayWarningTitle: "🔥 DONE",
            currentSessionLeadingCaption: "0H",
            startTimeTitle: "In",
            endTimeTitle: "Out",
            deleteActionTitle: "Delete",
            backActionTitle: "Back",
            reportActionTitle: "Report",
            weeklyTitle: "Week",
            monthlyTitle: "Month",
            weeklyLabelPrefix: "Week",
            weeklyProgressTitle: "Weekly Progress",
            weeklyProgressSegmentTitle: "Progress",
            weeklyQuitTimeSegmentTitle: "Quit Time",
            weeklyTodayGoalMetText: "Today: Goal met",
            weeklyTodayStatusUnavailableText: "Today: Unavailable",
            monthlyHistoryTitle: "Monthly History",
            monthlyHistoryTotalTitle: "Monthly Total",
            monthlyHistoryEmptyText: "Empty",
            monthlyHistoryInProgressText: "In progress",
            monthlyHistoryOffText: "Off",
            monthlyHistoryHolidayText: "Holiday",
            monthlyHistoryActiveText: "Active",
            currentSessionGoalLabelPrefix: "Goal:"
        )
        let state = MainPopoverViewStateFactory(copy: copy).makePlaceholder()

        #expect(state.dateText == "Placeholder Day")
        #expect(state.checkedInSummaryText == "Waiting to start")
        #expect(state.currentSessionText == "00:00:00")
        #expect(state.startTimeText == "--.--")
        #expect(state.endTimeText == "--.--")
        #expect(state.weeklyTotalText == "n/a")
        #expect(state.monthlyTotalText == "n/a")
        #expect(state.attendanceState == .notCheckedIn)
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
        #expect(state.checkedInSummaryText == "Not checked in yet")
        #expect(state.startTimeText == "--:--")
        #expect(state.endTimeText == "--:--")
        #expect(state.currentSessionText == "--:--:--")
        #expect(state.attendanceState == .notCheckedIn)
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
        #expect(state.checkedInSummaryText == "Checked out at 18:30")
        #expect(state.startTimeText == "09:00")
        #expect(state.endTimeText == "18:30")
        #expect(state.weeklyTotalText == "12:30")
        #expect(state.monthlyTotalText == "44:10")
        #expect(state.attendanceState == .checkedOut)
    }

    @Test
    func treatsEndWithoutStartAsNotCheckedIn() throws {
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
            startTime: nil,
            endTime: try #require(
                ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
            )
        )

        let state = factory.make(
            referenceDate: referenceDate,
            todayRecord: record
        )

        #expect(state.checkedInSummaryText == "Not checked in yet")
        #expect(state.startTimeText == "--:--")
        #expect(state.endTimeText == "18:30")
        #expect(state.attendanceState == .notCheckedIn)
    }

    @Test
    func treatsEndBeforeStartAsCheckedIn() throws {
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
                ISO8601DateFormatter().date(from: "2026-03-31T18:30:00+09:00")
            ),
            endTime: try #require(
                ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
            )
        )

        let state = factory.make(
            referenceDate: referenceDate,
            todayRecord: record
        )

        #expect(state.checkedInSummaryText == "Checked in at 18:30")
        #expect(state.startTimeText == "18:30")
        #expect(state.endTimeText == "09:00")
        #expect(state.attendanceState == .checkedIn)
    }

    private static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}

private func makeSeoulCurrentSessionCalculator() -> CurrentSessionCalculator {
    CurrentSessionCalculator(
        workedDurationCalculator: WorkedDurationCalculator(calendar: makeSeoulCalendar())
    )
}

private func makeSeoulCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
    return calendar
}
