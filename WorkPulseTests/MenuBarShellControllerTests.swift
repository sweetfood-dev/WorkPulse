import AppKit
import Testing
@testable import WorkPulse

@Suite("MenuBarShellController")
struct MenuBarShellControllerTests {
    @Test
    @MainActor
    func configuresStatusItemButtonAndPopoverDefaults() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let popover = FakePopoverController()
        let contentViewController = NSViewController()
        withExtendedLifetime(
            MenuBarShellController(
                statusItem: statusItem,
                popover: popover,
                popoverViewController: contentViewController
            )
        ) {
            let button = try! #require(statusItem.button)
            #expect(button.title == "WP")
            #expect(popover.contentViewController === contentViewController)
            #expect(popover.behavior == .transient)
            #expect(popover.animates)
        }
    }

    @Test
    @MainActor
    func clickingStatusItemTogglesPopoverOpenAndClosed() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let popover = FakePopoverController()
        withExtendedLifetime(
            MenuBarShellController(
                statusItem: statusItem,
                popover: popover,
                popoverViewController: NSViewController()
            )
        ) {
            let button = try! #require(statusItem.button)

            button.performClick(nil)

            #expect(popover.showCallCount == 1)
            #expect(popover.isShown)
            #expect(popover.lastShownView === button)
            #expect(popover.lastShownRect == button.bounds)
            #expect(popover.lastPreferredEdge == .minY)

            button.performClick(nil)

            #expect(popover.closeCallCount == 1)
            #expect(!popover.isShown)
        }
    }

    @Test
    @MainActor
    func openingPopoverInvokesWillOpenCallbackOnlyOnOpen() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let popover = FakePopoverController()
        var willOpenCallCount = 0
        var controller: MenuBarShellController? = MenuBarShellController(
            statusItem: statusItem,
            popover: popover,
            popoverViewController: NSViewController()
        )
        controller?.onWillOpenPopover = {
            willOpenCallCount += 1
        }

        defer { controller = nil }

        let button = try #require(statusItem.button)

        button.performClick(nil)
        button.performClick(nil)

        #expect(willOpenCallCount == 1)
    }

    @Test
    @MainActor
    func closingPopoverInvokesDidCloseCallbackOnlyOnClose() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let popover = FakePopoverController()
        var didCloseCallCount = 0
        var controller: MenuBarShellController? = MenuBarShellController(
            statusItem: statusItem,
            popover: popover,
            popoverViewController: NSViewController()
        )
        controller?.onDidClosePopover = {
            didCloseCallCount += 1
        }

        defer { controller = nil }

        let button = try #require(statusItem.button)

        button.performClick(nil)
        button.performClick(nil)

        #expect(didCloseCallCount == 1)
    }
}

@MainActor
private final class FakePopoverController: MenuBarPopoverControlling {
    var contentViewController: NSViewController?
    var behavior: NSPopover.Behavior = .applicationDefined
    var animates = false
    var isShown = false

    private(set) var showCallCount = 0
    private(set) var closeCallCount = 0
    private(set) var lastShownRect: NSRect = .zero
    private(set) weak var lastShownView: NSView?
    private(set) var lastPreferredEdge: NSRectEdge?

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        showCallCount += 1
        isShown = true
        lastShownRect = positioningRect
        lastShownView = positioningView
        lastPreferredEdge = preferredEdge
    }

    func performClose(_ sender: Any?) {
        closeCallCount += 1
        isShown = false
    }
}
