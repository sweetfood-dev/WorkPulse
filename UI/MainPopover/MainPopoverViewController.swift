import AppKit

protocol CurrentSessionCancellable {
    func cancel()
}

protocol CurrentSessionScheduling {
    func scheduleRepeating(
        every interval: TimeInterval,
        action: @escaping () -> Void
    ) -> any CurrentSessionCancellable
}

final class TimerCurrentSessionCancellable: CurrentSessionCancellable {
    private weak var timer: Timer?

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
    }
}

struct TimerCurrentSessionScheduler: CurrentSessionScheduling {
    func scheduleRepeating(
        every interval: TimeInterval,
        action: @escaping () -> Void
    ) -> any CurrentSessionCancellable {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            action()
        }
        return TimerCurrentSessionCancellable(timer: timer)
    }
}

struct MainPopoverViewState {
    let dateText: String
    let checkedInSummaryText: String
    let currentSessionText: String
    let startTimeText: String
    let endTimeText: String
    let weeklyTotalText: String
    let monthlyTotalText: String

    static let placeholder = MainPopoverViewState(
        dateText: "Today",
        checkedInSummaryText: "Checked in at --:--",
        currentSessionText: "--:--:--",
        startTimeText: "--:--",
        endTimeText: "--:--",
        weeklyTotalText: "--",
        monthlyTotalText: "--"
    )
}

@MainActor
final class MainPopoverCurrentSessionRuntime {
    private let currentSessionCalculator: CurrentSessionCalculator
    private let currentTimeProvider: () -> Date
    private let currentSessionScheduler: any CurrentSessionScheduling
    private let onTextChange: (String) -> Void
    private var currentSessionRefresh: (any CurrentSessionCancellable)?

    init(
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        currentTimeProvider: @escaping () -> Date = Date.init,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler(),
        onTextChange: @escaping (String) -> Void
    ) {
        self.currentSessionCalculator = currentSessionCalculator
        self.currentTimeProvider = currentTimeProvider
        self.currentSessionScheduler = currentSessionScheduler
        self.onTextChange = onTextChange
    }

    deinit {
        currentSessionRefresh?.cancel()
    }

    func apply(startTime: Date?, endTime: Date?) {
        onTextChange(resolvedText(startTime: startTime, endTime: endTime))
    }

    func begin(startTime: Date?, endTime: Date?) {
        currentSessionRefresh?.cancel()
        currentSessionRefresh = nil

        apply(startTime: startTime, endTime: endTime)

        guard let startTime, endTime == nil else { return }

        currentSessionRefresh = currentSessionScheduler.scheduleRepeating(
            every: 1
        ) { [weak self] in
            self?.apply(startTime: startTime, endTime: nil)
        }
    }

    func stop() {
        currentSessionRefresh?.cancel()
        currentSessionRefresh = nil
    }

    private func resolvedText(startTime: Date?, endTime: Date?) -> String {
        guard let duration = currentSessionCalculator.sessionDuration(
            startTime: startTime,
            endTime: endTime,
            now: currentTimeProvider()
        ) else {
            return MainPopoverViewState.placeholder.currentSessionText
        }

        return MainPopoverViewController.format(duration: duration)
    }
}

final class MainPopoverViewController: NSViewController {
    private var state: MainPopoverViewState
    private let timeFormatter: DateFormatter
    private var todayTimeEditModeState = TodayTimeEditModeState()
    private lazy var currentSessionRuntime = MainPopoverCurrentSessionRuntime(
        currentSessionCalculator: currentSessionCalculator,
        currentTimeProvider: currentTimeProvider,
        currentSessionScheduler: currentSessionScheduler,
        onTextChange: { [weak self] text in
            self?.currentSessionValueLabel.stringValue = text
        }
    )
    private let currentSessionCalculator: CurrentSessionCalculator
    private let currentTimeProvider: () -> Date
    private let currentSessionScheduler: any CurrentSessionScheduling
    var onApplyEditedTimes: ((Date?, Date?) -> Void)?

