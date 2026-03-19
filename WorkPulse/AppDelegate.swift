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
    func records(
        containing referenceDate: Date,
        matches: @escaping (Date, Date) -> Bool
    ) -> [AttendanceRecord]
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

    func records(
        containing referenceDate: Date,
        matches: @escaping (Date, Date) -> Bool
    ) -> [AttendanceRecord] {
        records.filter { matches($0.startTime, referenceDate) }
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

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private enum UIConstants {
        static let workedTimePlaceholder = "--:--"
        static let workedTimePrefix = "현재 근무: "
        static let statusItemSymbolName = "clock.badge.checkmark"
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

        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.isVisible = true
        if let image = NSImage(systemSymbolName: UIConstants.statusItemSymbolName, accessibilityDescription: "WorkPulse") {
            image.isTemplate = true
            statusItem?.button?.image = image
            statusItem?.button?.imagePosition = .imageLeading
        }
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
        static let monthlyWorkedTimePlaceholder = "이번 달: --:--"
        static let todayStartTimePlaceholder = "오늘 출근: --"
        static let todayStartTimePrefix = "오늘 출근: "
        static let currentSessionTitle = "CURRENT SESSION"
        static let dailyGoalText = "Goal: 8h"
        static let dailyGoalDuration: TimeInterval = 8 * 60 * 60
    }

    private let workedTimeDisplayFactory: WorkedTimeDisplayModelFactory
    private let workedTimeCalculator = WorkedTimeCalculator()
    private(set) var workedTimeLabel = NSTextField(labelWithString: "")
    private(set) var weeklyWorkedTimeLabel = NSTextField(labelWithString: "")
    private(set) var weeklyTargetProgressLabel = NSTextField(labelWithString: "")
    private(set) var monthlyWorkedTimeLabel = NSTextField(labelWithString: "")
    private(set) var dateTitleLabel = NSTextField(labelWithString: "")
    private(set) var sessionSubtitleLabel = NSTextField(labelWithString: "")
    private(set) var currentSessionLabel = NSTextField(labelWithString: UIConstants.currentSessionTitle)
    private(set) var progressStartLabel = NSTextField(labelWithString: "0h")
    private(set) var progressGoalLabel = NSTextField(labelWithString: UIConstants.dailyGoalText)
    private(set) var currentSessionProgressView = AttendanceProgressBarView()
    private(set) var settingsButton = NSButton()
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
    private let weekMatcher: AttendanceWeekMatcher
    private let monthMatcher: AttendanceMonthMatcher
    private let timeFormatter: AttendanceTimeFormatter
    private let workedDurationFormatter: WorkedDurationFormatter
    private let todayStartTimeDisplayFactory: TodayStartTimeDisplayModelFactory
    private let weeklyWorkedTimeCalculator: WeeklyWorkedTimeCalculator
    private let monthlyWorkedTimeCalculator: MonthlyWorkedTimeCalculator
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
        weekMatcher = AttendanceWeekMatcher(calendar: calendar)
        monthMatcher = AttendanceMonthMatcher(calendar: calendar)
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
        monthlyWorkedTimeCalculator = MonthlyWorkedTimeCalculator(calendar: calendar)
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
        configureInputActions()
    }

    private func makeContentView() -> NSView {
        AttendanceTimePopoverContentView(
            workedTimeLabel: workedTimeLabel,
            weeklyWorkedTimeLabel: weeklyWorkedTimeLabel,
            weeklyTargetProgressLabel: weeklyTargetProgressLabel,
            monthlyWorkedTimeLabel: monthlyWorkedTimeLabel,
            dateTitleLabel: dateTitleLabel,
            sessionSubtitleLabel: sessionSubtitleLabel,
            currentSessionLabel: currentSessionLabel,
            progressStartLabel: progressStartLabel,
            progressGoalLabel: progressGoalLabel,
            currentSessionProgressView: currentSessionProgressView,
            settingsButton: settingsButton,
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
        refreshCurrentSessionProgress()
    }

    func applyWorkedTimeDisplay(_ displayModel: WorkedTimeDisplayModel) {
        workedTimeLabel.stringValue = currentWorkedTimeText()
        workedTimeLabel.isHidden = false
    }

    private func currentWorkedTimeText() -> String {
        let workedDuration = workedTimeCalculator.workedDuration(
            startTime: attendanceTimeStore.startTime,
            endTime: attendanceTimeStore.endTime,
            currentDate: currentDateProvider()
        )

        guard let workedDuration else {
            return UIConstants.workedTimeTimePlaceholder
        }

        return workedDurationFormatter.stringIncludingSeconds(from: workedDuration)
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
        sessionSubtitleLabel.stringValue = checkedInText()
        sessionSubtitleLabel.textColor = .secondaryLabelColor
    }

    private func refreshSummaryDisplay() {
        refreshHeaderDisplay()
        refreshWorkedTimeDisplay()
        refreshWeeklySummaryDisplay()
        refreshMonthlyWorkedTimeDisplay()
    }

    private func refreshHeaderDisplay() {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        dateTitleLabel.stringValue = formatter.string(from: referenceDate)
        sessionSubtitleLabel.stringValue = checkedInText()
    }

    private func checkedInText() -> String {
        guard let startTime = attendanceTimeStore.startTime else {
            return "Checked in at --"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"
        return "Checked in at \(formatter.string(from: startTime))"
    }

    private func refreshCurrentSessionProgress() {
        let workedDuration = workedTimeCalculator.workedDuration(
            startTime: attendanceTimeStore.startTime,
            endTime: attendanceTimeStore.endTime,
            currentDate: currentDateProvider()
        ) ?? 0
        let ratio = min(max(workedDuration / UIConstants.dailyGoalDuration, 0), 1)
        currentSessionProgressView.setProgress(ratio)
    }

    private func refreshWeeklySummaryDisplay() {
        let totalWorkedDuration = weeklyWorkedTimeCalculator.workedDuration(
            records: attendanceRecords(
                containing: referenceDate,
                matches: weekMatcher.contains
            ),
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

        weeklyWorkedTimeLabel.stringValue = workedDurationFormatter.koreanSummaryString(from: totalWorkedDuration)
        weeklyWorkedTimeLabel.isHidden = false
    }

    private func applyMonthlyWorkedTimeDisplay(totalWorkedDuration: TimeInterval?) {
        guard let totalWorkedDuration else {
            monthlyWorkedTimeLabel.stringValue = UIConstants.monthlyWorkedTimePlaceholder
            monthlyWorkedTimeLabel.isHidden = false
            return
        }

        monthlyWorkedTimeLabel.stringValue = workedDurationFormatter.koreanSummaryString(from: totalWorkedDuration)
        monthlyWorkedTimeLabel.isHidden = false
    }

    private func applyWeeklyTargetProgressDisplay(_ progress: WeeklyTargetProgress?) {
        guard let progress else {
            weeklyTargetProgressLabel.isHidden = true
            weeklyTargetProgressLabel.superview?.isHidden = true
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
        weeklyTargetProgressLabel.superview?.isHidden = false
    }

    private func refreshMonthlyWorkedTimeDisplay() {
        let totalWorkedDuration = monthlyWorkedTimeCalculator.workedDuration(
            records: attendanceRecords(
                containing: referenceDate,
                matches: monthMatcher.contains
            ),
            referenceDate: referenceDate
        )

        applyMonthlyWorkedTimeDisplay(totalWorkedDuration: totalWorkedDuration)
    }

    private func attendanceRecords(
        containing referenceDate: Date,
        matches: @escaping (Date, Date) -> Bool
    ) -> [AttendanceRecord] {
        if let recordStore = attendanceTimeStore as? AttendanceRecordStore {
            let storedRecords = recordStore.records(
                containing: referenceDate,
                matches: matches
            )

            if !storedRecords.isEmpty {
                return storedRecords
            }
        }

        guard
            let startTime = attendanceTimeStore.startTime,
            let endTime = attendanceTimeStore.endTime
        else {
            return []
        }

        guard matches(startTime, referenceDate) else { return [] }

        return [AttendanceRecord(startTime: startTime, endTime: endTime)]
    }

    private func applyInitialInputValues() {
        startTimePicker.dateValue = defaultStartTime
        endTimePicker.dateValue = defaultEndTime
    }

    private func configureInputActions() {
        startTimePicker.target = self
        startTimePicker.action = #selector(handleTimePickerChange)
        endTimePicker.target = self
        endTimePicker.action = #selector(handleTimePickerChange)
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsButton.isBordered = false
    }

    private static func makeTimePicker() -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        return picker
    }

    @objc private func handleTimePickerChange() {
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
        refreshSummaryDisplay()
        configureWorkedTimeRefreshTimer()
        refreshTodayStartTimeDisplay()
    }

    private func handleAttendanceTimeSave() {
        refreshAttendanceDisplayState()
        onSave?()
    }

}

private final class AttendanceTimePopoverContentView: NSView {
    private enum Layout {
        static let contentSize = NSSize(width: 340, height: 440)
        static let horizontalInset: CGFloat = 20
        static let sectionSpacing: CGFloat = 14
        static let cornerRadius: CGFloat = 14
        static let separatorColor = NSColor(
            calibratedRed: 232 / 255,
            green: 235 / 255,
            blue: 240 / 255,
            alpha: 1
        )
    }

    init(
        workedTimeLabel: NSTextField,
        weeklyWorkedTimeLabel: NSTextField,
        weeklyTargetProgressLabel: NSTextField,
        monthlyWorkedTimeLabel: NSTextField,
        dateTitleLabel: NSTextField,
        sessionSubtitleLabel: NSTextField,
        currentSessionLabel: NSTextField,
        progressStartLabel: NSTextField,
        progressGoalLabel: NSTextField,
        currentSessionProgressView: AttendanceProgressBarView,
        settingsButton: NSButton,
        startTimePicker: NSDatePicker,
        endTimePicker: NSDatePicker,
        saveButton _: NSButton
    ) {
        super.init(frame: NSRect(origin: .zero, size: Layout.contentSize))

        wantsLayer = true
        layer?.backgroundColor = NSColor(
            calibratedRed: 244 / 255,
            green: 247 / 255,
            blue: 251 / 255,
            alpha: 1
        ).cgColor

        let cardView = makeCardView()
        addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])

        styleHeaderTitle(dateTitleLabel)
        styleHeaderSubtitle(sessionSubtitleLabel)
        styleCurrentSessionLabel(currentSessionLabel)
        let inputCard = makeInputCard(
            startTimePicker: startTimePicker,
            endTimePicker: endTimePicker
        )

        styleWorkedTimeLabel(workedTimeLabel)
        styleProgressCaption(progressStartLabel, alignment: .left)
        styleProgressCaption(progressGoalLabel, alignment: .right)
        styleSettingsButton(settingsButton)

        let headerStack = makeHeader(
            dateTitleLabel: dateTitleLabel,
            sessionSubtitleLabel: sessionSubtitleLabel,
            settingsButton: settingsButton
        )
        let progressLabelsRow = makeProgressLabelsRow(
            progressStartLabel: progressStartLabel,
            progressGoalLabel: progressGoalLabel
        )
        let footer = makeFooter(
            weeklyWorkedTimeLabel: weeklyWorkedTimeLabel,
            monthlyWorkedTimeLabel: monthlyWorkedTimeLabel
        )
        let currentSessionSection = NSStackView(views: [
            makeSessionHeading(currentSessionLabel: currentSessionLabel),
            workedTimeLabel,
            currentSessionProgressView,
            progressLabelsRow,
        ])
        currentSessionSection.orientation = .vertical
        currentSessionSection.alignment = .centerX
        currentSessionSection.spacing = Layout.sectionSpacing
        currentSessionSection.translatesAutoresizingMaskIntoConstraints = false

        let headerSection = wrapInInsets(headerStack, horizontal: Layout.horizontalInset, top: 18, bottom: 12)
        let currentSection = wrapInInsets(currentSessionSection, horizontal: Layout.horizontalInset, top: 18, bottom: 18)
        let footerSection = wrapInInsets(footer, horizontal: Layout.horizontalInset, top: 14, bottom: 18)

        let contentStack = NSStackView(views: [
            headerSection,
            makeSeparator(),
            currentSection,
            inputCard,
            footerSection,
        ])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor),
            currentSessionSection.widthAnchor.constraint(equalTo: currentSection.widthAnchor, constant: -Layout.horizontalInset * 2),
            currentSessionProgressView.widthAnchor.constraint(equalTo: currentSessionSection.widthAnchor),
            progressLabelsRow.widthAnchor.constraint(equalTo: currentSessionSection.widthAnchor),
            footer.widthAnchor.constraint(equalTo: footerSection.widthAnchor, constant: -Layout.horizontalInset * 2),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeCardView() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.cornerRadius = Layout.cornerRadius
        view.layer?.backgroundColor = NSColor.white.cgColor
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor(
            calibratedRed: 223 / 255,
            green: 230 / 255,
            blue: 240 / 255,
            alpha: 1
        ).cgColor
        return view
    }

    private func makeSeparator() -> NSView {
        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = Layout.separatorColor.cgColor
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1),
        ])
        return separator
    }

    private func wrapInInsets(_ content: NSView, horizontal: CGFloat, top: CGFloat, bottom: CGFloat) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontal),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontal),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: top),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottom),
        ])
        return container
    }

    private func styleHeaderTitle(_ label: NSTextField) {
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = .labelColor
    }

    private func styleHeaderSubtitle(_ label: NSTextField) {
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
    }

    private func styleCurrentSessionLabel(_ label: NSTextField) {
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = NSColor(
            calibratedRed: 148 / 255,
            green: 163 / 255,
            blue: 184 / 255,
            alpha: 1
        )
        label.alignment = .center
    }

    private func makeIconView(symbolName: String, tintColor: NSColor, pointSize: CGFloat) -> NSImageView {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        imageView.contentTintColor = tintColor
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: pointSize + 4),
            imageView.heightAnchor.constraint(equalToConstant: pointSize + 4),
        ])
        return imageView
    }

    private func makeMutedLabel(with text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func styleWorkedTimeLabel(_ label: NSTextField) {
        label.font = .monospacedDigitSystemFont(ofSize: 42, weight: .light)
        label.textColor = NSColor(
            calibratedRed: 35 / 255,
            green: 111 / 255,
            blue: 255 / 255,
            alpha: 1
        )
        label.alignment = .center
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 280),
        ])
    }

    private func styleProgressCaption(_ label: NSTextField, alignment: NSTextAlignment) {
        label.font = .systemFont(ofSize: 9, weight: .bold)
        label.textColor = .secondaryLabelColor
        label.alignment = alignment
    }

    private func makeHeader(
        dateTitleLabel: NSTextField,
        sessionSubtitleLabel: NSTextField,
        settingsButton: NSButton
    ) -> NSView {
        let dateRow = NSStackView(views: [
            makeIconView(symbolName: "calendar", tintColor: .secondaryLabelColor, pointSize: 15),
            dateTitleLabel,
        ])
        dateRow.orientation = .horizontal
        dateRow.alignment = .centerY
        dateRow.spacing = 8

        let subtitleRow = NSStackView(views: [
            makeIconView(symbolName: "arrow.right.to.line", tintColor: .systemGreen, pointSize: 15),
            sessionSubtitleLabel,
        ])
        subtitleRow.orientation = .horizontal
        subtitleRow.alignment = .centerY
        subtitleRow.spacing = 8

        let leftStack = NSStackView(views: [dateRow, subtitleRow])
        leftStack.orientation = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 4

        let header = NSStackView(views: [leftStack, settingsButton])
        header.orientation = .horizontal
        header.alignment = .top
        header.distribution = .fill
        header.translatesAutoresizingMaskIntoConstraints = false
        return header
    }

    private func makeSessionHeading(currentSessionLabel: NSTextField) -> NSView {
        let row = NSStackView(views: [
            makeIconView(symbolName: "hourglass", tintColor: NSColor(calibratedRed: 0 / 255, green: 122 / 255, blue: 255 / 255, alpha: 1), pointSize: 16),
            currentSessionLabel,
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeProgressLabelsRow(
        progressStartLabel: NSTextField,
        progressGoalLabel: NSTextField
    ) -> NSView {
        let row = NSStackView(views: [progressStartLabel, progressGoalLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeFooter(
        weeklyWorkedTimeLabel: NSTextField,
        monthlyWorkedTimeLabel: NSTextField
    ) -> NSView {
        let weeklyCaption = makeFooterCaption(with: "THIS WEEK")
        let monthlyCaption = makeFooterCaption(with: "THIS MONTH")
        styleFooterValue(weeklyWorkedTimeLabel, alignment: .left)
        styleFooterValue(monthlyWorkedTimeLabel, alignment: .right)

        let weeklyHeader = NSStackView(views: [
            makeIconView(symbolName: "calendar", tintColor: .secondaryLabelColor, pointSize: 14),
            weeklyCaption,
        ])
        weeklyHeader.orientation = .horizontal
        weeklyHeader.alignment = .centerY
        weeklyHeader.spacing = 6

        let monthlyHeader = NSStackView(views: [
            monthlyCaption,
            makeIconView(symbolName: "chart.bar", tintColor: .secondaryLabelColor, pointSize: 14),
        ])
        monthlyHeader.orientation = .horizontal
        monthlyHeader.alignment = .centerY
        monthlyHeader.spacing = 6

        let weeklyStack = NSStackView(views: [weeklyHeader, weeklyWorkedTimeLabel])
        weeklyStack.orientation = .vertical
        weeklyStack.alignment = .leading
        weeklyStack.spacing = 4

        let monthlyStack = NSStackView(views: [monthlyHeader, monthlyWorkedTimeLabel])
        monthlyStack.orientation = .vertical
        monthlyStack.alignment = .trailing
        monthlyStack.spacing = 4

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSStackView(views: [weeklyStack, spacer, monthlyStack])
        footer.orientation = .horizontal
        footer.alignment = .top
        footer.distribution = .fill
        footer.translatesAutoresizingMaskIntoConstraints = false
        return footer
    }

    private func makeFooterCaption(with text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 9, weight: .bold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func styleFooterValue(_ label: NSTextField, alignment: NSTextAlignment) {
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .labelColor
        label.alignment = alignment
        label.translatesAutoresizingMaskIntoConstraints = false
    }

    private func makeInputCard(
        startTimePicker: NSDatePicker,
        endTimePicker: NSDatePicker
    ) -> NSView {
        styleTimePicker(startTimePicker)
        styleTimePicker(endTimePicker)

        let startRow = makeInputRow(title: "Start Time", picker: startTimePicker)
        let endRow = makeInputRow(title: "End Time", picker: endTimePicker)
        let stack = NSStackView(views: [startRow, endRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(
            calibratedRed: 0,
            green: 0,
            blue: 0,
            alpha: 0.03
        ).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(
            calibratedRed: 0,
            green: 0,
            blue: 0,
            alpha: 0.05
        ).cgColor

        let topBorder = makeSeparator()
        let bottomBorder = makeSeparator()
        container.addSubview(topBorder)
        container.addSubview(bottomBorder)
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            topBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            topBorder.topAnchor.constraint(equalTo: container.topAnchor),
            bottomBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            startRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            endRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        return container
    }

    private func makeInputRow(title: String, picker: NSDatePicker) -> NSView {
        let titleLabel = makeMutedLabel(with: title)
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = NSColor(
            calibratedRed: 89 / 255,
            green: 89 / 255,
            blue: 102 / 255,
            alpha: 1
        )

        let pickerContainer = makeTimeFieldContainer(for: picker)
        let iconName = title == "Start Time" ? "arrow.right.to.line" : "rectangle.portrait.and.arrow.right"
        let row = NSStackView(views: [
            makeIconView(symbolName: iconName, tintColor: .secondaryLabelColor, pointSize: 15),
            titleLabel,
            NSView(),
            pickerContainer,
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pickerContainer.widthAnchor.constraint(equalToConstant: 116),
            pickerContainer.heightAnchor.constraint(equalToConstant: 50),
        ])

        return row
    }

    private func makeTimeFieldContainer(for picker: NSDatePicker) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 6
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(
            calibratedRed: 209 / 255,
            green: 209 / 255,
            blue: 209 / 255,
            alpha: 1
        ).cgColor
        container.layer?.backgroundColor = NSColor.white.cgColor

        container.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            picker.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            picker.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -20),
            picker.heightAnchor.constraint(equalToConstant: 28),
        ])

        return container
    }

    private func styleTimePicker(_ picker: NSDatePicker) {
        picker.datePickerStyle = .textField
        picker.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.controlSize = .regular
        picker.isBordered = false
        picker.isBezeled = false
        picker.drawsBackground = true
        picker.backgroundColor = .white
        picker.textColor = .labelColor
        picker.alignment = .center
    }

    private func styleSettingsButton(_ button: NSButton) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentTintColor = .secondaryLabelColor
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 28),
        ])
    }
}

final class AttendanceProgressBarView: NSView {
    private let fillView = NSView()
    private var fillWidthConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.backgroundColor = NSColor(
            calibratedRed: 229 / 255,
            green: 231 / 255,
            blue: 235 / 255,
            alpha: 1
        ).cgColor

        fillView.translatesAutoresizingMaskIntoConstraints = false
        fillView.wantsLayer = true
        fillView.layer?.cornerRadius = 4
        fillView.layer?.backgroundColor = NSColor(
            calibratedRed: 0 / 255,
            green: 122 / 255,
            blue: 255 / 255,
            alpha: 1
        ).cgColor
        addSubview(fillView)

        fillWidthConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)
        fillWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 8),
            fillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fillView.topAnchor.constraint(equalTo: topAnchor),
            fillView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setProgress(_ progress: Double) {
        layoutSubtreeIfNeeded()
        let width = max(bounds.width * progress, progress > 0 ? 8 : 0)
        fillWidthConstraint?.constant = width
        needsLayout = true
    }

    override func layout() {
        super.layout()
        fillWidthConstraint?.constant = min(fillWidthConstraint?.constant ?? 0, bounds.width)
    }
}
