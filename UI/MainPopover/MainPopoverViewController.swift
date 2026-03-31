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

final class CurrentSessionProgressBarView: NSView {
    private let trackView = NSView()
    private let fillView = NSView()
    private var fillWidthConstraint: NSLayoutConstraint?

    var progressFraction: CGFloat = 0 {
        didSet {
            needsLayout = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        fillWidthConstraint?.constant = bounds.width * max(0, min(progressFraction, 1))
    }

    private func configure() {
        wantsLayer = true

        trackView.wantsLayer = true
        trackView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        trackView.layer?.cornerRadius = 5
        trackView.translatesAutoresizingMaskIntoConstraints = false

        fillView.wantsLayer = true
        fillView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        fillView.layer?.cornerRadius = 5
        fillView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(trackView)
        addSubview(fillView)

        fillWidthConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 10),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.topAnchor.constraint(equalTo: topAnchor),
            trackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fillView.topAnchor.constraint(equalTo: topAnchor),
            fillView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fillWidthConstraint!,
        ])
    }
}

@MainActor
final class MainPopoverCurrentSessionRuntime {
    private let currentSessionCalculator: CurrentSessionCalculator
    private let currentTimeProvider: () -> Date
    private let currentSessionScheduler: any CurrentSessionScheduling
    private let onTextChange: (String) -> Void
    private let onDurationChange: (TimeInterval?) -> Void
    private var currentSessionRefresh: (any CurrentSessionCancellable)?

    init(
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        currentTimeProvider: @escaping () -> Date = Date.init,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler(),
        onTextChange: @escaping (String) -> Void,
        onDurationChange: @escaping (TimeInterval?) -> Void = { _ in }
    ) {
        self.currentSessionCalculator = currentSessionCalculator
        self.currentTimeProvider = currentTimeProvider
        self.currentSessionScheduler = currentSessionScheduler
        self.onTextChange = onTextChange
        self.onDurationChange = onDurationChange
    }

    deinit {
        currentSessionRefresh?.cancel()
    }

    func apply(startTime: Date?, endTime: Date?) {
        let duration = currentSessionCalculator.sessionDuration(
            startTime: startTime,
            endTime: endTime,
            now: currentTimeProvider()
        )

        onTextChange(
            duration.map { MainPopoverViewController.format(duration: $0) }
                ?? MainPopoverViewState.placeholder.currentSessionText
        )
        onDurationChange(duration)
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
}

final class MainPopoverViewController: NSViewController {
    private var state: MainPopoverViewState
    private let timeFormatter: DateFormatter
    private var todayTimeEditModeState = TodayTimeEditModeState()
    private let currentSessionGoalDuration: TimeInterval = 8 * 60 * 60
    private lazy var currentSessionRuntime = MainPopoverCurrentSessionRuntime(
        currentSessionCalculator: currentSessionCalculator,
        currentTimeProvider: currentTimeProvider,
        currentSessionScheduler: currentSessionScheduler,
        onTextChange: { [weak self] text in
            self?.currentSessionValueLabel.stringValue = text
        },
        onDurationChange: { [weak self] duration in
            self?.applyCurrentSessionProgress(duration: duration)
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
    let currentSessionProgressBar = CurrentSessionProgressBarView()
    let currentSessionProgressLeadingLabel = MainPopoverViewController.makeProgressCaptionLabel(alignment: .left)
    let currentSessionProgressTrailingLabel = MainPopoverViewController.makeProgressCaptionLabel(alignment: .right)
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
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 460))
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = makeHeaderSection()

        currentSessionTitleLabel.stringValue = "Current Session"
        currentSessionProgressLeadingLabel.stringValue = "0H"
        currentSessionProgressTrailingLabel.stringValue = "Goal: 8h"
        let currentSessionStack = makeCurrentSessionSection()

        startTimeTitleLabel.stringValue = "Start Time"
        endTimeTitleLabel.stringValue = "End Time"
        configureEditControls()
        configureTimeRow(
            startTimeRow,
            titleLabel: startTimeTitleLabel,
            valueLabel: startTimeValueLabel,
            editStack: startTimeEditStack,
            iconSystemName: "arrow.right.to.line",
            action: #selector(handleStartTimeRowTap)
        )
        configureTimeRow(
            endTimeRow,
            titleLabel: endTimeTitleLabel,
            valueLabel: endTimeValueLabel,
            editStack: endTimeEditStack,
            iconSystemName: "rectangle.portrait.and.arrow.right",
            action: #selector(handleEndTimeRowTap)
        )
        let todayTimesStack = makeTodayTimesSection()

