import AppKit

struct MainPopoverViewSnapshot {
    let header: MainPopoverHeaderSectionSnapshot
    let currentSession: MainPopoverCurrentSessionSectionSnapshot
    let todayTimes: MainPopoverTodayTimesSectionSnapshot
    let summary: MainPopoverSummarySectionSnapshot
    let weeklyDetail: MainPopoverWeeklyProgressSectionSnapshot
    let monthlyDetail: MonthlyHistoryViewControllerSnapshot
    let isShowingWeeklyDetail: Bool
    let isShowingMonthlyDetail: Bool
}

private enum MainPopoverRoute {
    case main
    case weeklyDetail
    case monthlyDetail
}

final class MainPopoverViewController: NSViewController {
    private enum LayoutMetrics {
        static let monthlyDetailTopInset: CGFloat = 18
        static let monthlyDetailSpacingAfterBackButton: CGFloat = 12
    }

    private var state: MainPopoverViewState
    private let copy: MainPopoverCopy
    private let currentTimeProvider: () -> Date
    private let currentSessionCalculator: CurrentSessionCalculator
    private let currentSessionScheduler: any CurrentSessionScheduling
    private let renderModelFactory: MainPopoverRenderModelFactory
    var onApplyEditedTimes: ((Date?, Date?) -> Void)?
    var onApplyEditedDetailTimes: ((MainPopoverDetailSurface, Date, Date?, Date?) -> Void)?
    var onOpenWeeklyProgress: (() -> Void)?
    var onOpenMonthlyHistory: (() -> Void)?
    var onSelectDetailDate: ((MainPopoverDetailSurface, Date) -> Void)?

    private let headerSectionView = MainPopoverHeaderSectionView()
    private let currentSessionSectionView = MainPopoverCurrentSessionSectionView()
    private let todayTimesSectionView = MainPopoverTodayTimesSectionView()
    private let summarySectionView = MainPopoverSummarySectionView()
    private let weeklyDetailSectionView = MainPopoverWeeklyProgressSectionView()
    private let monthlyDetailContainerView = NSView()
    private let monthlyDetailBackButton = NSButton(title: "", target: nil, action: nil)
    private let monthlyHistoryViewController = MonthlyHistoryViewController()
    private let mainContentView = NSView()
    private var route: MainPopoverRoute = .main
    var onNavigateMonthlyHistory: ((Int) -> Void)?

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
        summarySectionView.onSelect = { [weak self] selection in
            switch selection {
            case .weekly:
                self?.onOpenWeeklyProgress?()
            case .monthly:
                self?.onOpenMonthlyHistory?()
            }
        }
        weeklyDetailSectionView.onBack = { [weak self] in
            self?.showMainView()
        }
        weeklyDetailSectionView.onSelectDay = { [weak self] selectedDate in
            self?.onSelectDetailDate?(.weekly, selectedDate)
        }
        weeklyDetailSectionView.onApplyEditedDayTimes = { [weak self] date, startTime, endTime in
            self?.onApplyEditedDetailTimes?(.weekly, date, startTime, endTime)
        }
        monthlyHistoryViewController.onNavigatePrevious = { [weak self] in
            self?.onNavigateMonthlyHistory?(-1)
        }
        monthlyHistoryViewController.onNavigateNext = { [weak self] in
            self?.onNavigateMonthlyHistory?(1)
        }
        monthlyHistoryViewController.onSelectDay = { [weak self] selectedDate in
            self?.onSelectDetailDate?(.monthly, selectedDate)
        }
        monthlyHistoryViewController.onApplyEditedDayTimes = { [weak self] date, startTime, endTime in
            self?.onApplyEditedDetailTimes?(.monthly, date, startTime, endTime)
        }
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
        preferredContentSize = MainPopoverStyle.Metrics.popoverSize

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