    let dateLabel = MainPopoverViewController.makeSectionTitleLabel()
    let checkedInSummaryLabel = MainPopoverViewController.makeSecondaryLabel()
    let currentSessionTitleLabel = MainPopoverViewController.makeSectionTitleLabel()
    let currentSessionValueLabel = MainPopoverViewController.makeValueLabel()
    let startTimeTitleLabel = MainPopoverViewController.makeSectionTitleLabel()
    let startTimeValueLabel = MainPopoverViewController.makeRowValueLabel()
    let startTimePicker = MainPopoverViewController.makeTimePicker()
    let startTimeApplyButton = MainPopoverViewController.makeActionButton(title: "Apply")
    let startTimeCancelButton = MainPopoverViewController.makeActionButton(title: "Cancel")
    let endTimeTitleLabel = MainPopoverViewController.makeSectionTitleLabel()
    let endTimeValueLabel = MainPopoverViewController.makeRowValueLabel()
    let endTimePicker = MainPopoverViewController.makeTimePicker()
    let endTimeApplyButton = MainPopoverViewController.makeActionButton(title: "Apply")
    let endTimeCancelButton = MainPopoverViewController.makeActionButton(title: "Cancel")
    let weeklyTitleLabel = MainPopoverViewController.makeSectionTitleLabel()
    let weeklyValueLabel = MainPopoverViewController.makeSummaryValueLabel()
    let monthlyTitleLabel = MainPopoverViewController.makeSectionTitleLabel()
    let monthlyValueLabel = MainPopoverViewController.makeSummaryValueLabel()
    private let startTimeEditStack = NSStackView()
    private let endTimeEditStack = NSStackView()
    private let startTimeRow = NSStackView()
    private let endTimeRow = NSStackView()

