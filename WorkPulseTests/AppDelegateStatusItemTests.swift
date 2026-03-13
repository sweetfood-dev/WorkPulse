import AppKit
import Testing
@testable import WorkPulse

@Suite(.serialized)
struct AppDelegateStatusItemTests {
    @MainActor
    @Test("applicationDidFinishLaunching creates a menu bar status item")
    func createsStatusItemOnLaunch() {
        let sut = AppDelegate()

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        #expect(sut.statusItem != nil)
        #expect(sut.statusItem?.statusBar === NSStatusBar.system)
    }

    @MainActor
    @Test("applicationDidFinishLaunching makes the status item identifiable")
    func makesStatusItemIdentifiableOnLaunch() {
        let sut = AppDelegate()

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let button = sut.statusItem?.button

        #expect(button != nil)
        #expect(
            button?.image != nil ||
            !(button?.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        )
    }

    @MainActor
    @Test("clicking the status item creates the main window when missing and reuses it when present")
    func clickingStatusItemCreatesAndShowsMainWindow() throws {
        let sut = AppDelegate()

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let button = try #require(sut.statusItem?.button)
        #expect(sut.window == nil)

        button.performClick(nil)

        let createdWindow = try #require(sut.window)
        #expect(createdWindow.isVisible)

        createdWindow.orderOut(nil)
        #expect(!createdWindow.isVisible)

        button.performClick(nil)

        let reusedWindow = try #require(sut.window)
        #expect(createdWindow === reusedWindow)
        #expect(reusedWindow.isVisible)
    }

    @MainActor
    @Test("clicking the status item activates the app")
    func clickingStatusItemActivatesTheApp() throws {
        let sut = AppDelegate()
        var receivedIgnoreOtherAppsValues: [Bool] = []
        sut.applicationActivator = { receivedIgnoreOtherAppsValues.append($0) }

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            sut.window?.close()

            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let button = try #require(sut.statusItem?.button)

        button.performClick(nil)

        #expect(receivedIgnoreOtherAppsValues == [true])
    }

    @MainActor
    @Test("closing the last window keeps the app alive and preserves the status item")
    func closingLastWindowKeepsAppAlive() throws {
        let sut = AppDelegate()

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            sut.window?.close()

            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let statusItem = try #require(sut.statusItem)
        let button = try #require(statusItem.button)

        button.performClick(nil)

        let window = try #require(sut.window)
        window.close()

        #expect(!sut.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
        #expect(sut.statusItem === statusItem)
    }

