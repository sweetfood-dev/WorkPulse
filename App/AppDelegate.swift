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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarShellController: MenuBarShellController?
    private var monthlyHistoryWindowController: MonthlyHistoryWindowController?
    private var displayedMonthlyHistoryReferenceDate: Date?
    private let popoverCoordinator: MainPopoverCoordinator

    init(
        runtimeDependencies: MainPopoverRuntimeDependencies = .live,
        recordStore: (any AttendanceRecordStore)? = nil
    ) {
        let resolvedRecordStore = recordStore ?? {
            let legacyStore = UserDefaultsAttendanceRecordStore(
                calendar: runtimeDependencies.calendar
            )

            do {
                let swiftDataStore = try SwiftDataAttendanceRecordStore(
                    calendar: runtimeDependencies.calendar,
                    legacyRecords: legacyStore.loadRecords()
                )
                return MirroredAttendanceRecordStore(
                    primary: swiftDataStore,
                    fallback: legacyStore
                )
            } catch {
                assertionFailure("Failed to create SwiftData attendance store: \(error)")
                return legacyStore
            }
        }()
        self.popoverCoordinator = MainPopoverCoordinator(
            runtimeDependencies: runtimeDependencies,
            recordStore: resolvedRecordStore
        )
        super.init()
        self.popoverCoordinator.onOpenMonthlyHistory = { [weak self] state in
            self?.presentMonthlyHistory(state)
        }
        self.popoverCoordinator.onRefreshMonthlyHistory = { [weak self] _ in
            self?.refreshMonthlyHistoryWindow()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let popoverViewController = popoverCoordinator.makePopoverViewController()
        let menuBarShellController = MenuBarShellController(
            popoverViewController: popoverViewController
        )
        menuBarShellController.onWillOpenPopover = { [weak self] in
            self?.handlePopoverWillOpen()
        }
        menuBarShellController.onDidClosePopover = { [weak self] in
            self?.popoverCoordinator.handlePopoverDidClose()
        }
        self.menuBarShellController = menuBarShellController
    }

    func configurePopoverViewController(
        _ popoverViewController: MainPopoverViewController,
        referenceDate: Date
    ) {
        popoverCoordinator.configurePopoverViewController(
            popoverViewController,
            referenceDate: referenceDate
        )
    }

    func handlePopoverWillOpen() {
        popoverCoordinator.handlePopoverWillOpen()
    }

    private func presentMonthlyHistory(_ state: MonthlyHistoryViewState) {
        let windowController = monthlyHistoryWindowController ?? {
            let controller = MonthlyHistoryWindowController()
            controller.onNavigatePreviousMonth = { [weak self] in
                self?.navigateMonthlyHistory(by: -1)
            }
            controller.onNavigateNextMonth = { [weak self] in
                self?.navigateMonthlyHistory(by: 1)
            }
            controller.onWillCloseWindow = { [weak self] in
                self?.monthlyHistoryWindowController = nil
                self?.displayedMonthlyHistoryReferenceDate = nil
            }
            monthlyHistoryWindowController = controller
            return controller
        }()

        displayedMonthlyHistoryReferenceDate = state.referenceDate
        windowController.show(state: state)
    }

    private func refreshMonthlyHistoryWindow() {
        guard
            monthlyHistoryWindowController != nil,
            let referenceDate = displayedMonthlyHistoryReferenceDate
        else {
            return
        }

        monthlyHistoryWindowController?.apply(
            popoverCoordinator.loadMonthlyHistory(referenceDate: referenceDate)
        )
    }

    private func navigateMonthlyHistory(by monthOffset: Int) {
        guard
            let referenceDate = displayedMonthlyHistoryReferenceDate,
            let state = popoverCoordinator.shiftMonthlyHistory(
                referenceDate: referenceDate,
                by: monthOffset
            )
        else {
            return
        }

        displayedMonthlyHistoryReferenceDate = state.referenceDate
        monthlyHistoryWindowController?.apply(state)
    }
}
