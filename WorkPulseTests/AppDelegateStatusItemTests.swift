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
    @Test("when start and end times are both missing, worked time shows a placeholder")
    func workedTimeShowsPlaceholderWhenStartAndEndTimesAreMissing() throws {
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
        #expect(button.title == "--:--")

        button.performClick(nil)

        let popover = try #require(sut.attendancePopover)
        let controller = try #require(popover.contentViewController as? AttendanceTimePopoverViewController)
        controller.loadViewIfNeeded()

        #expect(controller.workedTimeLabel.stringValue == "현재 근무: --:--")
        #expect(!controller.workedTimeLabel.isHidden)
    }

    @MainActor
    @Test("when only start time exists, worked time shows elapsed time from the current time")
    func workedTimeShowsElapsedTimeWhenOnlyStartTimeExists() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 30))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = startTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar,
            currentDateProvider: { referenceDate }
        )

        sut.loadViewIfNeeded()

        #expect(sut.workedTimeLabel.stringValue == "현재 근무: 02:30")
        #expect(!sut.workedTimeLabel.isHidden)
    }

    @MainActor
    @Test("status item and popover use the injected current time provider for ongoing worked time")
    func statusItemAndPopoverUseInjectedCurrentTimeProviderForOngoingWorkedTime() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let currentDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 30))
        )

        let sut = AppDelegate()
        let store = TestAttendanceTimeStore()
        store.startTime = startTime
        sut.attendanceTimeStore = store
        sut.currentDateProvider = { currentDate }

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
        #expect(button.title == "02:30")

        button.performClick(nil)

        let popover = try #require(sut.attendancePopover)
        let controller = try #require(popover.contentViewController as? AttendanceTimePopoverViewController)
        controller.loadViewIfNeeded()

        #expect(controller.workedTimeLabel.stringValue == "현재 근무: 02:30")
    }

    @MainActor
    @Test("when only start time exists, worked time refreshes as the current time changes")
    func workedTimeRefreshesWhenCurrentTimeChanges() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let initialNow = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let updatedNow = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 1))
        )
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 30))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = startTime
        var currentNow = initialNow

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: initialNow,
            calendar: calendar,
            currentDateProvider: { currentNow },
            workedTimeRefreshInterval: 0.05
        )

        sut.loadViewIfNeeded()
        #expect(sut.workedTimeLabel.stringValue == "현재 근무: 02:30")

        currentNow = updatedNow
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

        #expect(sut.workedTimeLabel.stringValue == "현재 근무: 02:31")
    }

    @MainActor
    @Test("when start and end times exist, worked time shows the recorded duration")
    func workedTimeShowsRecordedDurationWhenStartAndEndTimesExist() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 21, minute: 0))
        )
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 30))
        )
        let endTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 15))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = startTime
        store.endTime = endTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.workedTimeLabel.stringValue == "현재 근무: 08:45")
        #expect(!sut.workedTimeLabel.isHidden)
    }

    @MainActor
    @Test("saving updated attendance times refreshes worked time immediately")
    func savingUpdatedAttendanceTimesRefreshesWorkedTimeImmediately() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let storedStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let storedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0))
        )
        let updatedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 5))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = storedStartTime
        store.endTime = storedEndTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()
        #expect(sut.workedTimeLabel.stringValue == "현재 근무: 09:00")

        sut.endTimePicker.dateValue = updatedEndTime
        sut.saveButton.performClick(nil)

        #expect(store.endTime == updatedEndTime)
        #expect(sut.workedTimeLabel.stringValue == "현재 근무: 10:05")
    }

    @MainActor
    @Test("status item text and popover worked time always use the same calculated result")
    func statusItemTextAndPopoverWorkedTimeStayInSync() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let storedStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let storedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0))
        )
        let updatedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 5))
        )

        let sut = AppDelegate()
        let store = TestAttendanceTimeStore()
        store.startTime = storedStartTime
        store.endTime = storedEndTime
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
        #expect(button.title == "09:00")

        button.performClick(nil)

        let popover = try #require(sut.attendancePopover)
        let controller = try #require(popover.contentViewController as? AttendanceTimePopoverViewController)
        controller.loadViewIfNeeded()

        #expect(controller.workedTimeLabel.stringValue == "현재 근무: 09:00")

        controller.endTimePicker.dateValue = updatedEndTime
        controller.saveButton.performClick(nil)

        #expect(button.title == "10:05")
        #expect(controller.workedTimeLabel.stringValue == "현재 근무: 10:05")
    }

    @MainActor
    @Test("saving attendance times refreshes every dependent display immediately")
    func savingAttendanceTimesRefreshesEveryDependentDisplayImmediately() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let currentDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let startTimeToSave = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 3))
        )
        let endTimeToSave = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 10))
        )

        let sut = AppDelegate()
        let store = TestAttendanceTimeStore()
        sut.attendanceTimeStore = store
        sut.currentDateProvider = { currentDate }

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

        controller.startTimePicker.dateValue = startTimeToSave
        controller.endTimePicker.dateValue = endTimeToSave
        controller.saveButton.performClick(nil)

        #expect(store.startTime == startTimeToSave)
        #expect(store.endTime == endTimeToSave)
        #expect(button.title == "09:07")
        #expect(controller.workedTimeLabel.stringValue == "현재 근무: 09:07")
        #expect(controller.todayStartTimeLabel.stringValue == "오늘 출근: 09:03")
        #expect(!controller.todayStartTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover shows a placeholder for weekly worked time when no weekly records exist")
    func popoverShowsPlaceholderForWeeklyWorkedTimeWhenNoWeeklyRecordsExist() throws {
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

        #expect(controller.weeklyWorkedTimeLabel.stringValue == "이번 주: --:--")
        #expect(!controller.weeklyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover shows a placeholder for monthly worked time when no monthly records exist")
    func popoverShowsPlaceholderForMonthlyWorkedTimeWhenNoMonthlyRecordsExist() throws {
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

        #expect(controller.monthlyWorkedTimeLabel.stringValue == "이번 달: --:--")
        #expect(!controller.monthlyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover shows the monthly worked time when one completed record exists this month")
    func popoverShowsMonthlyWorkedTimeForSingleCompletedRecordThisMonth() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 30))
        )
        let endTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 15))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = startTime
        store.endTime = endTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.monthlyWorkedTimeLabel.stringValue == "이번 달: 08:45")
        #expect(!sut.monthlyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover sums multiple completed records within this month")
    func popoverSumsMultipleCompletedRecordsWithinThisMonth() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 15, hour: 12, minute: 0))
        )
        let mondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let mondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let tuesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 10, minute: 0))
        )
        let tuesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 16, minute: 30))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime),
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.monthlyWorkedTimeLabel.stringValue == "이번 달: 15:30")
        #expect(!sut.monthlyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover excludes records outside the current month from monthly total")
    func popoverExcludesRecordsOutsideCurrentMonthFromMonthlyTotal() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 15, hour: 12, minute: 0))
        )
        let previousMonthStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 29, hour: 9, minute: 0))
        )
        let previousMonthEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 29, hour: 18, minute: 0))
        )
        let currentMonthStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 10, minute: 0))
        )
        let currentMonthEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 16, minute: 30))
        )
        let nextMonthStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0))
        )
        let nextMonthEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 18, minute: 0))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: previousMonthStartTime, endTime: previousMonthEndTime),
            AttendanceRecord(startTime: currentMonthStartTime, endTime: currentMonthEndTime),
            AttendanceRecord(startTime: nextMonthStartTime, endTime: nextMonthEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.monthlyWorkedTimeLabel.stringValue == "이번 달: 06:30")
        #expect(!sut.monthlyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover uses the latest record when same day is updated within this month")
    func popoverUsesLatestRecordWhenSameDayIsUpdatedWithinThisMonth() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 15, hour: 12, minute: 0))
        )
        let originalStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let originalEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0))
        )
        let updatedStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 10, minute: 0))
        )
        let updatedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 16, minute: 30))
        )
        let otherDayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 9, minute: 0))
        )
        let otherDayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 18, minute: 0))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: originalStartTime, endTime: originalEndTime),
            AttendanceRecord(startTime: updatedStartTime, endTime: updatedEndTime),
            AttendanceRecord(startTime: otherDayStartTime, endTime: otherDayEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.monthlyWorkedTimeLabel.stringValue == "이번 달: 15:30")
        #expect(!sut.monthlyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("saving updated attendance times refreshes monthly worked time immediately")
    func savingUpdatedAttendanceTimesRefreshesMonthlyWorkedTimeImmediately() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 15, hour: 12, minute: 0))
        )
        let initialStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let initialEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0))
        )
        let updatedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 5))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = initialStartTime
        store.endTime = initialEndTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.monthlyWorkedTimeLabel.stringValue == "이번 달: 09:00")

        sut.endTimePicker.dateValue = updatedEndTime
        sut.saveButton.performClick(nil)

        #expect(sut.monthlyWorkedTimeLabel.stringValue == "이번 달: 10:05")
        #expect(!sut.monthlyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("monthly aggregation keeps current weekly and today displays intact")
    func monthlyAggregationKeepsCurrentWeeklyAndTodayDisplaysIntact() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 3))
        )
        let endTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 10))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = startTime
        store.endTime = endTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar,
            currentDateProvider: { referenceDate }
        )

        sut.loadViewIfNeeded()

        #expect(sut.workedTimeLabel.stringValue == "현재 근무: 09:07")
        #expect(!sut.workedTimeLabel.isHidden)
        #expect(sut.weeklyWorkedTimeLabel.stringValue == "이번 주: 09:07")
        #expect(!sut.weeklyWorkedTimeLabel.isHidden)
        #expect(sut.monthlyWorkedTimeLabel.stringValue == "이번 달: 09:07")
        #expect(!sut.monthlyWorkedTimeLabel.isHidden)
        #expect(sut.todayStartTimeLabel.stringValue == "오늘 출근: 09:03")
        #expect(!sut.todayStartTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover shows the weekly worked time when one completed record exists this week")
    func popoverShowsWeeklyWorkedTimeForSingleCompletedRecordThisWeek() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 30))
        )
        let endTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 15))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = startTime
        store.endTime = endTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyWorkedTimeLabel.stringValue == "이번 주: 08:45")
        #expect(!sut.weeklyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover sums multiple completed records within this week")
    func popoverSumsMultipleCompletedRecordsWithinThisWeek() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let mondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let mondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let tuesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 10, minute: 0))
        )
        let tuesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 16, minute: 30))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime),
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyWorkedTimeLabel.stringValue == "이번 주: 15:30")
        #expect(!sut.weeklyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover shows remaining weekly target time when this week's total is under forty hours")
    func popoverShowsRemainingWeeklyTargetTimeWhenWeeklyTotalIsUnderFortyHours() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 12, minute: 0))
        )
        let mondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let mondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let tuesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let tuesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0))
        )
        let wednesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 9, minute: 0))
        )
        let wednesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 18, minute: 0))
        )
        let thursdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 9, minute: 0))
        )
        let thursdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 13, minute: 30))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime),
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime),
            AttendanceRecord(startTime: wednesdayStartTime, endTime: wednesdayEndTime),
            AttendanceRecord(startTime: thursdayStartTime, endTime: thursdayEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyTargetProgressLabel.stringValue == "채워야 하는 시간 08:30")
        #expect(!sut.weeklyTargetProgressLabel.isHidden)
    }

    @MainActor
    @Test("popover shows a completion state when this week's total reaches exactly forty hours")
    func popoverShowsCompletionStateWhenWeeklyTotalReachesExactlyFortyHours() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 12, minute: 0))
        )
        let mondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let mondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 19, minute: 0))
        )
        let tuesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let tuesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 0))
        )
        let wednesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 9, minute: 0))
        )
        let wednesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 19, minute: 0))
        )
        let thursdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 9, minute: 0))
        )
        let thursdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 19, minute: 0))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime),
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime),
            AttendanceRecord(startTime: wednesdayStartTime, endTime: wednesdayEndTime),
            AttendanceRecord(startTime: thursdayStartTime, endTime: thursdayEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyTargetProgressLabel.stringValue == "주간 목표 달성")
        #expect(!sut.weeklyTargetProgressLabel.isHidden)
    }

    @MainActor
    @Test("popover shows overtime when this week's total exceeds forty hours")
    func popoverShowsOvertimeWhenWeeklyTotalExceedsFortyHours() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 12, minute: 0))
        )
        let mondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let mondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 19, minute: 0))
        )
        let tuesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let tuesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 0))
        )
        let wednesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 9, minute: 0))
        )
        let wednesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 19, minute: 0))
        )
        let thursdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 9, minute: 0))
        )
        let thursdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 19, minute: 0))
        )
        let fridayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 9, minute: 0))
        )
        let fridayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 13, minute: 15))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime),
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime),
            AttendanceRecord(startTime: wednesdayStartTime, endTime: wednesdayEndTime),
            AttendanceRecord(startTime: thursdayStartTime, endTime: thursdayEndTime),
            AttendanceRecord(startTime: fridayStartTime, endTime: fridayEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyTargetProgressLabel.stringValue == "초과된 시간 04:15")
        #expect(!sut.weeklyTargetProgressLabel.isHidden)
    }

    @MainActor
    @Test("popover uses different semantic styles for remaining time and overtime")
    func popoverUsesDifferentSemanticStylesForRemainingTimeAndOvertime() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let underReferenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 12, minute: 0))
        )
        let underStore = TestAttendanceTimeStore()
        underStore.records = [
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 18, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 13, minute: 30)))
            )
        ]
        let underController = AttendanceTimePopoverViewController(
            attendanceTimeStore: underStore,
            referenceDate: underReferenceDate,
            calendar: calendar
        )
        underController.loadViewIfNeeded()

        let overtimeReferenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 12, minute: 0))
        )
        let overtimeStore = TestAttendanceTimeStore()
        overtimeStore.records = [
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 19, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 19, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 19, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 13, minute: 15)))
            )
        ]
        let overtimeController = AttendanceTimePopoverViewController(
            attendanceTimeStore: overtimeStore,
            referenceDate: overtimeReferenceDate,
            calendar: calendar
        )
        overtimeController.loadViewIfNeeded()

        let underColor = try #require(underController.weeklyTargetProgressLabel.textColor)
        let overtimeColor = try #require(overtimeController.weeklyTargetProgressLabel.textColor)

        #expect(underColor.isEqual(NSColor.systemOrange))
        #expect(overtimeColor.isEqual(NSColor.systemRed))
    }

    @MainActor
    @Test("popover uses a distinct completion style when this week's total reaches exactly forty hours")
    func popoverUsesDistinctCompletionStyleWhenWeeklyTotalReachesExactlyFortyHours() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 12, minute: 0))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 19, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 19, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 19, minute: 0)))
            )
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        let completionColor = try #require(sut.weeklyTargetProgressLabel.textColor)

        #expect(completionColor.isEqual(NSColor.systemGreen))
    }

    @MainActor
    @Test("saving updated attendance times refreshes weekly target progress text and style immediately")
    func savingUpdatedAttendanceTimesRefreshesWeeklyTargetProgressImmediately() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 12, minute: 0))
        )
        let mondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let mondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let tuesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let tuesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0))
        )
        let wednesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 9, minute: 0))
        )
        let wednesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 18, minute: 0))
        )
        let thursdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 9, minute: 0))
        )
        let thursdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 18, minute: 0))
        )
        let fridayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 9, minute: 0))
        )
        let storedFridayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 12, minute: 0))
        )
        let updatedFridayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 5, hour: 13, minute: 30))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = fridayStartTime
        store.endTime = storedFridayEndTime
        store.records = [
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime),
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime),
            AttendanceRecord(startTime: wednesdayStartTime, endTime: wednesdayEndTime),
            AttendanceRecord(startTime: thursdayStartTime, endTime: thursdayEndTime),
            AttendanceRecord(startTime: fridayStartTime, endTime: storedFridayEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyTargetProgressLabel.stringValue == "채워야 하는 시간 01:00")
        #expect(try #require(sut.weeklyTargetProgressLabel.textColor).isEqual(NSColor.systemOrange))

        sut.endTimePicker.dateValue = updatedFridayEndTime
        sut.saveButton.performClick(nil)

        #expect(store.endTime == updatedFridayEndTime)
        #expect(store.records.last == AttendanceRecord(startTime: fridayStartTime, endTime: updatedFridayEndTime))
        #expect(sut.weeklyTargetProgressLabel.stringValue == "초과된 시간 00:30")
        #expect(try #require(sut.weeklyTargetProgressLabel.textColor).isEqual(NSColor.systemRed))
    }

    @MainActor
    @Test("popover keeps weekly worked time visible alongside weekly target progress")
    func popoverKeepsWeeklyWorkedTimeVisibleAlongsideWeeklyTargetProgress() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 12, minute: 0))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 18, minute: 0)))
            ),
            AttendanceRecord(
                startTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 9, minute: 0))),
                endTime: try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 4, hour: 13, minute: 30)))
            )
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyWorkedTimeLabel.stringValue == "이번 주: 31:30")
        #expect(!sut.weeklyWorkedTimeLabel.isHidden)
        #expect(sut.weeklyTargetProgressLabel.stringValue == "채워야 하는 시간 08:30")
        #expect(!sut.weeklyTargetProgressLabel.isHidden)
    }

    @MainActor
    @Test("popover excludes records outside the current week from the weekly total")
    func popoverExcludesRecordsOutsideCurrentWeekFromWeeklyTotal() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let previousWeekStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 29, hour: 9, minute: 0))
        )
        let previousWeekEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 29, hour: 12, minute: 0))
        )
        let mondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let mondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let tuesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 10, minute: 0))
        )
        let tuesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 16, minute: 30))
        )
        let nextWeekStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 8, hour: 9, minute: 0))
        )
        let nextWeekEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 8, hour: 11, minute: 0))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: previousWeekStartTime, endTime: previousWeekEndTime),
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime),
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime),
            AttendanceRecord(startTime: nextWeekStartTime, endTime: nextWeekEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyWorkedTimeLabel.stringValue == "이번 주: 15:30")
        #expect(!sut.weeklyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover uses the latest record when the same day is updated")
    func popoverUsesLatestRecordWhenSameDayIsUpdated() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let originalMondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let originalMondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let updatedMondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 30))
        )
        let updatedMondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 19, minute: 0))
        )
        let tuesdayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 10, minute: 0))
        )
        let tuesdayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 16, minute: 30))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: originalMondayStartTime, endTime: originalMondayEndTime),
            AttendanceRecord(startTime: updatedMondayStartTime, endTime: updatedMondayEndTime),
            AttendanceRecord(startTime: tuesdayStartTime, endTime: tuesdayEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyWorkedTimeLabel.stringValue == "이번 주: 16:00")
        #expect(!sut.weeklyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover excludes in-progress work from the weekly total by default")
    func popoverExcludesInProgressWorkFromWeeklyTotalByDefault() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 12, minute: 0))
        )
        let mondayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 0))
        )
        let mondayEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 18, minute: 0))
        )
        let inProgressStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 3, hour: 10, minute: 0))
        )
        let store = TestAttendanceTimeStore()
        store.records = [
            AttendanceRecord(startTime: mondayStartTime, endTime: mondayEndTime)
        ]
        store.startTime = inProgressStartTime
        store.endTime = nil

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar,
            currentDateProvider: { referenceDate }
        )

        sut.loadViewIfNeeded()

        #expect(sut.weeklyWorkedTimeLabel.stringValue == "이번 주: 09:00")
        #expect(!sut.weeklyWorkedTimeLabel.isHidden)
    }

    @MainActor
    @Test("saving updated attendance times refreshes weekly worked time immediately")
    func savingUpdatedAttendanceTimesRefreshesWeeklyWorkedTimeImmediately() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let storedStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 0))
        )
        let storedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 0))
        )
        let updatedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 5))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = storedStartTime
        store.endTime = storedEndTime
        store.records = [
            AttendanceRecord(startTime: storedStartTime, endTime: storedEndTime)
        ]

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()
        #expect(sut.weeklyWorkedTimeLabel.stringValue == "이번 주: 09:00")

        sut.endTimePicker.dateValue = updatedEndTime
        sut.saveButton.performClick(nil)

        #expect(store.endTime == updatedEndTime)
        #expect(store.records == [
            AttendanceRecord(startTime: storedStartTime, endTime: updatedEndTime)
        ])
        #expect(sut.weeklyWorkedTimeLabel.stringValue == "이번 주: 10:05")
    }

    @MainActor
    @Test("popover shows a placeholder for today's start time when no start time is stored")
    func popoverShowsPlaceholderForTodayStartTimeWhenNoStartTimeIsStored() throws {
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

        #expect(controller.todayStartTimeLabel.stringValue == "오늘 출근: --")
        #expect(!controller.todayStartTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover shows today's stored start time when today's start time exists")
    func popoverShowsStoredTodayStartTimeWhenStartTimeExists() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 12, minute: 0))
        )
        let todayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 3))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = todayStartTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.todayStartTimeLabel.stringValue == "오늘 출근: 09:03")
        #expect(!sut.todayStartTimeLabel.isHidden)
    }

    @MainActor
    @Test("popover does not reflect start time when only previous day start time exists")
    func popoverDoesNotReflectPreviousDayStartTime() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let previousDayStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 1, hour: 9, minute: 3))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = previousDayStartTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.todayStartTimeLabel.stringValue.isEmpty)
        #expect(sut.todayStartTimeLabel.isHidden)
    }

    @MainActor
    @Test("saving a new today start time refreshes the today start time label immediately")
    func savingNewTodayStartTimeRefreshesLabelImmediately() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let startTimeToSave = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 3))
        )
        let store = TestAttendanceTimeStore()

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()
        #expect(sut.todayStartTimeLabel.stringValue == "오늘 출근: --")

        sut.startTimePicker.dateValue = startTimeToSave
        sut.saveButton.performClick(nil)

        #expect(store.startTime == startTimeToSave)
        #expect(sut.todayStartTimeLabel.stringValue == "오늘 출근: 09:03")
        #expect(!sut.todayStartTimeLabel.isHidden)
    }

    @MainActor
    @Test("updating today's start time replaces the previous displayed value")
    func updatingTodayStartTimeReplacesPreviousDisplayedValue() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let initialStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 8, minute: 30))
        )
        let updatedStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 45))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = initialStartTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()
        #expect(sut.todayStartTimeLabel.stringValue == "오늘 출근: 08:30")

        sut.startTimePicker.dateValue = updatedStartTime
        sut.saveButton.performClick(nil)

        #expect(store.startTime == updatedStartTime)
        #expect(sut.todayStartTimeLabel.stringValue == "오늘 출근: 09:45")
        #expect(sut.todayStartTimeLabel.stringValue != "오늘 출근: 08:30")
    }

    @MainActor
    @Test("today start time display does not break existing persisted time input behavior")
    func todayStartTimeDisplayDoesNotBreakPersistedTimeInputBehavior() throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )
        let persistedStartTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 3))
        )
        let persistedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 10))
        )
        let updatedEndTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 19, minute: 5))
        )
        let store = TestAttendanceTimeStore()
        store.startTime = persistedStartTime
        store.endTime = persistedEndTime

        let sut = AttendanceTimePopoverViewController(
            attendanceTimeStore: store,
            referenceDate: referenceDate,
            calendar: calendar
        )

        sut.loadViewIfNeeded()

        #expect(sut.todayStartTimeLabel.stringValue == "오늘 출근: 09:03")
        #expect(sut.startTimePicker.dateValue == persistedStartTime)
        #expect(sut.endTimePicker.dateValue == persistedEndTime)

        sut.endTimePicker.dateValue = updatedEndTime
        sut.saveButton.performClick(nil)

        #expect(store.endTime == updatedEndTime)
        #expect(sut.todayStartTimeLabel.stringValue == "오늘 출근: 09:03")
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

private final class TestAttendanceTimeStore: AttendanceTimeStore, AttendanceRecordStore {
    var startTime: Date?
    var endTime: Date?
    var records: [AttendanceRecord] = []
}