    @MainActor
    @Test("closing the main window clears the stored window reference")
    func closingMainWindowClearsStoredReference() throws {
        let sut = AppDelegate()

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let button = try #require(sut.statusItem?.button)
        button.performClick(nil)

        let window = try #require(sut.window)
        sut.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))

        #expect(sut.window == nil)
    }

    @MainActor
    @Test("repeated launch or reactivation configuration reuses the same status item")
    func repeatedConfigurationReusesSameStatusItem() throws {
        let sut = AppDelegate()

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        let initialStatusItem = try #require(sut.statusItem)

        defer {
            NSStatusBar.system.removeStatusItem(initialStatusItem)

            if let statusItem = sut.statusItem, statusItem !== initialStatusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        let reusedStatusItem = try #require(sut.statusItem)

        #expect(reusedStatusItem === initialStatusItem)
    }

    @MainActor
    @Test("clicking the status item opens the attendance time input popover")
    func clickingStatusItemOpensAttendanceTimeInputPopover() throws {
        let sut = AppDelegate()
        sut.attendanceTimeStore = TestAttendanceTimeStore()
        var presentedPopover: NSPopover?
        var presentedButton: NSStatusBarButton?
        sut.popoverPresenter = { popover, button in
            presentedPopover = popover
            presentedButton = button
        }

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            sut.attendancePopover?.close()
            sut.window?.close()

            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let button = try #require(sut.statusItem?.button)

        button.performClick(nil)

        let popover = try #require(sut.attendancePopover)
        #expect(popover === presentedPopover)
        #expect(popover.contentViewController is AttendanceTimePopoverViewController)
        #expect(presentedButton === button)
    }

    @MainActor
    @Test("popover shows default time input state when no saved attendance times exist")
    func popoverShowsDefaultInputStateWithoutSavedAttendanceTimes() throws {
        let sut = AppDelegate()
        sut.attendanceTimeStore = TestAttendanceTimeStore()

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            sut.attendancePopover?.close()
            sut.window?.close()

            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let button = try #require(sut.statusItem?.button)

        button.performClick(nil)

        let popover = try #require(sut.attendancePopover)
        let controller = try #require(popover.contentViewController as? AttendanceTimePopoverViewController)
        controller.loadViewIfNeeded()

        #expect(controller.startTimePicker.dateValue == controller.defaultStartTime)
        #expect(controller.endTimePicker.dateValue == controller.defaultEndTime)
    }

    @MainActor
    @Test("saving start time in the popover writes to local store")
    func savingStartTimeInPopoverWritesToLocalStore() throws {
        let sut = AppDelegate()
        let store = TestAttendanceTimeStore()
        sut.attendanceTimeStore = store

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            sut.attendancePopover?.close()
            sut.window?.close()

            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let button = try #require(sut.statusItem?.button)
        button.performClick(nil)

        let popover = try #require(sut.attendancePopover)
        let controller = try #require(popover.contentViewController as? AttendanceTimePopoverViewController)
        controller.loadViewIfNeeded()

        let startTimeToSave = Date(timeIntervalSince1970: 1_234_567_890)
        controller.startTimePicker.dateValue = startTimeToSave
        controller.saveButton.performClick(nil)

        #expect(store.startTime == startTimeToSave)
    }

    @MainActor
    @Test("saving end time in the popover writes to local store")
    func savingEndTimeInPopoverWritesToLocalStore() throws {
        let sut = AppDelegate()
        let store = TestAttendanceTimeStore()
        sut.attendanceTimeStore = store

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            sut.attendancePopover?.close()
            sut.window?.close()

            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let button = try #require(sut.statusItem?.button)
        button.performClick(nil)

        let popover = try #require(sut.attendancePopover)
        let controller = try #require(popover.contentViewController as? AttendanceTimePopoverViewController)
        controller.loadViewIfNeeded()

        let endTimeToSave = Date(timeIntervalSince1970: 1_234_567_999)
        controller.endTimePicker.dateValue = endTimeToSave
        controller.saveButton.performClick(nil)

        #expect(store.endTime == endTimeToSave)
    }

    @MainActor
    @Test("reopening popover restores last saved start and end times")
    func reopeningPopoverRestoresLastSavedStartAndEndTimes() throws {
        let store = TestAttendanceTimeStore()
        let startTimeToSave = Date(timeIntervalSince1970: 1_700_000_000)
        let endTimeToSave = Date(timeIntervalSince1970: 1_700_003_600)

        let firstApp = AppDelegate()
        firstApp.attendanceTimeStore = store
        firstApp.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            firstApp.attendancePopover?.close()
            firstApp.window?.close()

            if let statusItem = firstApp.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let firstButton = try #require(firstApp.statusItem?.button)
        firstButton.performClick(nil)

        let firstPopover = try #require(firstApp.attendancePopover)
        let firstController = try #require(
            firstPopover.contentViewController as? AttendanceTimePopoverViewController
        )
        firstController.loadViewIfNeeded()
        firstController.startTimePicker.dateValue = startTimeToSave
        firstController.endTimePicker.dateValue = endTimeToSave
        firstController.saveButton.performClick(nil)
        firstPopover.close()

        let secondApp = AppDelegate()
        secondApp.attendanceTimeStore = store
        secondApp.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            secondApp.attendancePopover?.close()
            secondApp.window?.close()

            if let statusItem = secondApp.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let secondButton = try #require(secondApp.statusItem?.button)
        secondButton.performClick(nil)

        let secondPopover = try #require(secondApp.attendancePopover)
        let secondController = try #require(
            secondPopover.contentViewController as? AttendanceTimePopoverViewController
        )
        secondController.loadViewIfNeeded()

        #expect(secondController.startTimePicker.dateValue == startTimeToSave)
        #expect(secondController.endTimePicker.dateValue == endTimeToSave)
    }

    @MainActor
    @Test("closing popover without saving does not replace persisted times")
    func closingPopoverWithoutSavingDoesNotReplacePersistedTimes() throws {
        let sut = AppDelegate()
        let store = TestAttendanceTimeStore()
        let persistedStart = Date(timeIntervalSince1970: 1_700_100_000)
        let persistedEnd = Date(timeIntervalSince1970: 1_700_103_600)
        store.startTime = persistedStart
        store.endTime = persistedEnd
        sut.attendanceTimeStore = store

        sut.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defer {
            sut.attendancePopover?.close()
            sut.window?.close()

            if let statusItem = sut.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let button = try #require(sut.statusItem?.button)
        button.performClick(nil)

        let firstPopover = try #require(sut.attendancePopover)
        let firstController = try #require(
            firstPopover.contentViewController as? AttendanceTimePopoverViewController
        )
        firstController.loadViewIfNeeded()
        firstController.startTimePicker.dateValue = Date(timeIntervalSince1970: 1_800_000_000)
        firstController.endTimePicker.dateValue = Date(timeIntervalSince1970: 1_800_003_600)

        firstPopover.close()

        button.performClick(nil)

        let secondPopover = try #require(sut.attendancePopover)
        let secondController = try #require(
            secondPopover.contentViewController as? AttendanceTimePopoverViewController
        )
        secondController.loadViewIfNeeded()

        #expect(store.startTime == persistedStart)
        #expect(store.endTime == persistedEnd)
        #expect(secondController.startTimePicker.dateValue == persistedStart)
        #expect(secondController.endTimePicker.dateValue == persistedEnd)
    }
}

private final class TestAttendanceTimeStore: AttendanceTimeStore {
    var startTime: Date?
    var endTime: Date?
}