        weeklyTitleLabel.stringValue = "This Week"
        monthlyTitleLabel.stringValue = "This Month"
        let summaryStack = makeSummarySection()

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
        let buttonRow = NSStackView(views: [cancelButton, applyButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 6
        buttonRow.distribution = .fillEqually

        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = 6
        stack.addArrangedSubview(picker)
        stack.addArrangedSubview(buttonRow)
        stack.isHidden = true
    }

    private func configureTimeRow(
        _ row: NSStackView,
        titleLabel: NSTextField,
        valueLabel: NSTextField,
        editStack: NSStackView,
        iconSystemName: String,
        action: Selector
    ) {
        let iconView = Self.makeSymbolImageView(systemName: iconSystemName)
        let trailingContainer = NSView()
        let valuePill = MainPopoverViewController.makeValuePillContainer()
        trailingContainer.translatesAutoresizingMaskIntoConstraints = false
        valuePill.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        editStack.translatesAutoresizingMaskIntoConstraints = false
        trailingContainer.addSubview(valuePill)
        valuePill.addSubview(valueLabel)
        trailingContainer.addSubview(editStack)
        NSLayoutConstraint.activate([
            valuePill.leadingAnchor.constraint(equalTo: trailingContainer.leadingAnchor),
            valuePill.trailingAnchor.constraint(equalTo: trailingContainer.trailingAnchor),
            valuePill.topAnchor.constraint(equalTo: trailingContainer.topAnchor),
            valuePill.bottomAnchor.constraint(equalTo: trailingContainer.bottomAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: valuePill.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: valuePill.trailingAnchor, constant: -12),
            valueLabel.centerYAnchor.constraint(equalTo: valuePill.centerYAnchor),
            editStack.leadingAnchor.constraint(equalTo: trailingContainer.leadingAnchor),
            editStack.trailingAnchor.constraint(equalTo: trailingContainer.trailingAnchor),
            editStack.topAnchor.constraint(equalTo: trailingContainer.topAnchor),
            editStack.bottomAnchor.constraint(equalTo: trailingContainer.bottomAnchor),
        ])

        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 14
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(trailingContainer)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        trailingContainer.widthAnchor.constraint(equalToConstant: 122).isActive = true
        valuePill.heightAnchor.constraint(equalToConstant: 44).isActive = true
        valueLabel.alignment = .center

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

    private func applyCurrentSessionProgress(duration: TimeInterval?) {
        let clampedFraction: CGFloat
        if let duration {
            clampedFraction = max(0, min(CGFloat(duration / currentSessionGoalDuration), 1))
        } else {
            clampedFraction = 0
        }
        currentSessionProgressBar.progressFraction = clampedFraction
    }

    private func makeHeaderSection() -> NSView {
        let calendarImageView = Self.makeSymbolImageView(systemName: "calendar")
        let settingsImageView = Self.makeSymbolImageView(systemName: "gearshape")
        dateLabel.font = .systemFont(ofSize: 16, weight: .bold)
        checkedInSummaryLabel.textColor = .secondaryLabelColor

        let dateRow = NSStackView(views: [calendarImageView, dateLabel, NSView(), settingsImageView])
        dateRow.orientation = .horizontal
        dateRow.alignment = .centerY
        dateRow.spacing = 10

        let checkInRow = NSStackView(views: [
            Self.makeTintedSymbolImageView(systemName: "arrow.right.to.line", color: .systemGreen),
            checkedInSummaryLabel,
            NSView()
        ])
        checkInRow.orientation = .horizontal
        checkInRow.alignment = .centerY
        checkInRow.spacing = 8

        let stack = Self.makeSectionStack(edgeInsets: NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20))
        stack.spacing = 10
        stack.addArrangedSubview(dateRow)
        stack.addArrangedSubview(checkInRow)
        return stack
    }

    private func makeCurrentSessionSection() -> NSView {
        let titleRow = NSStackView(views: [
            Self.makeTintedSymbolImageView(systemName: "hourglass", color: .systemBlue),
            currentSessionTitleLabel
        ])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8

        currentSessionTitleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        currentSessionTitleLabel.textColor = .secondaryLabelColor
        currentSessionValueLabel.textColor = .systemBlue

        let progressCaptionRow = NSStackView(views: [
            currentSessionProgressLeadingLabel,
            NSView(),
            currentSessionProgressTrailingLabel
        ])
        progressCaptionRow.orientation = .horizontal
        progressCaptionRow.alignment = .centerY
        progressCaptionRow.spacing = 8

        let stack = Self.makeSectionStack(edgeInsets: NSEdgeInsets(top: 24, left: 20, bottom: 24, right: 20))
        stack.alignment = .centerX
        stack.spacing = 14
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(currentSessionValueLabel)
        stack.addArrangedSubview(currentSessionProgressBar)
        stack.addArrangedSubview(progressCaptionRow)

        NSLayoutConstraint.activate([
            currentSessionProgressBar.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        return stack
    }

    private func makeTodayTimesSection() -> NSView {
        let backgroundView = NSView()
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor(
            calibratedWhite: 0.97,
            alpha: 1
        ).cgColor
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [startTimeRow, endTimeRow])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -16),
        ])

