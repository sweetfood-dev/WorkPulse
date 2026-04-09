import AppKit

protocol StringClipboardWriting {
    func copy(_ string: String)
}

struct NSPasteboardStringClipboardWriter: StringClipboardWriting {
    func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

@MainActor
final class MainPopoverCoordinator {
    private static let isGeometryDebugEnabled =
        ProcessInfo.processInfo.environment["WORKPULSE_DEBUG_POPOVER_GEOMETRY"] == "1"

    private weak var popoverViewController: MainPopoverViewController?
    private var displayedReferenceDate: Date?
    private var displayedWeeklyProgressReferenceDate: Date?
    private var displayedMonthlyHistoryReferenceDate: Date?
    private let runtimeDependencies: MainPopoverRuntimeDependencies
    private let recordStore: any AttendanceRecordStore
    private let viewStateFactory: MainPopoverViewStateFactory
    private let stateLoader: MainPopoverStateLoader
    private let workedDurationCalculator: WorkedDurationCalculator
    private let todayQuitReportBuilder: TodayQuitReportBuilder
    private let clipboardWriter: any StringClipboardWriting
    private let weeklyProgressLoader: MainPopoverWeeklyProgressLoader
    private let monthlyHistoryLoader: MonthlyHistoryLoader
    var onDidUpdateAttendanceState: ((MainPopoverAttendanceState) -> Void)?

    init(
        runtimeDependencies: MainPopoverRuntimeDependencies,
        recordStore: any AttendanceRecordStore,
        clipboardWriter: any StringClipboardWriting = NSPasteboardStringClipboardWriter()
    ) {
        self.runtimeDependencies = runtimeDependencies
        self.recordStore = recordStore
        self.clipboardWriter = clipboardWriter
        self.workedDurationCalculator = WorkedDurationCalculator(
            calendar: runtimeDependencies.calendar
        )
        self.todayQuitReportBuilder = TodayQuitReportBuilder(
            calendar: runtimeDependencies.calendar,
            locale: runtimeDependencies.locale,
            timeZone: runtimeDependencies.timeZone
        )
        self.viewStateFactory = MainPopoverViewStateFactory(
            calendar: runtimeDependencies.calendar,
            locale: runtimeDependencies.locale,
            timeZone: runtimeDependencies.timeZone
        )
        self.stateLoader = MainPopoverStateLoader(
            recordStore: recordStore,
            viewStateFactory: viewStateFactory,
            calendar: runtimeDependencies.calendar
        )
        self.weeklyProgressLoader = MainPopoverWeeklyProgressLoader(
            recordStore: recordStore,
            calendar: runtimeDependencies.calendar,
            locale: runtimeDependencies.locale,
            timeZone: runtimeDependencies.timeZone,
            calendarDayMetadataProvider: runtimeDependencies.calendarDayMetadataProvider,
            currentDateProvider: runtimeDependencies.currentDateProvider
        )
        self.monthlyHistoryLoader = MonthlyHistoryLoader(
            recordStore: recordStore,
            calendar: runtimeDependencies.calendar,
            locale: runtimeDependencies.locale,
            timeZone: runtimeDependencies.timeZone,
            calendarDayMetadataProvider: runtimeDependencies.calendarDayMetadataProvider,
            currentDateProvider: runtimeDependencies.currentDateProvider
        )
    }

    func makePopoverViewController(
        referenceDate: Date? = nil
    ) -> MainPopoverViewController {
        let popoverViewController = MainPopoverViewController(
            state: viewStateFactory.makePlaceholder(),
            currentSessionCalculator: CurrentSessionCalculator(
                workedDurationCalculator: workedDurationCalculator
            ),
            currentTimeProvider: runtimeDependencies.currentDateProvider,
            currentSessionScheduler: runtimeDependencies.currentSessionScheduler
        )
        popoverViewController.loadViewIfNeeded()
        configurePopoverViewController(
            popoverViewController,
            referenceDate: referenceDate ?? runtimeDependencies.currentDateProvider()
        )
        return popoverViewController
    }

    func configurePopoverViewController(
        _ popoverViewController: MainPopoverViewController,
        referenceDate: Date
    ) {
        self.popoverViewController = popoverViewController
        displayedReferenceDate = referenceDate
        popoverViewController.onApplyEditedTimes = { [weak self] startTime, endTime in
            self?.handleAppliedTodayTimes(startTime: startTime, endTime: endTime)
        }
        popoverViewController.onApplyEditedDetailTimes = { [weak self] surface, referenceDate, startTime, endTime in
            self?.handleAppliedDetailTimes(
                surface: surface,
                referenceDate: referenceDate,
                startTime: startTime,
                endTime: endTime
            )
        }
        popoverViewController.onOpenWeeklyProgress = { [weak self] in
            self?.showWeeklyProgress()
        }
        popoverViewController.onOpenMonthlyHistory = { [weak self] in
            self?.showMonthlyHistory()
        }
        popoverViewController.onCopyQuitReport = { [weak self] in
            self?.copyTodayQuitReport()
        }
        popoverViewController.onSelectDetailDate = { [weak self] surface, selectedDate in
            self?.selectDetailDate(surface: surface, selectedDate: selectedDate)
        }
        popoverViewController.onNavigateMonthlyHistory = { [weak self] monthOffset in
            self?.navigateMonthlyHistory(by: monthOffset)
        }
        refreshPopover(referenceDate: referenceDate)
    }

