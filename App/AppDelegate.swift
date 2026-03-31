import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarShellController: MenuBarShellController?
    private var popoverViewController: MainPopoverViewController?
    private let recordStore: any AttendanceRecordStore
    private let currentDateProvider: () -> Date

    init(
        recordStore: any AttendanceRecordStore = UserDefaultsAttendanceRecordStore(),
        currentDateProvider: @escaping () -> Date = Date.init
    ) {
        self.recordStore = recordStore
        self.currentDateProvider = currentDateProvider
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let popoverViewController = MainPopoverViewController()
        popoverViewController.loadViewIfNeeded()
        configurePopoverViewController(
            popoverViewController,
            referenceDate: currentDateProvider()
        )

        menuBarShellController = MenuBarShellController(
            popoverViewController: popoverViewController
        )
    }

    func configurePopoverViewController(
        _ popoverViewController: MainPopoverViewController,
        referenceDate: Date
    ) {
        self.popoverViewController = popoverViewController
        popoverViewController.onApplyEditedTimes = { [weak self] startTime, endTime in
            self?.handleAppliedTodayTimes(startTime: startTime, endTime: endTime)
        }
        refreshPopover(referenceDate: referenceDate)
    }

    private func handleAppliedTodayTimes(startTime: Date?, endTime: Date?) {
        let referenceDate = currentDateProvider()
        recordStore.upsertRecord(
            AttendanceRecord(
                date: referenceDate,
                startTime: startTime,
                endTime: endTime
            )
        )
        refreshPopover(referenceDate: referenceDate)
    }

    private func refreshPopover(referenceDate: Date) {
        guard let popoverViewController else { return }

        let loadedState = MainPopoverStateLoader(
            recordStore: recordStore
        ).load(referenceDate: referenceDate)
        popoverViewController.apply(state: loadedState.viewState)
        popoverViewController.beginCurrentSessionUpdates(
            startTime: loadedState.todayRecord?.startTime,
            endTime: loadedState.todayRecord?.endTime
        )
    }
}
