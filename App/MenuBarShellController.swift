import AppKit

@MainActor
protocol MenuBarPopoverControlling: AnyObject {
    var contentViewController: NSViewController? { get set }
    var contentSize: NSSize { get set }
    var behavior: NSPopover.Behavior { get set }
    var animates: Bool { get set }
    var isShown: Bool { get }

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge)
    func performClose(_ sender: Any?)
}

extension NSPopover: MenuBarPopoverControlling {}

@MainActor
final class MenuBarShellController: NSObject {
    private static let isGeometryDebugEnabled =
        ProcessInfo.processInfo.environment["WORKPULSE_DEBUG_POPOVER_GEOMETRY"] == "1"

    private let statusItem: NSStatusItem
    private let popover: any MenuBarPopoverControlling
    private var preferredContentSizeObservation: NSKeyValueObservation?
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
        applyContentSize(viewController.preferredContentSize)
        popover.behavior = .transient
        popover.animates = true
        preferredContentSizeObservation = viewController.observe(\.preferredContentSize, options: [.initial, .new]) { [weak self] _, change in
            guard let self, let size = change.newValue else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self.applyContentSize(size)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.applyContentSize(size)
                }
            }
        }
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
            if Self.isGeometryDebugEnabled {
                print("[PopoverShell] togglePopover close contentSize=\(popover.contentSize)")
            }
            popover.performClose(sender)
            onDidClosePopover?()
            return
        }

        onWillOpenPopover?()
        if let viewController = popover.contentViewController {
            applyContentSize(viewController.preferredContentSize)
        }
        if Self.isGeometryDebugEnabled {
            print("[PopoverShell] togglePopover show contentSize=\(popover.contentSize)")
        }
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
    }

    private func applyContentSize(_ size: NSSize) {
        popover.contentSize = size
        guard let contentView = popover.contentViewController?.view else { return }
        if contentView.window == nil {
            var frame = contentView.frame
            frame.size = size
            contentView.frame = frame
        }
        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()
        guard Self.isGeometryDebugEnabled else { return }
        print(
            "[PopoverShell] applyContentSize size=\(size) contentFrame=\(NSStringFromRect(contentView.frame)) contentBounds=\(NSStringFromRect(contentView.bounds)) shown=\(popover.isShown)"
        )
    }
}