        mainContentView.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(contentStack)
        rootView.addSubview(mainContentView)
        rootView.addSubview(weeklyDetailSectionView)
        rootView.addSubview(monthlyDetailContainerView)
        weeklyDetailSectionView.translatesAutoresizingMaskIntoConstraints = false
        weeklyDetailSectionView.isHidden = true
        monthlyDetailContainerView.translatesAutoresizingMaskIntoConstraints = false
        monthlyDetailContainerView.isHidden = true

        monthlyDetailBackButton.title = copy.backActionTitle
        monthlyDetailBackButton.bezelStyle = .rounded
        monthlyDetailBackButton.target = self
        monthlyDetailBackButton.action = #selector(handleMonthlyDetailBack)
        monthlyDetailBackButton.font = .systemFont(ofSize: 11, weight: .semibold)
        monthlyDetailBackButton.translatesAutoresizingMaskIntoConstraints = false

        addChild(monthlyHistoryViewController)
        let monthlyDetailView = monthlyHistoryViewController.view
        monthlyDetailView.translatesAutoresizingMaskIntoConstraints = false
        monthlyDetailContainerView.addSubview(monthlyDetailBackButton)
        monthlyDetailContainerView.addSubview(monthlyDetailView)

        NSLayoutConstraint.activate([
            mainContentView.topAnchor.constraint(equalTo: rootView.topAnchor),
            mainContentView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            mainContentView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            mainContentView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: mainContentView.bottomAnchor),
            headerSectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            currentSessionSectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            todayTimesSectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            summarySectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            weeklyDetailSectionView.topAnchor.constraint(equalTo: rootView.topAnchor),
            weeklyDetailSectionView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            weeklyDetailSectionView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            weeklyDetailSectionView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            monthlyDetailContainerView.topAnchor.constraint(equalTo: rootView.topAnchor),
            monthlyDetailContainerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            monthlyDetailContainerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            monthlyDetailContainerView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            monthlyDetailBackButton.topAnchor.constraint(equalTo: monthlyDetailContainerView.topAnchor, constant: LayoutMetrics.monthlyDetailTopInset),
            monthlyDetailBackButton.leadingAnchor.constraint(equalTo: monthlyDetailContainerView.leadingAnchor, constant: 20),

            monthlyDetailView.topAnchor.constraint(equalTo: monthlyDetailBackButton.bottomAnchor, constant: LayoutMetrics.monthlyDetailSpacingAfterBackButton),
            monthlyDetailView.leadingAnchor.constraint(equalTo: monthlyDetailContainerView.leadingAnchor),
            monthlyDetailView.trailingAnchor.constraint(equalTo: monthlyDetailContainerView.trailingAnchor),
            monthlyDetailView.bottomAnchor.constraint(equalTo: monthlyDetailContainerView.bottomAnchor),
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

        if intent.allowsLiveCurrentSessionUpdates {
            currentSessionBinder.begin(startTime: intent.startTime, endTime: intent.endTime)
        } else if intent.endTime != nil {
            currentSessionBinder.stop()
            currentSessionBinder.apply(startTime: intent.startTime, endTime: intent.endTime)
        } else {
            currentSessionBinder.stop()
        }

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

    func showWeeklyDetail(
        _ state: MainPopoverWeeklyProgressViewState,
        editorState: MainPopoverDetailDayEditingState? = nil
    ) {
        route = .weeklyDetail
        updateRoute()
        weeklyDetailSectionView.apply(state, editorState: editorState)
        weeklyDetailSectionView.layoutSubtreeIfNeeded()
        applyPreferredPopoverSize(weeklyDetailPopoverSize())
    }

    func showMonthlyHistory(
        _ state: MonthlyHistoryViewState,
        editorState: MainPopoverDetailDayEditingState? = nil
    ) {
        route = .monthlyDetail
        updateRoute()
        monthlyHistoryViewController.apply(state, editorState: editorState)
        monthlyHistoryViewController.view.layoutSubtreeIfNeeded()
        applyPreferredPopoverSize(monthlyHistoryPopoverSize())
    }

    func showMainView() {
        route = .main
        updateRoute()
        applyPreferredPopoverSize(MainPopoverStyle.Metrics.popoverSize)
    }

    func simulateMonthlyNavigatePrevious() {
        monthlyHistoryViewController.simulateNavigatePrevious()
    }

    func simulateMonthlyNavigateNext() {
        monthlyHistoryViewController.simulateNavigateNext()
    }

    func simulateSelectWeeklyDetailDay(at index: Int) {
        weeklyDetailSectionView.simulateSelectDay(at: index)
    }

    func simulateSelectMonthlyDetailDay(at index: Int) {
        monthlyHistoryViewController.simulateSelectDay(at: index)
    }

    func beginEditingSelectedDetailDay(_ field: TodayTimeField) {
        switch route {
        case .weeklyDetail:
            weeklyDetailSectionView.beginEditingSelectedDay(field)
        case .monthlyDetail:
            monthlyHistoryViewController.beginEditingSelectedDay(field)
        case .main:
            return
        }
    }

    func setSelectedDetailPickerDate(_ date: Date, for field: TodayTimeField) {
        switch route {
        case .weeklyDetail:
            weeklyDetailSectionView.setEditingPickerDate(date, for: field)
        case .monthlyDetail:
            monthlyHistoryViewController.setEditingPickerDate(date, for: field)
        case .main:
            return
        }
    }

    func applySelectedDetailEditing() {
        switch route {
        case .weeklyDetail:
            weeklyDetailSectionView.applyEditingSelectedDay()
        case .monthlyDetail:
            monthlyHistoryViewController.applyEditingSelectedDay()
        case .main:
            return
        }
    }

    var isShowingWeeklyDetail: Bool {
        route == .weeklyDetail
    }

    var isShowingMonthlyDetail: Bool {
        route == .monthlyDetail
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
                displayState: MainPopoverTodayTimesDisplayState(
                    startTimeText: state.startTimeText,
                    endTimeText: state.endTimeText
                ),
                fallbackStartTime: currentTimeProvider(),
                fallbackEndTime: currentTimeProvider()
            )
        )

