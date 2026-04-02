import AppKit

@MainActor
final class MonthlyHistoryWindowController: NSWindowController, NSWindowDelegate {
    var onWillCloseWindow: (() -> Void)?

    private let monthlyHistoryViewController = MonthlyHistoryViewController()

    init() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: MainPopoverStyle.Metrics.monthlyHistoryWindowSize.width,
                height: MainPopoverStyle.Metrics.monthlyHistoryWindowSize.height
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = MainPopoverCopy.english.monthlyHistoryTitle
        window.contentViewController = monthlyHistoryViewController
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(state: MonthlyHistoryViewState) {
        monthlyHistoryViewController.apply(state)
        window?.title = state.titleText
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func apply(_ state: MonthlyHistoryViewState) {
        monthlyHistoryViewController.apply(state)
        window?.title = state.titleText
    }

    func windowWillClose(_ notification: Notification) {
        onWillCloseWindow?()
    }
}
