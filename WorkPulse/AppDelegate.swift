//
//  AppDelegate.swift
//  WorkPulse
//
//  Created by todoc on 3/13/26.
//

import AppKit

protocol AttendanceTimeStore: AnyObject {
    var startTime: Date? { get set }
    var endTime: Date? { get set }
}

struct AttendanceTimeRecord: Equatable {
    let startTime: Date
    let endTime: Date?
}

extension AttendanceTimeStore {
    func todayRecord(
        referenceDate: Date,
        dayMatcher: AttendanceDayMatcher
    ) -> AttendanceTimeRecord? {
        guard let startTime else { return nil }
        guard dayMatcher.isInSameDay(startTime, as: referenceDate) else { return nil }

        return AttendanceTimeRecord(
            startTime: startTime,
            endTime: endTime
        )
    }
}

struct AttendanceTimeInputModel: Equatable {
    let startTime: Date
    let endTime: Date

    static func fromStoredValues(
        startTime: Date?,
        endTime: Date?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> AttendanceTimeInputModel {
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let fallbackStart = calendar.date(byAdding: .hour, value: 9, to: startOfDay) ?? referenceDate
        let fallbackEnd = calendar.date(byAdding: .hour, value: 18, to: startOfDay) ?? referenceDate

        return AttendanceTimeInputModel(
            startTime: startTime ?? fallbackStart,
            endTime: endTime ?? fallbackEnd
        )
    }
}

final class UserDefaultsAttendanceTimeStore: AttendanceTimeStore {
    private enum Keys {
        static let startTime = "attendance.startTime"
        static let endTime = "attendance.endTime"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var startTime: Date? {
        get { userDefaults.object(forKey: Keys.startTime) as? Date }
        set { set(newValue, forKey: Keys.startTime) }
    }

    var endTime: Date? {
        get { userDefaults.object(forKey: Keys.endTime) as? Date }
        set { set(newValue, forKey: Keys.endTime) }
    }

    private func set(_ value: Date?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private(set) var window: NSWindow?
    private(set) var statusItem: NSStatusItem?
    private(set) var attendancePopover: NSPopover?
    var attendanceTimeStore: AttendanceTimeStore = UserDefaultsAttendanceTimeStore()
    var applicationActivator: (Bool) -> Void = { shouldIgnoreOtherApps in
        NSApplication.shared.activate(ignoringOtherApps: shouldIgnoreOtherApps)
    }
    var popoverPresenter: (NSPopover, NSStatusBarButton) -> Void = { popover, button in
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard statusItem == nil else { return }

        configureStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "WorkPulse"
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(handleStatusItemClick)
    }

    @objc private func handleStatusItemClick() {
        guard let button = statusItem?.button else { return }
        handleStatusItemInteraction(with: button)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow, closingWindow === window else {
            return
        }

        window = nil
    }

    private func presentMainWindow() {
        if window == nil {
            let viewController = ViewController()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "WorkPulse"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentViewController = viewController
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
    }

    private func handleStatusItemInteraction(with button: NSStatusBarButton) {
        applicationActivator(true)
        presentMainWindow()
        presentAttendancePopover(relativeTo: button)
    }

    private func presentAttendancePopover(relativeTo button: NSStatusBarButton) {
        closeExistingAttendancePopover()

        let popover = makeAttendancePopover()
        attendancePopover = popover
        popoverPresenter(popover, button)
    }

    private func closeExistingAttendancePopover() {
        if let existingPopover = attendancePopover {
            existingPopover.close()
            attendancePopover = nil
        }
    }

    private func makeAttendancePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = AttendanceTimePopoverViewController(
            attendanceTimeStore: attendanceTimeStore
        )
        return popover
    }

    func popoverDidClose(_ notification: Notification) {
        guard notification.object as? NSPopover === attendancePopover else {
            return
        }

        attendancePopover = nil
    }
}

final class AttendanceTimePopoverViewController: NSViewController {
    private enum UIConstants {
        static let todayStartTimePlaceholder = "오늘 출근: --"
        static let todayStartTimePrefix = "오늘 출근: "
    }

