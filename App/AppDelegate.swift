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
}
