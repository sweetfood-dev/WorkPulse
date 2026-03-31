import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarShellController: MenuBarShellController?
    private let viewStateFactory = MainPopoverViewStateFactory()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let popoverViewController = MainPopoverViewController(
            state: viewStateFactory.make(
                referenceDate: Date(),
                todayRecord: nil
            )
        )

        menuBarShellController = MenuBarShellController(
            popoverViewController: popoverViewController
        )
    }
}
