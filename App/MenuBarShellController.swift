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

        statusItem.length = NSStatusItem.squareLength
        button.title = ""
        button.imagePosition = .imageOnly
        applyStatusAppearance(.notCheckedIn, to: button)
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    func updateStatusItem(attendanceState: MainPopoverAttendanceState) {
        guard let button = statusItem.button else { return }
        applyStatusAppearance(attendanceState, to: button)
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

    private func applyStatusAppearance(_ attendanceState: MainPopoverAttendanceState, to button: NSStatusBarButton) {
        button.image = statusImage(for: attendanceState)
        button.contentTintColor = nil
        button.toolTip = statusTitle(for: attendanceState)
    }

    private func statusImage(for attendanceState: MainPopoverAttendanceState) -> NSImage? {
        let image = NSImage(
            systemSymbolName: "laptopcomputer.and.ipad",
            accessibilityDescription: statusTitle(for: attendanceState)
        )
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            .applying(
                NSImage.SymbolConfiguration(hierarchicalColor: statusTintColor(for: attendanceState))
            )
        let configuredImage = image?.withSymbolConfiguration(symbolConfiguration)
        configuredImage?.isTemplate = false
        return configuredImage
    }

    private func statusTintColor(for attendanceState: MainPopoverAttendanceState) -> NSColor {
        switch attendanceState {
        case .notCheckedIn:
            return .systemGray
        case .checkedIn:
            return .systemBlue
        case .checkedOut:
            return .systemGreen
        }
    }

    private func statusTitle(for attendanceState: MainPopoverAttendanceState) -> String {
        switch attendanceState {
        case .notCheckedIn:
            return "출근 전"
        case .checkedIn:
            return "업무 중"
        case .checkedOut:
            return "퇴근"
        }
    }
}