    func syncMenuBarAttendanceState() {
        let currentDate = runtimeDependencies.currentDateProvider()
        let loadedState = stateLoader.load(referenceDate: currentDate)
        onDidUpdateAttendanceState?(loadedState.viewState.attendanceState)
    }

    func handlePopoverWillOpen() {
        let referenceDate = currentReferenceDateForPopoverOpen()
        logGeometryEvent("handlePopoverWillOpen", referenceDate: referenceDate)
        popoverViewController?.showMainView()
        displayedWeeklyProgressReferenceDate = nil
        displayedMonthlyHistoryReferenceDate = nil

        if shouldResetEditingForReferenceDate(referenceDate) {
            popoverViewController?.cancelEditing()
        }

        refreshPopover(referenceDate: referenceDate)
    }

    func handlePopoverDidClose() {
        popoverViewController?.stopCurrentSessionUpdates()
    }

    func applyEditedTimes(startTime: Date?, endTime: Date?) {
        handleAppliedTodayTimes(startTime: startTime, endTime: endTime)
    }

    private func handleAppliedTodayTimes(startTime: Date?, endTime: Date?) {
        let referenceDate = currentReferenceDateForPopoverOpen()
        logGeometryEvent("handleAppliedTodayTimes", referenceDate: referenceDate)
        do {
            try recordStore.upsertRecord(
                AttendanceRecord(
                    date: referenceDate,
                    startTime: startTime,
                    endTime: endTime
                )
            )
        } catch {
            NSLog("Failed to save attendance record: %@", String(describing: error))
        }
        refreshPopover(referenceDate: referenceDate)
    }

    private func currentReferenceDateForPopoverOpen() -> Date {
        let currentDate = runtimeDependencies.currentDateProvider()
        guard let displayedReferenceDate else { return currentDate }

        guard runtimeDependencies.calendar.isDate(displayedReferenceDate, inSameDayAs: currentDate) else {
            return currentDate
        }

        return displayedReferenceDate
    }

    private func refreshPopover(referenceDate: Date) {
        guard let popoverViewController else { return }
        logGeometryEvent("refreshPopover", referenceDate: referenceDate)
        displayedReferenceDate = referenceDate
        let currentDate = runtimeDependencies.currentDateProvider()

        let loadedState = stateLoader.load(referenceDate: referenceDate)
        syncMenuBarAttendanceState()
        popoverViewController.display(
            MainPopoverDisplayIntent(
                viewState: loadedState.viewState,
                startTime: loadedState.todayRecord?.startTime,
                endTime: loadedState.todayRecord?.endTime,
                allowsLiveCurrentSessionUpdates: runtimeDependencies.calendar.isDate(
                    referenceDate,
                    inSameDayAs: currentDate
                )
            )
        )
    }

    private func copyTodayQuitReport() {
        let currentDate = runtimeDependencies.currentDateProvider()
        let todayRecord = recordStore.record(on: currentDate, calendar: runtimeDependencies.calendar)
        let throughTodayStatusText = weeklyProgressLoader.load(referenceDate: currentDate).todayDeltaStatusText
        let reportText = todayQuitReportBuilder.make(
            todayRecord: todayRecord,
            now: currentDate,
            throughTodayStatusText: throughTodayStatusText
        )
        clipboardWriter.copy(reportText)
    }

    private func showWeeklyProgress() {
        let referenceDate = currentReferenceDateForPopoverOpen()
        logGeometryEvent("showWeeklyProgress", referenceDate: referenceDate)
        displayedWeeklyProgressReferenceDate = referenceDate
        popoverViewController?.showWeeklyDetail(
            weeklyProgressLoader.load(referenceDate: referenceDate)
        )
    }

    private func showMonthlyHistory() {
        let referenceDate = currentReferenceDateForPopoverOpen()
        logGeometryEvent("showMonthlyHistory", referenceDate: referenceDate)
        let state = loadMonthlyHistory(referenceDate: referenceDate)
        displayedMonthlyHistoryReferenceDate = state.referenceDate
        popoverViewController?.showMonthlyHistory(state)
    }

    func loadMonthlyHistory(referenceDate: Date) -> MonthlyHistoryViewState {
        monthlyHistoryLoader.load(referenceDate: referenceDate)
    }

