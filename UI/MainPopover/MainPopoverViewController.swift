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
    private let onChange: (String, TimeInterval?) -> Void
    private var currentSessionRefresh: (any CurrentSessionCancellable)?

    init(
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        currentTimeProvider: @escaping () -> Date = Date.init,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler(),
        onChange: @escaping (String, TimeInterval?) -> Void
    ) {
        self.currentSessionCalculator = currentSessionCalculator
        self.currentTimeProvider = currentTimeProvider
        self.currentSessionScheduler = currentSessionScheduler
        self.onChange = onChange
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

        onChange(
            duration.map { MainPopoverViewController.format(duration: $0) }
                ?? MainPopoverViewState.placeholder.currentSessionText,
            duration
        )
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
    private let currentSessionCalculator: CurrentSessionCalculator
    private let currentTimeProvider: () -> Date
    private let currentSessionScheduler: any CurrentSessionScheduling
    private let renderModelFactory: MainPopoverRenderModelFactory
    private var currentSessionText: String
    private var currentSessionDuration: TimeInterval?
    private lazy var currentSessionRuntime = MainPopoverCurrentSessionRuntime(
        currentSessionCalculator: currentSessionCalculator,
        currentTimeProvider: currentTimeProvider,
        currentSessionScheduler: currentSessionScheduler,
        onChange: { [weak self] text, duration in
            self?.currentSessionText = text
            self?.currentSessionDuration = duration
            self?.render()
        }
    )
    var onApplyEditedTimes: ((Date?, Date?) -> Void)?

    let headerSectionView = MainPopoverHeaderSectionView()
    let currentSessionSectionView = MainPopoverCurrentSessionSectionView()
    let todayTimesSectionView = MainPopoverTodayTimesSectionView()
    let summarySectionView = MainPopoverSummarySectionView()

    var dateLabel: NSTextField { headerSectionView.dateLabel }
    var checkedInSummaryLabel: NSTextField { headerSectionView.checkedInSummaryLabel }
    var currentSessionTitleLabel: NSTextField { currentSessionSectionView.titleLabel }
    var currentSessionValueLabel: NSTextField { currentSessionSectionView.valueLabel }
    var currentSessionProgressBar: CurrentSessionProgressBarView { currentSessionSectionView.progressBar }
    var currentSessionProgressLeadingLabel: NSTextField { currentSessionSectionView.leadingCaptionLabel }
    var currentSessionProgressTrailingLabel: NSTextField { currentSessionSectionView.trailingCaptionLabel }
    var startTimeTitleLabel: NSTextField { todayTimesSectionView.startRowView.titleLabel }
    var startTimeValueLabel: NSTextField { todayTimesSectionView.startRowView.valueLabel }
    var startTimePicker: NSDatePicker { todayTimesSectionView.startRowView.picker }
    var startTimeApplyButton: NSButton { todayTimesSectionView.startTimeApplyButton }
    var startTimeCancelButton: NSButton { todayTimesSectionView.startTimeCancelButton }
    var endTimeTitleLabel: NSTextField { todayTimesSectionView.endRowView.titleLabel }
    var endTimeValueLabel: NSTextField { todayTimesSectionView.endRowView.valueLabel }
    var endTimePicker: NSDatePicker { todayTimesSectionView.endRowView.picker }
    var endTimeApplyButton: NSButton { todayTimesSectionView.endTimeApplyButton }
    var endTimeCancelButton: NSButton { todayTimesSectionView.endTimeCancelButton }
    var weeklyTitleLabel: NSTextField { summarySectionView.weeklyTitleLabel }
    var weeklyValueLabel: NSTextField { summarySectionView.weeklyValueLabel }
    var monthlyTitleLabel: NSTextField { summarySectionView.monthlyTitleLabel }
    var monthlyValueLabel: NSTextField { summarySectionView.monthlyValueLabel }
    var editingActionRow: NSStackView { todayTimesSectionView.editingActionRow }
    var todayTimesBackgroundView: NSView { todayTimesSectionView.backgroundView }

    init(
        state: MainPopoverViewState = .placeholder,
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        currentTimeProvider: @escaping () -> Date = Date.init,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler()
    ) {
        self.state = state
        self.currentSessionText = state.currentSessionText
        self.currentSessionDuration = nil
        self.currentSessionCalculator = currentSessionCalculator
        self.currentTimeProvider = currentTimeProvider
        self.currentSessionScheduler = currentSessionScheduler
        self.renderModelFactory = MainPopoverRenderModelFactory(
            currentSessionGoalDuration: MainPopoverStyle.Metrics.currentSessionGoalDuration,
            maximumVisibleProgressFraction: MainPopoverStyle.Metrics.maximumVisibleProgressFraction
        )
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
        let rootView = NSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: MainPopoverStyle.Metrics.popoverSize.width,
                height: MainPopoverStyle.Metrics.popoverSize.height
            )
        )
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = MainPopoverStyle.Colors.popoverBackground.cgColor

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = MainPopoverStyle.Metrics.contentSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        [
            headerSectionView,
            Self.makeSeparator(),
            currentSessionSectionView,
            Self.makeSeparator(),
            todayTimesSectionView,
            Self.makeSeparator(),
            summarySectionView,
        ].forEach(contentStack.addArrangedSubview)

        rootView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: rootView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: rootView.bottomAnchor),
            headerSectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            currentSessionSectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            todayTimesSectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            summarySectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
        ])

        view = rootView
        configureActions()
        render()
    }

    func apply(state: MainPopoverViewState) {
        self.state = state
        currentSessionText = state.currentSessionText
        currentSessionDuration = nil
        render()
    }

    func applyCurrentSession(startTime: Date?, endTime: Date?) {
        currentSessionRuntime.apply(startTime: startTime, endTime: endTime)
    }

    func beginCurrentSessionUpdates(startTime: Date?, endTime: Date?) {
        todayTimeEditModeState.loadSavedTimes(startTime: startTime, endTime: endTime)
        currentSessionRuntime.begin(startTime: startTime, endTime: endTime)
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
        render()
    }

    func beginEditingEndTime() {
        todayTimeEditModeState.beginEditing(.endTime)
        render()
    }

    func cancelEditingTime() {
        todayTimeEditModeState.cancel()
        render()
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

        guard todayTimeEditModeState.hasValidDraftTimes else {
            render()
            return
        }

        guard let appliedTimes = todayTimeEditModeState.apply() else { return }

        state = MainPopoverViewState(
            dateText: state.dateText,
            checkedInSummaryText: checkedInSummaryText(for: appliedTimes.startTime),
            currentSessionText: currentSessionText,
            startTimeText: timeText(for: appliedTimes.startTime),
            endTimeText: timeText(for: appliedTimes.endTime),
            weeklyTotalText: state.weeklyTotalText,
            monthlyTotalText: state.monthlyTotalText
        )
        onApplyEditedTimes?(appliedTimes.startTime, appliedTimes.endTime)
        render()
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

    private func configureActions() {
        let startTapRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleStartTimeRowTap))
        todayTimesSectionView.startRowView.addGestureRecognizer(startTapRecognizer)

        let endTapRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleEndTimeRowTap))
        todayTimesSectionView.endRowView.addGestureRecognizer(endTapRecognizer)

        startTimeCancelButton.target = self
        startTimeCancelButton.action = #selector(handleCancelEditing)
        endTimeCancelButton.target = self
        endTimeCancelButton.action = #selector(handleCancelEditing)
        startTimeApplyButton.target = self
        startTimeApplyButton.action = #selector(handleApplyEditing)
        endTimeApplyButton.target = self
        endTimeApplyButton.action = #selector(handleApplyEditing)
    }

    private func render() {
        guard isViewLoaded else { return }

        let renderModel = renderModelFactory.make(
            viewState: state,
            currentSessionText: currentSessionText,
            currentSessionDuration: currentSessionDuration,
            editModeState: todayTimeEditModeState,
            fallbackTime: currentTimeProvider()
        )

        headerSectionView.apply(renderModel.header)
        currentSessionSectionView.apply(renderModel.currentSession)
        todayTimesSectionView.apply(renderModel.todayTimes)
        summarySectionView.apply(renderModel.summary)
    }

    private func checkedInSummaryText(for startTime: Date?) -> String {
        guard let startTime else {
            return MainPopoverViewState.placeholder.checkedInSummaryText
        }

        return "Checked in at \(timeText(for: startTime))"
    }

    private func timeText(for date: Date?) -> String {
        guard let date else {
            return MainPopoverViewState.placeholder.startTimeText
        }

        return timeFormatter.string(from: date)
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