        let section = Self.makeSectionStack(edgeInsets: NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20))
        section.addArrangedSubview(backgroundView)
        return section
    }

    private func makeSummarySection() -> NSView {
        let weeklyStack = makeSummaryColumn(
            icon: Self.makeSymbolImageView(systemName: "calendar"),
            titleLabel: weeklyTitleLabel,
            valueLabel: weeklyValueLabel,
            alignment: .left
        )
        let monthlyStack = makeSummaryColumn(
            icon: Self.makeSymbolImageView(systemName: "chart.bar"),
            titleLabel: monthlyTitleLabel,
            valueLabel: monthlyValueLabel,
            alignment: .right
        )

        let row = NSStackView(views: [weeklyStack, NSView(), monthlyStack])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12

        let section = Self.makeSectionStack(edgeInsets: NSEdgeInsets(top: 16, left: 20, bottom: 18, right: 20))
        section.addArrangedSubview(row)
        return section
    }

    private func makeSummaryColumn(
        icon: NSImageView,
        titleLabel: NSTextField,
        valueLabel: NSTextField,
        alignment: NSTextAlignment
    ) -> NSView {
        titleLabel.alignment = alignment
        valueLabel.alignment = alignment

        let titleRow = NSStackView(views: [icon, titleLabel])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8

        if alignment == .right {
            titleRow.insertArrangedSubview(NSView(), at: 0)
        }

        let stack = NSStackView(views: [titleRow, valueLabel])
        stack.orientation = .vertical
        stack.alignment = alignment == .right ? .trailing : .leading
        stack.spacing = 8
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
        label.font = .monospacedDigitSystemFont(ofSize: 40, weight: .regular)
        label.textColor = .systemBlue
        label.alignment = .center
        return label
    }

    private static func makeRowValueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private static func makeTimePicker() -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerElements = [.hourMinute]
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerMode = .single
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.isHidden = true
        picker.controlSize = .regular
        picker.alignment = .center
        return picker
    }

    private static func makeActionButton(title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.isHidden = true
        return button
    }

    private static func makeSummaryValueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .labelColor
        return label
    }

    private static func makeProgressCaptionLabel(alignment: NSTextAlignment) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = alignment
        return label
    }

    private static func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }

    private static func makeSectionStack(edgeInsets: NSEdgeInsets) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = edgeInsets
        return stack
    }

    private static func makeSymbolImageView(systemName: String) -> NSImageView {
        let imageView = NSImageView()
        imageView.image = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: nil
        )
        imageView.contentTintColor = .secondaryLabelColor
        return imageView
    }

    private static func makeTintedSymbolImageView(systemName: String, color: NSColor) -> NSImageView {
        let imageView = makeSymbolImageView(systemName: systemName)
        imageView.contentTintColor = color
        return imageView
    }

    private static func makeValuePillContainer() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        view.layer?.borderColor = NSColor.separatorColor.cgColor
        view.layer?.borderWidth = 1
        view.layer?.cornerRadius = 12
        return view
    }

    fileprivate static func format(duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