    func shiftMonthlyHistory(referenceDate: Date, by monthOffset: Int) -> MonthlyHistoryViewState? {
        guard let shiftedDate = runtimeDependencies.calendar.date(
            byAdding: .month,
            value: monthOffset,
            to: referenceDate
        ) else {
            return nil
        }

        return monthlyHistoryLoader.load(referenceDate: shiftedDate)
    }

    private func navigateMonthlyHistory(by monthOffset: Int) {
        guard
            let referenceDate = displayedMonthlyHistoryReferenceDate,
            let state = shiftMonthlyHistory(referenceDate: referenceDate, by: monthOffset)
        else {
            return
        }

        logGeometryEvent("navigateMonthlyHistory(\(monthOffset))", referenceDate: state.referenceDate)
        displayedMonthlyHistoryReferenceDate = state.referenceDate
        popoverViewController?.showMonthlyHistory(state)
    }

    private func shouldResetEditingForReferenceDate(_ referenceDate: Date) -> Bool {
        guard let displayedReferenceDate else { return false }

        return runtimeDependencies.calendar.isDate(
            displayedReferenceDate,
            inSameDayAs: referenceDate
        ) == false
    }

    private func handleAppliedDetailTimes(
        surface: MainPopoverDetailSurface,
        referenceDate: Date,
        startTime: Date?,
        endTime: Date?
    ) {
        logGeometryEvent("handleAppliedDetailTimes[\(surface)]", referenceDate: referenceDate)
        do {
            try recordStore.upsertRecord(
                AttendanceRecord(
                    date: referenceDate,
                    startTime: startTime,
                    endTime: endTime
                )
            )
        } catch {
            NSLog("Failed to save detail attendance record: %@", String(describing: error))
        }

        refreshMainRouteIfNeeded(for: referenceDate)
        selectDetailDate(surface: surface, selectedDate: referenceDate)
    }

    private func refreshMainRouteIfNeeded(for referenceDate: Date) {
        guard let displayedReferenceDate else { return }
        guard runtimeDependencies.calendar.isDate(displayedReferenceDate, inSameDayAs: referenceDate) else {
            return
        }

        refreshPopover(referenceDate: displayedReferenceDate)
    }

    private func selectDetailDate(
        surface: MainPopoverDetailSurface,
        selectedDate: Date
    ) {
        logGeometryEvent("selectDetailDate[\(surface)]", referenceDate: selectedDate)
        let editorState = makeDetailDayEditingState(referenceDate: selectedDate)

        switch surface {
        case .weekly:
            let referenceDate = displayedWeeklyProgressReferenceDate ?? currentReferenceDateForPopoverOpen()
            displayedWeeklyProgressReferenceDate = referenceDate
            popoverViewController?.showWeeklyDetail(
                weeklyProgressLoader.load(referenceDate: referenceDate),
                editorState: editorState
            )
        case .monthly:
            let referenceDate = displayedMonthlyHistoryReferenceDate ?? currentReferenceDateForPopoverOpen()
            let state = loadMonthlyHistory(referenceDate: referenceDate)
            displayedMonthlyHistoryReferenceDate = state.referenceDate
            popoverViewController?.showMonthlyHistory(
                state,
                editorState: editorState
            )
        }
    }

    private func makeDetailDayEditingState(referenceDate: Date) -> MainPopoverDetailDayEditingState {
        let loadedState = stateLoader.load(referenceDate: referenceDate)
        let fallbackStartTime = fallbackTime(on: referenceDate, hour: 9, minute: 0)
        let fallbackEndTime = loadedState.todayRecord?.startTime
            ?? fallbackTime(on: referenceDate, hour: 18, minute: 0)

        return MainPopoverDetailDayEditingState(
            referenceDate: referenceDate,
            dateText: loadedState.viewState.dateText,
            startTimeText: loadedState.viewState.startTimeText,
            endTimeText: loadedState.viewState.endTimeText,
            startTime: loadedState.todayRecord?.startTime,
            endTime: loadedState.todayRecord?.endTime,
            fallbackStartTime: loadedState.todayRecord?.startTime ?? fallbackStartTime,
            fallbackEndTime: loadedState.todayRecord?.endTime ?? fallbackEndTime
        )
    }

    private func fallbackTime(
        on referenceDate: Date,
        hour: Int,
        minute: Int
    ) -> Date {
        let dayStart = runtimeDependencies.calendar.startOfDay(for: referenceDate)
        return runtimeDependencies.calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: dayStart
        ) ?? dayStart
    }

    private func logGeometryEvent(_ event: String, referenceDate: Date) {
        guard Self.isGeometryDebugEnabled else { return }
        print(
            "[PopoverFlow] event=\(event) referenceDate=\(referenceDate) displayedMain=\(String(describing: displayedReferenceDate)) displayedWeekly=\(String(describing: displayedWeeklyProgressReferenceDate)) displayedMonthly=\(String(describing: displayedMonthlyHistoryReferenceDate))"
        )
    }
}
