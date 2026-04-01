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
    private let currentTimeProvider: () -> Date
    private let currentSessionCalculator: CurrentSessionCalculator
    private let currentSessionScheduler: any CurrentSessionScheduling
    private let renderModelFactory: MainPopoverRenderModelFactory
    var onApplyEditedTimes: ((Date?, Date?) -> Void)?

    private let headerSectionView = MainPopoverHeaderSectionView()
    private let currentSessionSectionView = MainPopoverCurrentSessionSectionView()
    private let todayTimesSectionView = MainPopoverTodayTimesSectionView()
    private let summarySectionView = MainPopoverSummarySectionView()

    private lazy var currentSessionBinder: MainPopoverCurrentSessionBinder = {
        let binder = MainPopoverCurrentSessionBinder(
            initialText: state.currentSessionText,
            copy: copy,
            currentSessionCalculator: currentSessionCalculator,
            currentTimeProvider: currentTimeProvider,
            currentSessionScheduler: currentSessionScheduler
        )
        binder.onDidChange = { [weak self] in
            self?.render()
        }
        return binder
    }()

    private lazy var todayTimesBinder: MainPopoverTodayTimesBinder = {
        let binder = MainPopoverTodayTimesBinder(
            sectionView: todayTimesSectionView,
            copy: copy
        )
        binder.onDidChange = { [weak self] in
            self?.render()
        }
        binder.onDidApplyTimes = { [weak self] appliedTimes in
            self?.onApplyEditedTimes?(appliedTimes.startTime, appliedTimes.endTime)
        }
        return binder
    }()

    init(
        state: MainPopoverViewState,
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        copy: MainPopoverCopy = .english,
        currentTimeProvider: @escaping () -> Date,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler()
    ) {
        self.state = state
        self.copy = copy
        self.currentTimeProvider = currentTimeProvider
        self.currentSessionCalculator = currentSessionCalculator
        self.currentSessionScheduler = currentSessionScheduler
        self.renderModelFactory = MainPopoverRenderModelFactory(copy: copy)
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
        render()
    }

    func apply(state: MainPopoverViewState) {
        self.state = state
        currentSessionBinder.load(viewState: state)
        render()
    }

    func display(_ intent: MainPopoverDisplayIntent) {
        state = intent.viewState
        todayTimesBinder.loadSavedTimes(startTime: intent.startTime, endTime: intent.endTime)
        currentSessionBinder.load(viewState: intent.viewState)
        currentSessionBinder.begin(startTime: intent.startTime, endTime: intent.endTime)
        render()
    }

    func applyCurrentSession(startTime: Date?, endTime: Date?) {
        currentSessionBinder.apply(startTime: startTime, endTime: endTime)
    }

    func beginCurrentSessionUpdates(startTime: Date?, endTime: Date?) {
        todayTimesBinder.loadSavedTimes(startTime: startTime, endTime: endTime)
        currentSessionBinder.begin(startTime: startTime, endTime: endTime)
        render()
    }

    func stopCurrentSessionUpdates() {
        currentSessionBinder.stop()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        stopCurrentSessionUpdates()
    }

    func beginEditing(_ field: TodayTimeField) {
        todayTimesBinder.beginEditing(field)
    }

    func cancelEditing() {
        todayTimesBinder.cancelEditing()
    }

    func applyEditing() {
        todayTimesBinder.applyEditing()
    }

    func deleteEndTime() {
        todayTimesBinder.deleteEndTime()
    }

    func setEditingPickerDate(_ date: Date, for field: TodayTimeField) {
        let currentDraft = todayTimesSectionView.currentDraft()
        let updatedDraft: MainPopoverTodayTimesDraft

        switch field {
        case .startTime:
            updatedDraft = MainPopoverTodayTimesDraft(startTime: date, endTime: currentDraft.endTime)
        case .endTime:
            updatedDraft = MainPopoverTodayTimesDraft(startTime: currentDraft.startTime, endTime: date)
        }

        todayTimesBinder.setEditingDraft(updatedDraft)
    }

    private func render() {
        guard isViewLoaded else { return }

        let renderModel = renderModelFactory.make(
            viewState: state,
            currentSession: currentSessionBinder.makeRenderModel(),
            todayTimes: todayTimesBinder.makeRenderModel(
                viewState: state,
                fallbackTime: currentTimeProvider()
            )
        )

        headerSectionView.apply(renderModel.header)
        currentSessionSectionView.apply(renderModel.currentSession)
        todayTimesSectionView.apply(renderModel.todayTimes)
        summarySectionView.apply(renderModel.summary)
    }

    var snapshot: MainPopoverViewSnapshot {
        MainPopoverViewSnapshot(
            header: headerSectionView.snapshot,
            currentSession: currentSessionSectionView.snapshot,
            todayTimes: todayTimesSectionView.snapshot,
            summary: summarySectionView.snapshot
        )
    }
}