        headerSectionView.apply(renderModel.header)
        currentSessionSectionView.apply(renderModel.currentSession)
        todayTimesSectionView.apply(renderModel.todayTimes)
        summarySectionView.apply(renderModel.summary)
    }

    private func updateRoute() {
        guard isViewLoaded else { return }
        mainContentView.isHidden = route != .main
        weeklyDetailSectionView.isHidden = route != .weeklyDetail
        monthlyDetailContainerView.isHidden = route != .monthlyDetail
    }

    private func applyPreferredPopoverSize(_ size: NSSize) {
        preferredContentSize = size
        guard isViewLoaded else { return }
        view.frame = NSRect(origin: .zero, size: size)
        view.bounds = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
    }

    private func weeklyDetailPopoverSize() -> NSSize {
        return NSSize(
            width: MainPopoverStyle.Metrics.popoverSize.width,
            height: max(
                MainPopoverStyle.Metrics.popoverSize.height,
                ceil(weeklyDetailSectionView.fittingSize.height)
            )
        )
    }

    private func monthlyHistoryPopoverSize() -> NSSize {
        monthlyDetailContainerView.layoutSubtreeIfNeeded()
        return NSSize(
            width: MainPopoverStyle.Metrics.popoverSize.width,
            height: max(
                MainPopoverStyle.Metrics.popoverSize.height,
                ceil(monthlyDetailContainerView.fittingSize.height)
            )
        )
    }

    @objc
    private func handleMonthlyDetailBack() {
        showMainView()
    }

    var snapshot: MainPopoverViewSnapshot {
        MainPopoverViewSnapshot(
            header: headerSectionView.snapshot,
            currentSession: currentSessionSectionView.snapshot,
            todayTimes: todayTimesSectionView.snapshot,
            summary: summarySectionView.snapshot,
            weeklyDetail: weeklyDetailSectionView.snapshot,
            monthlyDetail: monthlyHistoryViewController.snapshot,
            isShowingWeeklyDetail: isShowingWeeklyDetail,
            isShowingMonthlyDetail: isShowingMonthlyDetail
        )
    }
}