    init(
        state: MainPopoverViewState = .placeholder,
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        currentTimeProvider: @escaping () -> Date = Date.init,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler()
    ) {
        self.state = state
        self.currentSessionCalculator = currentSessionCalculator
        self.currentTimeProvider = currentTimeProvider
        self.currentSessionScheduler = currentSessionScheduler
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        self.timeFormatter = formatter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 320))
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = NSStackView(views: [dateLabel, checkedInSummaryLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6

        currentSessionTitleLabel.stringValue = "Current Session"
        let currentSessionStack = NSStackView(views: [currentSessionTitleLabel, currentSessionValueLabel])
        currentSessionStack.orientation = .vertical
        currentSessionStack.alignment = .centerX
        currentSessionStack.spacing = 8

        startTimeTitleLabel.stringValue = "Start Time"
        endTimeTitleLabel.stringValue = "End Time"
        configureEditControls()
        configureTimeRow(
            startTimeRow,
            titleLabel: startTimeTitleLabel,
            valueLabel: startTimeValueLabel,
            editStack: startTimeEditStack,
            action: #selector(handleStartTimeRowTap)
        )
        configureTimeRow(
            endTimeRow,
            titleLabel: endTimeTitleLabel,
            valueLabel: endTimeValueLabel,
            editStack: endTimeEditStack,
            action: #selector(handleEndTimeRowTap)
        )
        let todayTimesStack = NSStackView(views: [startTimeRow, endTimeRow])
        todayTimesStack.orientation = .vertical
        todayTimesStack.spacing = 12

        weeklyTitleLabel.stringValue = "This Week"
        monthlyTitleLabel.stringValue = "This Month"
        let summaryStack = NSStackView(views: [
            makeSummaryColumn(titleLabel: weeklyTitleLabel, valueLabel: weeklyValueLabel),
            makeSummaryColumn(titleLabel: monthlyTitleLabel, valueLabel: monthlyValueLabel)
        ])
        summaryStack.orientation = .horizontal
        summaryStack.distribution = .fillEqually
        summaryStack.spacing = 24

        contentStack.addArrangedSubview(headerStack)
        contentStack.addArrangedSubview(Self.makeSeparator())
        contentStack.addArrangedSubview(currentSessionStack)
        contentStack.addArrangedSubview(Self.makeSeparator())
        contentStack.addArrangedSubview(todayTimesStack)
        contentStack.addArrangedSubview(Self.makeSeparator())
        contentStack.addArrangedSubview(summaryStack)

        rootView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: rootView.bottomAnchor, constant: -20)
        ])

        view = rootView
        apply(state: state)
        syncEditingUI()
    }

    func apply(state: MainPopoverViewState) {
        self.state = state

        guard isViewLoaded else { return }

        dateLabel.stringValue = state.dateText
        checkedInSummaryLabel.stringValue = state.checkedInSummaryText
        currentSessionValueLabel.stringValue = state.currentSessionText
        startTimeValueLabel.stringValue = state.startTimeText
        endTimeValueLabel.stringValue = state.endTimeText
        weeklyValueLabel.stringValue = state.weeklyTotalText
        monthlyValueLabel.stringValue = state.monthlyTotalText
    }

    func applyCurrentSession(startTime: Date?, endTime: Date?) {
        currentSessionRuntime.apply(startTime: startTime, endTime: endTime)
    }

    func beginCurrentSessionUpdates(startTime: Date?, endTime: Date?) {
        todayTimeEditModeState.loadSavedTimes(startTime: startTime, endTime: endTime)
        currentSessionRuntime.begin(startTime: startTime, endTime: endTime)
        syncEditorValues()
    }

    func stopCurrentSessionUpdates() {
        currentSessionRuntime.stop()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        stopCurrentSessionUpdates()
    }

    func beginEditingStartTime() {
        todayTimeEditModeState.beginEditing(.startTime)
        syncEditingUI()
    }

    func beginEditingEndTime() {
        todayTimeEditModeState.beginEditing(.endTime)
        syncEditingUI()
    }

    func cancelEditingTime() {
        todayTimeEditModeState.cancel()
        syncEditorValues()
        syncEditingUI()
    }

    func applyEditingTime() {
        switch todayTimeEditModeState.editingField {
        case .startTime:
            todayTimeEditModeState.updateDraftStartTime(startTimePicker.dateValue)
        case .endTime:
            todayTimeEditModeState.updateDraftEndTime(endTimePicker.dateValue)
        case nil:
            return
        }

        guard todayTimeEditModeState.hasValidDraftTimes else { return }
        guard let appliedTimes = todayTimeEditModeState.apply() else { return }

        startTimeValueLabel.stringValue = timeText(for: appliedTimes.startTime)
        endTimeValueLabel.stringValue = timeText(for: appliedTimes.endTime)
        onApplyEditedTimes?(appliedTimes.startTime, appliedTimes.endTime)
        syncEditingUI()
    }

    @objc
    private func handleStartTimeRowTap() {
        beginEditingStartTime()
    }

    @objc
    private func handleEndTimeRowTap() {
        beginEditingEndTime()
    }

    @objc
    private func handleCancelEditing() {
        cancelEditingTime()
    }

    @objc
    private func handleApplyEditing() {
        applyEditingTime()
    }

    private func configureEditControls() {
        configureEditStack(
            startTimeEditStack,
            picker: startTimePicker,
            applyButton: startTimeApplyButton,
            cancelButton: startTimeCancelButton
        )
        configureEditStack(
            endTimeEditStack,
            picker: endTimePicker,
            applyButton: endTimeApplyButton,
            cancelButton: endTimeCancelButton
        )

        startTimeCancelButton.target = self
        startTimeCancelButton.action = #selector(handleCancelEditing)
        endTimeCancelButton.target = self
        endTimeCancelButton.action = #selector(handleCancelEditing)
        startTimeApplyButton.target = self
        startTimeApplyButton.action = #selector(handleApplyEditing)
        endTimeApplyButton.target = self
        endTimeApplyButton.action = #selector(handleApplyEditing)
        startTimeApplyButton.isEnabled = true
        endTimeApplyButton.isEnabled = true
    }

    private func configureEditStack(
        _ stack: NSStackView,
        picker: NSDatePicker,
        applyButton: NSButton,
        cancelButton: NSButton
    ) {
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.addArrangedSubview(picker)
        stack.addArrangedSubview(applyButton)
        stack.addArrangedSubview(cancelButton)
        stack.isHidden = true
    }

    private func configureTimeRow(
        _ row: NSStackView,
        titleLabel: NSTextField,
        valueLabel: NSTextField,
        editStack: NSStackView,
        action: Selector
    ) {
        let trailingContainer = NSView()
        trailingContainer.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        editStack.translatesAutoresizingMaskIntoConstraints = false
        trailingContainer.addSubview(valueLabel)
        trailingContainer.addSubview(editStack)
        NSLayoutConstraint.activate([
            valueLabel.leadingAnchor.constraint(equalTo: trailingContainer.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingContainer.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: trailingContainer.centerYAnchor),
            editStack.leadingAnchor.constraint(equalTo: trailingContainer.leadingAnchor),
            editStack.trailingAnchor.constraint(equalTo: trailingContainer.trailingAnchor),
            editStack.topAnchor.constraint(equalTo: trailingContainer.topAnchor),
            editStack.bottomAnchor.constraint(equalTo: trailingContainer.bottomAnchor),
        ])

        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(trailingContainer)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        trailingContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        valueLabel.alignment = .right

        let recognizer = NSClickGestureRecognizer(target: self, action: action)
        row.addGestureRecognizer(recognizer)
    }

    private func syncEditorValues() {
        if let startTime = todayTimeEditModeState.draftStartTime {
            startTimePicker.dateValue = startTime
        } else {
            startTimePicker.dateValue = currentTimeProvider()
        }

        if let endTime = todayTimeEditModeState.draftEndTime {
            endTimePicker.dateValue = endTime
        } else {
            endTimePicker.dateValue = currentTimeProvider()
        }
    }

    private func syncEditingUI() {
        let isEditingStartTime = todayTimeEditModeState.isEditingStartTime
        let isEditingEndTime = todayTimeEditModeState.isEditingEndTime

        startTimeValueLabel.isHidden = isEditingStartTime
        startTimeEditStack.isHidden = !isEditingStartTime
        startTimePicker.isHidden = !isEditingStartTime
        startTimeApplyButton.isHidden = !isEditingStartTime
        startTimeCancelButton.isHidden = !isEditingStartTime

        endTimeValueLabel.isHidden = isEditingEndTime
        endTimeEditStack.isHidden = !isEditingEndTime
        endTimePicker.isHidden = !isEditingEndTime
        endTimeApplyButton.isHidden = !isEditingEndTime
        endTimeCancelButton.isHidden = !isEditingEndTime
    }

    private func makeSummaryColumn(titleLabel: NSTextField, valueLabel: NSTextField) -> NSView {
        let stack = NSStackView(views: [titleLabel, valueLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func timeText(for date: Date?) -> String {
        guard let date else {
            return MainPopoverViewState.placeholder.startTimeText
        }

        return timeFormatter.string(from: date)
    }

    private static func makeSectionTitleLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private static func makeSecondaryLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func makeValueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 34, weight: .regular)
        label.textColor = .labelColor
        label.alignment = .center
        return label
    }

    private static func makeRowValueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func makeTimePicker() -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerElements = [.hourMinute]
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerMode = .single
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.isHidden = true
        return picker
    }

    private static func makeActionButton(title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.isHidden = true
        return button
    }

    private static func makeSummaryValueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private static func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }

    fileprivate static func format(duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
