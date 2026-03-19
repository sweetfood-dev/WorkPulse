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

protocol AttendanceRecordStore: AnyObject {
    var records: [AttendanceRecord] { get set }
    func upsertRecord(_ record: AttendanceRecord, calendar: Calendar)
}

struct AttendanceRecord: Codable, Equatable {
    let startTime: Date
    let endTime: Date
}

extension AttendanceRecordStore {
    func upsertRecord(_ record: AttendanceRecord, calendar: Calendar) {
        var updatedRecords = records

        if let existingIndex = updatedRecords.lastIndex(where: {
            calendar.isDate($0.startTime, inSameDayAs: record.startTime)
        }) {
            updatedRecords[existingIndex] = record
        } else {
            updatedRecords.append(record)
        }

        records = updatedRecords
    }
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

final class UserDefaultsAttendanceTimeStore: AttendanceTimeStore, AttendanceRecordStore {
    private enum Keys {
        static let startTime = "attendance.startTime"
        static let endTime = "attendance.endTime"
        static let records = "attendance.records"
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

    var records: [AttendanceRecord] {
        get {
            guard let data = userDefaults.data(forKey: Keys.records) else { return [] }
            return (try? JSONDecoder().decode([AttendanceRecord].self, from: data)) ?? []
        }
        set {
            guard !newValue.isEmpty else {
                userDefaults.removeObject(forKey: Keys.records)
                return
            }

            guard let data = try? JSONEncoder().encode(newValue) else { return }
            userDefaults.set(data, forKey: Keys.records)
        }
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
    private enum UIConstants {
        static let workedTimePlaceholder = "--:--"
        static let workedTimePrefix = "현재 근무: "
    }

    private let workedTimeDisplayFactory = WorkedTimeDisplayModelFactory(
        placeholderTimeText: UIConstants.workedTimePlaceholder,
        popoverPrefixText: UIConstants.workedTimePrefix,
        workedTimeCalculator: WorkedTimeCalculator(),
        workedDurationFormatter: WorkedDurationFormatter()
    )
    private(set) var window: NSWindow?
    private(set) var statusItem: NSStatusItem?
    private(set) var attendancePopover: NSPopover?
    var attendanceTimeStore: AttendanceTimeStore = UserDefaultsAttendanceTimeStore()
    var currentDateProvider: () -> Date = Date.init
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
        refreshWorkedTimeDisplay()
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(handleStatusItemClick)
    }

    @objc private func handleStatusItemClick() {
        refreshWorkedTimeDisplay()
        guard let button = statusItem?.button else { return }
        handleStatusItemInteraction(with: button)
    }

    private func refreshWorkedTimeDisplay() {
        let displayModel = workedTimeDisplayFactory.make(
            startTime: attendanceTimeStore.startTime,
            endTime: attendanceTimeStore.endTime,
            currentDate: currentDateProvider()
        )

        statusItem?.button?.title = displayModel.statusItemText
        let controller = attendancePopover?.contentViewController as? AttendanceTimePopoverViewController
        controller?.applyWorkedTimeDisplay(displayModel)
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
            attendanceTimeStore: attendanceTimeStore,
            currentDateProvider: currentDateProvider,
            onSave: { [weak self] in
                self?.refreshWorkedTimeDisplay()
            }
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
        static let workedTimeTimePlaceholder = "--:--"
        static let workedTimePrefix = "현재 근무: "
        static let weeklyWorkedTimePlaceholder = "이번 주: --:--"
        static let weeklyTargetMetText = "주간 목표 달성"
        static let weeklyTargetOvertimePrefix = "초과된 시간 "
        static let weeklyTargetRemainingPrefix = "채워야 하는 시간 "
        static let todayStartTimePlaceholder = "오늘 출근: --"
        static let todayStartTimePrefix = "오늘 출근: "
    }

    private let workedTimeDisplayFactory: WorkedTimeDisplayModelFactory
    private(set) var workedTimeLabel = NSTextField(labelWithString: "")
    private(set) var weeklyWorkedTimeLabel = NSTextField(labelWithString: "")
    private(set) var weeklyTargetProgressLabel = NSTextField(labelWithString: "")
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
    private let currentDateProvider: () -> Date
    private let workedTimeRefreshInterval: TimeInterval
    private let dayMatcher: AttendanceDayMatcher
    private let timeFormatter: AttendanceTimeFormatter
    private let workedDurationFormatter: WorkedDurationFormatter
    private let todayStartTimeDisplayFactory: TodayStartTimeDisplayModelFactory
    private let weeklyWorkedTimeCalculator: WeeklyWorkedTimeCalculator
    private let weeklyTargetProgressCalculator: WeeklyTargetProgressCalculator
    private let weeklyTargetProgressStyleResolver: WeeklyTargetProgressSemanticStyleResolver
    private let weeklyTargetProgressStylePalette: WeeklyTargetProgressStylePalette
    private let onSave: (() -> Void)?
    private var workedTimeRefreshTimer: Timer?

