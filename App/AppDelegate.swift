import AppKit

struct MainPopoverRuntimeDependencies {
    let calendar: Calendar
    let locale: Locale
    let timeZone: TimeZone
    let currentDateProvider: () -> Date
    let currentSessionScheduler: any CurrentSessionScheduling

    static var live: MainPopoverRuntimeDependencies {
        MainPopoverRuntimeDependencies(
            calendar: .current,
            locale: .current,
            timeZone: .current,
            currentDateProvider: Date.init,
            currentSessionScheduler: TimerCurrentSessionScheduler()
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarShellController: MenuBarShellController?
    private var popoverViewController: MainPopoverViewController?
    private var displayedReferenceDate: Date?
    private let recordStore: any AttendanceRecordStore
    private let runtimeDependencies: MainPopoverRuntimeDependencies

    init(
        runtimeDependencies: MainPopoverRuntimeDependencies = .live,
        recordStore: (any AttendanceRecordStore)? = nil
    ) {
        self.runtimeDependencies = runtimeDependencies
        self.recordStore = recordStore ?? UserDefaultsAttendanceRecordStore(
            calendar: runtimeDependencies.calendar
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let popoverViewController = MainPopoverViewController(
            currentTimeProvider: runtimeDependencies.currentDateProvider,
            currentSessionScheduler: runtimeDependencies.currentSessionScheduler
        )
        popoverViewController.loadViewIfNeeded()
        configurePopoverViewController(
            popoverViewController,
            referenceDate: runtimeDependencies.currentDateProvider()
        )

        let menuBarShellController = MenuBarShellController(
            popoverViewController: popoverViewController
        )
        menuBarShellController.onWillOpenPopover = { [weak self] in
            guard let self else { return }
            self.refreshPopover(referenceDate: self.resolvedReferenceDate())
        }
        self.menuBarShellController = menuBarShellController
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
        refreshPopover(referenceDate: referenceDate)
    }

    private func handleAppliedTodayTimes(startTime: Date?, endTime: Date?) {
        let referenceDate = resolvedReferenceDate()
        recordStore.upsertRecord(
            AttendanceRecord(
                date: referenceDate,
                startTime: startTime,
                endTime: endTime
            )
        )
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

        let loadedState = MainPopoverStateLoader(
            recordStore: recordStore,
            viewStateFactory: MainPopoverViewStateFactory(
                calendar: runtimeDependencies.calendar,
                locale: runtimeDependencies.locale,
                timeZone: runtimeDependencies.timeZone
            ),
            calendar: runtimeDependencies.calendar
        ).load(referenceDate: referenceDate)
        popoverViewController.apply(state: loadedState.viewState)
        popoverViewController.beginCurrentSessionUpdates(
            startTime: loadedState.todayRecord?.startTime,
            endTime: loadedState.todayRecord?.endTime
        )
    }
}
