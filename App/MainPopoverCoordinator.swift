import AppKit

@MainActor
final class MainPopoverCoordinator {
    private weak var popoverViewController: MainPopoverViewController?
    private var displayedReferenceDate: Date?
    private var displayedWeeklyProgressReferenceDate: Date?
    private var displayedMonthlyHistoryReferenceDate: Date?
    private let runtimeDependencies: MainPopoverRuntimeDependencies
    private let recordStore: any AttendanceRecordStore
    private let viewStateFactory: MainPopoverViewStateFactory
    private let stateLoader: MainPopoverStateLoader
    private let workedDurationCalculator: WorkedDurationCalculator
    private let weeklyProgressLoader: MainPopoverWeeklyProgressLoader
    private let monthlyHistoryLoader: MonthlyHistoryLoader

    init(
        runtimeDependencies: MainPopoverRuntimeDependencies,
        recordStore: any AttendanceRecordStore
    ) {
        self.runtimeDependencies = runtimeDependencies
        self.recordStore = recordStore
        self.workedDurationCalculator = WorkedDurationCalculator(
            calendar: runtimeDependencies.calendar
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
        popoverViewController.onSelectDetailDate = { [weak self] surface, selectedDate in
            self?.selectDetailDate(surface: surface, selectedDate: selectedDate)
        }
        popoverViewController.onNavigateMonthlyHistory = { [weak self] monthOffset in
            self?.navigateMonthlyHistory(by: monthOffset)
        }
        refreshPopover(referenceDate: referenceDate)
    }

    func handlePopoverWillOpen() {
        let referenceDate = currentReferenceDateForPopoverOpen()
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
        displayedReferenceDate = referenceDate
        let currentDate = runtimeDependencies.currentDateProvider()

        let loadedState = stateLoader.load(referenceDate: referenceDate)
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

    private func showWeeklyProgress() {
        let referenceDate = currentReferenceDateForPopoverOpen()
        displayedWeeklyProgressReferenceDate = referenceDate
        popoverViewController?.showWeeklyDetail(
            weeklyProgressLoader.load(referenceDate: referenceDate)
        )
    }

    private func showMonthlyHistory() {
        let referenceDate = currentReferenceDateForPopoverOpen()
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

        selectDetailDate(surface: surface, selectedDate: referenceDate)
    }

    private func selectDetailDate(
        surface: MainPopoverDetailSurface,
        selectedDate: Date
    ) {
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
}
