import AppKit

@MainActor
protocol MenuBarPopoverControlling: AnyObject {
    var contentViewController: NSViewController? { get set }
    var behavior: NSPopover.Behavior { get set }
    var animates: Bool { get set }
    var isShown: Bool { get }

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge)
    func performClose(_ sender: Any?)
}

extension NSPopover: MenuBarPopoverControlling {}

@MainActor
final class MenuBarShellController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: any MenuBarPopoverControlling
    var onWillOpenPopover: (() -> Void)?
    var onDidClosePopover: (() -> Void)?

    convenience init(popoverViewController: NSViewController) {
        self.init(
            statusItem: NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength),
            popover: NSPopover(),
            popoverViewController: popoverViewController
        )
    }

    init(
        statusItem: NSStatusItem,
        popover: any MenuBarPopoverControlling,
        popoverViewController: NSViewController
    ) {
        self.statusItem = statusItem
        self.popover = popover
        super.init()

        configurePopover(with: popoverViewController)
        configureStatusItem()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configurePopover(with viewController: NSViewController) {
        popover.contentViewController = viewController
        popover.behavior = .transient
        popover.animates = true
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.title = "WP"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
            onDidClosePopover?()
            return
        }

        onWillOpenPopover?()
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
    }
}