    private(set) var startTimePicker = AttendanceTimePopoverViewController.makeTimePicker()
    private(set) var endTimePicker = AttendanceTimePopoverViewController.makeTimePicker()
    private(set) var saveButton = NSButton(title: "Save", target: nil, action: nil)
    private(set) var todayStartTimeLabel = NSTextField(labelWithString: "")
    var defaultStartTime: Date { initialInputModel.startTime }
    var defaultEndTime: Date { initialInputModel.endTime }
    private let attendanceTimeStore: AttendanceTimeStore
    private let initialInputModel: AttendanceTimeInputModel
    private let referenceDate: Date
    private let calendar: Calendar
    private let dayMatcher: AttendanceDayMatcher
    private let timeFormatter: AttendanceTimeFormatter
    private let todayStartTimeDisplayFactory: TodayStartTimeDisplayModelFactory

    init(
        attendanceTimeStore: AttendanceTimeStore,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.attendanceTimeStore = attendanceTimeStore
        self.referenceDate = referenceDate
        self.calendar = calendar
        dayMatcher = AttendanceDayMatcher(calendar: calendar)
        timeFormatter = AttendanceTimeFormatter(calendar: calendar)
        todayStartTimeDisplayFactory = TodayStartTimeDisplayModelFactory(
            placeholderText: UIConstants.todayStartTimePlaceholder,
            prefixText: UIConstants.todayStartTimePrefix,
            timeFormatter: timeFormatter
        )
        initialInputModel = AttendanceTimeInputModel.fromStoredValues(
            startTime: attendanceTimeStore.startTime,
            endTime: attendanceTimeStore.endTime,
            referenceDate: referenceDate,
            calendar: calendar
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = makeContentView()
        refreshTodayStartTimeDisplay()
        applyInitialInputValues()
        configureSaveAction()
    }

    private func makeContentView() -> NSView {
        AttendanceTimePopoverContentView(
            todayStartTimeLabel: todayStartTimeLabel,
            startTimePicker: startTimePicker,
            endTimePicker: endTimePicker,
            saveButton: saveButton
        )
    }

    private func refreshTodayStartTimeDisplay() {
        let todayRecord = attendanceTimeStore.todayRecord(
            referenceDate: referenceDate,
            dayMatcher: dayMatcher
        )
        let displayModel = todayStartTimeDisplayFactory.make(
            startTime: attendanceTimeStore.startTime,
            todayRecord: todayRecord
        )

        applyTodayStartTimeDisplay(displayModel)
    }

    private func applyTodayStartTimeDisplay(_ displayModel: TodayStartTimeDisplayModel) {
        todayStartTimeLabel.stringValue = displayModel.text
        todayStartTimeLabel.isHidden = displayModel.isHidden
    }

    private func applyInitialInputValues() {
        startTimePicker.dateValue = defaultStartTime
        endTimePicker.dateValue = defaultEndTime
    }

    private func configureSaveAction() {
        saveButton.target = self
        saveButton.action = #selector(handleSaveButtonClick)
    }

    private static func makeTimePicker() -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        return picker
    }

    @objc private func handleSaveButtonClick() {
        saveCurrentInput()
    }

    private func saveCurrentInput() {
        attendanceTimeStore.startTime = startTimePicker.dateValue
        attendanceTimeStore.endTime = endTimePicker.dateValue
        refreshTodayStartTimeDisplay()
    }

}

private final class AttendanceTimePopoverContentView: NSView {
    init(
        todayStartTimeLabel: NSTextField,
        startTimePicker: NSDatePicker,
        endTimePicker: NSDatePicker,
        saveButton: NSButton
    ) {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 210))

        todayStartTimeLabel.frame = NSRect(x: 20, y: 160, width: 240, height: 20)
        startTimePicker.frame = NSRect(x: 20, y: 104, width: 240, height: 24)
        endTimePicker.frame = NSRect(x: 20, y: 56, width: 240, height: 24)
        saveButton.frame = NSRect(x: 200, y: 16, width: 60, height: 30)

        addSubview(todayStartTimeLabel)
        addSubview(startTimePicker)
        addSubview(endTimePicker)
        addSubview(saveButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