    init(
        attendanceTimeStore: AttendanceTimeStore,
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        currentDateProvider: @escaping () -> Date = Date.init,
        workedTimeRefreshInterval: TimeInterval = 60,
        onSave: (() -> Void)? = nil
    ) {
        self.attendanceTimeStore = attendanceTimeStore
        self.referenceDate = referenceDate
        self.calendar = calendar
        self.currentDateProvider = currentDateProvider
        self.workedTimeRefreshInterval = workedTimeRefreshInterval
        self.onSave = onSave
        dayMatcher = AttendanceDayMatcher(calendar: calendar)
        timeFormatter = AttendanceTimeFormatter(calendar: calendar)
        workedDurationFormatter = WorkedDurationFormatter()
        workedTimeDisplayFactory = WorkedTimeDisplayModelFactory(
            placeholderTimeText: UIConstants.workedTimeTimePlaceholder,
            popoverPrefixText: UIConstants.workedTimePrefix,
            workedTimeCalculator: WorkedTimeCalculator(),
            workedDurationFormatter: workedDurationFormatter
        )
        todayStartTimeDisplayFactory = TodayStartTimeDisplayModelFactory(
            placeholderText: UIConstants.todayStartTimePlaceholder,
            prefixText: UIConstants.todayStartTimePrefix,
            timeFormatter: timeFormatter
        )
        weeklyWorkedTimeCalculator = WeeklyWorkedTimeCalculator(calendar: calendar)
        weeklyTargetProgressCalculator = WeeklyTargetProgressCalculator(
            targetDuration: WeeklyTargetConfiguration.standard.duration
        )
        weeklyTargetProgressStyleResolver = WeeklyTargetProgressSemanticStyleResolver()
        weeklyTargetProgressStylePalette = WeeklyTargetProgressStylePalette()
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

    deinit {
        workedTimeRefreshTimer?.invalidate()
    }

    override func loadView() {
        view = makeContentView()
        refreshAttendanceDisplayState()
        applyInitialInputValues()
        configureSaveAction()
    }

    private func makeContentView() -> NSView {
        AttendanceTimePopoverContentView(
            workedTimeLabel: workedTimeLabel,
            weeklyWorkedTimeLabel: weeklyWorkedTimeLabel,
            weeklyTargetProgressLabel: weeklyTargetProgressLabel,
            todayStartTimeLabel: todayStartTimeLabel,
            startTimePicker: startTimePicker,
            endTimePicker: endTimePicker,
            saveButton: saveButton
        )
    }

    private func refreshWorkedTimeDisplay() {
        let displayModel = workedTimeDisplayFactory.make(
            startTime: attendanceTimeStore.startTime,
            endTime: attendanceTimeStore.endTime,
            currentDate: currentDateProvider()
        )

        applyWorkedTimeDisplay(displayModel)
    }

    func applyWorkedTimeDisplay(_ displayModel: WorkedTimeDisplayModel) {
        workedTimeLabel.stringValue = displayModel.popoverText
        workedTimeLabel.isHidden = false
    }

    private func configureWorkedTimeRefreshTimer() {
        workedTimeRefreshTimer?.invalidate()

        guard attendanceTimeStore.startTime != nil, attendanceTimeStore.endTime == nil else {
            workedTimeRefreshTimer = nil
            return
        }

        workedTimeRefreshTimer = Timer.scheduledTimer(withTimeInterval: workedTimeRefreshInterval, repeats: true) {
            [weak self] _ in
            self?.refreshWorkedTimeDisplay()
        }
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

    private func refreshWeeklySummaryDisplay() {
        let totalWorkedDuration = weeklyWorkedTimeCalculator.workedDuration(
            records: makeWeeklyAttendanceRecords(),
            referenceDate: referenceDate
        )
        let progress = weeklyTargetProgressCalculator.progress(
            totalWorkedDuration: totalWorkedDuration
        )

        applyWeeklyWorkedTimeDisplay(totalWorkedDuration: totalWorkedDuration)
        applyWeeklyTargetProgressDisplay(progress)
    }

    private func applyWeeklyWorkedTimeDisplay(totalWorkedDuration: TimeInterval?) {
        guard let totalWorkedDuration else {
            weeklyWorkedTimeLabel.stringValue = UIConstants.weeklyWorkedTimePlaceholder
            weeklyWorkedTimeLabel.isHidden = false
            return
        }

        weeklyWorkedTimeLabel.stringValue = "이번 주: \(workedDurationFormatter.string(from: totalWorkedDuration))"
        weeklyWorkedTimeLabel.isHidden = false
    }

    private func applyWeeklyTargetProgressDisplay(_ progress: WeeklyTargetProgress?) {
        guard let progress else {
            weeklyTargetProgressLabel.isHidden = true
            return
        }

        let semanticStyle = weeklyTargetProgressStyleResolver.style(for: progress)

        switch progress.status {
        case .met:
            weeklyTargetProgressLabel.stringValue = UIConstants.weeklyTargetMetText
            weeklyTargetProgressLabel.isHidden = false
        case let .overtime(overtimeDuration):
            weeklyTargetProgressLabel.stringValue = "\(UIConstants.weeklyTargetOvertimePrefix)\(workedDurationFormatter.string(from: overtimeDuration))"
            weeklyTargetProgressLabel.isHidden = false
        case let .remaining(remainingDuration):
            weeklyTargetProgressLabel.stringValue = "\(UIConstants.weeklyTargetRemainingPrefix)\(workedDurationFormatter.string(from: remainingDuration))"
            weeklyTargetProgressLabel.isHidden = false
        }

        weeklyTargetProgressLabel.textColor = weeklyTargetProgressStylePalette.textColor(for: semanticStyle)
    }

    private func makeWeeklyAttendanceRecords() -> [AttendanceRecord] {
        if let recordStore = attendanceTimeStore as? AttendanceRecordStore, !recordStore.records.isEmpty {
            return recordStore.records
        }

        guard
            let startTime = attendanceTimeStore.startTime,
            let endTime = attendanceTimeStore.endTime
        else {
            return []
        }

        return [
            AttendanceRecord(startTime: startTime, endTime: endTime)
        ]
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
        let savedStartTime = startTimePicker.dateValue
        let savedEndTime = endTimePicker.dateValue

        attendanceTimeStore.startTime = savedStartTime
        attendanceTimeStore.endTime = savedEndTime

        if let recordStore = attendanceTimeStore as? AttendanceRecordStore {
            let savedRecord = AttendanceRecord(startTime: savedStartTime, endTime: savedEndTime)
            recordStore.upsertRecord(savedRecord, calendar: calendar)
        }

        handleAttendanceTimeSave()
    }

    private func refreshAttendanceDisplayState() {
        refreshWorkedTimeDisplay()
        refreshWeeklySummaryDisplay()
        configureWorkedTimeRefreshTimer()
        refreshTodayStartTimeDisplay()
    }

    private func handleAttendanceTimeSave() {
        refreshAttendanceDisplayState()
        onSave?()
    }

}

private final class AttendanceTimePopoverContentView: NSView {
    init(
        workedTimeLabel: NSTextField,
        weeklyWorkedTimeLabel: NSTextField,
        weeklyTargetProgressLabel: NSTextField,
        todayStartTimeLabel: NSTextField,
        startTimePicker: NSDatePicker,
        endTimePicker: NSDatePicker,
        saveButton: NSButton
    ) {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 262))

        workedTimeLabel.frame = NSRect(x: 20, y: 212, width: 240, height: 20)
        weeklyWorkedTimeLabel.frame = NSRect(x: 20, y: 184, width: 240, height: 20)
        weeklyTargetProgressLabel.frame = NSRect(x: 20, y: 156, width: 240, height: 20)
        todayStartTimeLabel.frame = NSRect(x: 20, y: 128, width: 240, height: 20)
        startTimePicker.frame = NSRect(x: 20, y: 100, width: 240, height: 24)
        endTimePicker.frame = NSRect(x: 20, y: 52, width: 240, height: 24)
        saveButton.frame = NSRect(x: 200, y: 16, width: 60, height: 30)

        addSubview(workedTimeLabel)
        addSubview(weeklyWorkedTimeLabel)
        addSubview(weeklyTargetProgressLabel)
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
