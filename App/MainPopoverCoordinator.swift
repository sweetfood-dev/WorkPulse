import AppKit

@MainActor
final class MainPopoverCoordinator {
    private weak var popoverViewController: MainPopoverViewController?
    private var displayedReferenceDate: Date?
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
            currentDateProvider: runtimeDependencies.currentDateProvider
        )
        self.monthlyHistoryLoader = MonthlyHistoryLoader(
            recordStore: recordStore,
            calendar: runtimeDependencies.calendar,
            locale: runtimeDependencies.locale,
            timeZone: runtimeDependencies.timeZone,
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
        popoverViewController.onOpenWeeklyProgress = { [weak self] in
            self?.showWeeklyProgress()
        }
        popoverViewController.onOpenMonthlyHistory = { [weak self] in
            self?.showMonthlyHistory()
        }
        popoverViewController.onNavigateMonthlyHistory = { [weak self] monthOffset in
            self?.navigateMonthlyHistory(by: monthOffset)
        }
        refreshPopover(referenceDate: referenceDate)
    }

    func handlePopoverWillOpen() {
        let referenceDate = resolvedReferenceDate()
        popoverViewController?.showMainView()
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
        let referenceDate = resolvedReferenceDate()
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

    private func resolvedReferenceDate(from candidateReferenceDate: Date? = nil) -> Date {
        let currentDate = runtimeDependencies.currentDateProvider()
        guard let candidateReferenceDate = candidateReferenceDate ?? displayedReferenceDate else {
            return currentDate
        }

        guard runtimeDependencies.calendar.isDate(candidateReferenceDate, inSameDayAs: currentDate) else {
            return currentDate
        }

        return candidateReferenceDate
    }

    private func refreshPopover(referenceDate: Date) {
        guard let popoverViewController else { return }
        displayedReferenceDate = referenceDate

        let loadedState = stateLoader.load(referenceDate: referenceDate)
        popoverViewController.display(
            MainPopoverDisplayIntent(
                viewState: loadedState.viewState,
                startTime: loadedState.todayRecord?.startTime,
                endTime: loadedState.todayRecord?.endTime
            )
        )
    }

    private func showWeeklyProgress() {
        let referenceDate = resolvedReferenceDate()
        popoverViewController?.showWeeklyDetail(
            weeklyProgressLoader.load(referenceDate: referenceDate)
        )
    }

    private func showMonthlyHistory() {
        let referenceDate = resolvedReferenceDate()
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
}
