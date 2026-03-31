import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarShellController: MenuBarShellController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarShellController = MenuBarShellController(
            popoverViewController: MainPopoverViewController()
        )
    }
}
