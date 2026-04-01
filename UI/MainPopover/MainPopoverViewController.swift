import AppKit

struct MainPopoverViewSnapshot {
    let header: MainPopoverHeaderSectionSnapshot
    let currentSession: MainPopoverCurrentSessionSectionSnapshot
    let todayTimes: MainPopoverTodayTimesSectionSnapshot
    let summary: MainPopoverSummarySectionSnapshot
}

final class MainPopoverViewController: NSViewController {
    private var state: MainPopoverViewState
    private let copy: MainPopoverCopy
    private let timeFormatter: DateFormatter
    private var todayTimeEditModeState = TodayTimeEditModeState()
    private let currentTimeProvider: () -> Date
    private let renderModelFactory: MainPopoverRenderModelFactory
    private var currentSessionText: String
    private var currentSessionDuration: TimeInterval?
    private lazy var currentSessionRuntime = MainPopoverCurrentSessionRuntime(
        currentSessionCalculator: runtimeDependencies.currentSessionCalculator,
        currentTimeProvider: currentTimeProvider,
        currentSessionScheduler: runtimeDependencies.currentSessionScheduler,
        placeholderText: copy.currentSessionPlaceholderText,
        onChange: { [weak self] text, duration in
            self?.currentSessionText = text
            self?.currentSessionDuration = duration
            self?.render()
        }
    )
    private let runtimeDependencies: RuntimeDependencies
    var onApplyEditedTimes: ((Date?, Date?) -> Void)?

    private let headerSectionView = MainPopoverHeaderSectionView()
    private let currentSessionSectionView = MainPopoverCurrentSessionSectionView()
    private let todayTimesSectionView = MainPopoverTodayTimesSectionView()
    private let summarySectionView = MainPopoverSummarySectionView()

    init(
        state: MainPopoverViewState? = nil,
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        copy: MainPopoverCopy = .english,
        currentTimeProvider: @escaping () -> Date = Date.init,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler()
    ) {
        let resolvedState = state ?? MainPopoverViewStateFactory(copy: copy).makePlaceholder()
        self.state = resolvedState
        self.copy = copy
        self.currentSessionText = resolvedState.currentSessionText
        self.currentSessionDuration = nil
        self.currentTimeProvider = currentTimeProvider
        self.runtimeDependencies = RuntimeDependencies(
            currentSessionCalculator: currentSessionCalculator,
            currentSessionScheduler: currentSessionScheduler
        )
        let progressPolicy = MainPopoverCurrentSessionProgressPolicy()
        self.renderModelFactory = MainPopoverRenderModelFactory(
            copy: copy,
            progressPolicy: progressPolicy
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
            MainPopoverDividerView(),
            currentSessionSectionView,
            MainPopoverDividerView(),
            todayTimesSectionView,
            MainPopoverDividerView(),
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
            todayTimeEditModeState.updateDraftStartTime(todayTimesSectionView.pickerDate(for: .startTime))
        case .endTime:
            todayTimeEditModeState.updateDraftEndTime(todayTimesSectionView.pickerDate(for: .endTime))
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
        todayTimesSectionView.onEvent = { [weak self] event in
            switch event {
            case .beginEditing(.startTime):
                self?.handleStartTimeRowTap()
            case .beginEditing(.endTime):
                self?.handleEndTimeRowTap()
            case .cancelEditing:
                self?.handleCancelEditing()
            case .applyEditing:
                self?.handleApplyEditing()
            }
        }
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
            return copy.checkedInSummaryPlaceholder
        }

        return copy.checkedInSummaryText(for: timeText(for: startTime))
    }

    private func timeText(for date: Date?) -> String {
        guard let date else {
            return copy.timePlaceholderText
        }

        return timeFormatter.string(from: date)
    }

    func setPickerDate(_ date: Date, for field: TodayTimeField) {
        todayTimesSectionView.setPickerDate(date, for: field)
    }

    var snapshot: MainPopoverViewSnapshot {
        MainPopoverViewSnapshot(
            header: headerSectionView.snapshot,
            currentSession: currentSessionSectionView.snapshot,
            todayTimes: todayTimesSectionView.snapshot,
            summary: summarySectionView.snapshot
        )
    }

    private struct RuntimeDependencies {
        let currentSessionCalculator: CurrentSessionCalculator
        let currentSessionScheduler: any CurrentSessionScheduling
    }
}
