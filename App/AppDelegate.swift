import AppKit

struct MainPopoverRuntimeDependencies {
    let calendar: Calendar
    let locale: Locale
    let timeZone: TimeZone
    let calendarDayMetadataProvider: any CalendarDayMetadataProviding
    let currentDateProvider: () -> Date
    let currentSessionScheduler: any CurrentSessionScheduling

    static var live: MainPopoverRuntimeDependencies {
        let timeZone = TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        return MainPopoverRuntimeDependencies(
            calendar: calendar,
            locale: .current,
            timeZone: timeZone,
            calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(timeZone: timeZone),
            currentDateProvider: Date.init,
            currentSessionScheduler: TimerCurrentSessionScheduler()
        )
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarShellController: MenuBarShellController?
    private var calendarDayChangedObserver: NSObjectProtocol?
    private let popoverCoordinator: MainPopoverCoordinator
    private let notificationCenter: NotificationCenter
    var onDidSyncMenuBarAttendanceStateForTesting: (() -> Void)?

    init(
        runtimeDependencies: MainPopoverRuntimeDependencies = .live,
        recordStore: (any AttendanceRecordStore)? = nil,
        notificationCenter: NotificationCenter = .default
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
        self.notificationCenter = notificationCenter
        super.init()
    }

    deinit {
        if let calendarDayChangedObserver {
            notificationCenter.removeObserver(calendarDayChangedObserver)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let popoverViewController = popoverCoordinator.makePopoverViewController()
        let menuBarShellController = MenuBarShellController(
            popoverViewController: popoverViewController
        )
        popoverCoordinator.onDidUpdateAttendanceState = { [weak menuBarShellController] attendanceState in
            menuBarShellController?.updateStatusItem(attendanceState: attendanceState)
        }
        menuBarShellController.onWillOpenPopover = { [weak self] in
            self?.handlePopoverWillOpen()
        }
        menuBarShellController.onDidClosePopover = { [weak self] in
            self?.popoverCoordinator.handlePopoverDidClose()
        }
        self.menuBarShellController = menuBarShellController
        observeCalendarDayChanges()
        syncMenuBarAttendanceState()
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

    private func observeCalendarDayChanges() {
        guard calendarDayChangedObserver == nil else { return }
        calendarDayChangedObserver = notificationCenter.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncMenuBarAttendanceState()
            }
        }
    }

    private func syncMenuBarAttendanceState() {
        popoverCoordinator.syncMenuBarAttendanceState()
        onDidSyncMenuBarAttendanceStateForTesting?()
    }
}
