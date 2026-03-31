import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarShellController: MenuBarShellController?
    private let recordStore = UserDefaultsAttendanceRecordStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let referenceDate = Date()
        let loadedState = MainPopoverStateLoader(
            recordStore: recordStore
        ).load(referenceDate: referenceDate)
        let popoverViewController = MainPopoverViewController(
            state: loadedState.viewState
        )
        popoverViewController.loadViewIfNeeded()
        popoverViewController.beginCurrentSessionUpdates(
            startTime: loadedState.todayRecord?.startTime,
            endTime: loadedState.todayRecord?.endTime
        )

        menuBarShellController = MenuBarShellController(
            popoverViewController: popoverViewController
        )
    }
}
