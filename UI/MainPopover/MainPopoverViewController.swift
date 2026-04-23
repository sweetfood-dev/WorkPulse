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
    private static let isGeometryDebugEnabled =
        ProcessInfo.processInfo.environment["WORKPULSE_DEBUG_POPOVER_GEOMETRY"] == "1"

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
    var onApplyEditedTimes: ((Date?, Date?, Bool) -> Void)?
    var onApplyEditedDetailTimes: ((MainPopoverDetailSurface, Date, Date?, Date?, Bool) -> Void)?
    var onOpenWeeklyProgress: (() -> Void)?
    var onOpenMonthlyHistory: (() -> Void)?
    var onSelectDetailDate: ((MainPopoverDetailSurface, Date) -> Void)?
    var onCopyQuitReport: (() -> Void)?

    private let headerSectionView = MainPopoverHeaderSectionView()
    private let currentSessionSectionView = MainPopoverCurrentSessionSectionView()
    private let todayTimesSectionView = MainPopoverTodayTimesSectionView()
    private let summarySectionView = MainPopoverSummarySectionView()
    private let weeklyDetailSectionView = MainPopoverWeeklyProgressSectionView()
    private let monthlyDetailContainerView = NSView()
    private let monthlyDetailBackButton = NSButton(title: "", target: nil, action: nil)
    private let monthlyHistoryViewController = MonthlyHistoryViewController()
    private let routeContainerView = NSView()
    private let mainContentView = NSView()
    private var route: MainPopoverRoute = .main
    private var activeRouteView: NSView?
    var onNavigateMonthlyHistory: ((Int) -> Void)?

    private lazy var currentSessionBinder: MainPopoverCurrentSessionBinder = {
        let binder = MainPopoverCurrentSessionBinder(
            initialText: state.currentSessionText,
            initialAttendanceState: state.attendanceState,
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
            self?.onApplyEditedTimes?(appliedTimes.startTime, appliedTimes.endTime, appliedTimes.isVacation)
        }
        return binder
    }()

    init(
        state: MainPopoverViewState,
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        copy: MainPopoverCopy = .korean,
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
        headerSectionView.onDidTapReport = { [weak self] in
            self?.onCopyQuitReport?()
        }
        weeklyDetailSectionView.onBack = { [weak self] in
            self?.showMainView()
        }
        weeklyDetailSectionView.onSelectDay = { [weak self] selectedDate in
            self?.onSelectDetailDate?(.weekly, selectedDate)
        }
        weeklyDetailSectionView.onApplyEditedDayTimes = { [weak self] date, startTime, endTime, isVacation in
            self?.onApplyEditedDetailTimes?(.weekly, date, startTime, endTime, isVacation)
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
        monthlyHistoryViewController.onApplyEditedDayTimes = { [weak self] date, startTime, endTime, isVacation in
            self?.onApplyEditedDetailTimes?(.monthly, date, startTime, endTime, isVacation)
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
        routeContainerView.frame = rootView.bounds
        routeContainerView.autoresizingMask = [.width, .height]
        rootView.addSubview(routeContainerView)
        weeklyDetailSectionView.translatesAutoresizingMaskIntoConstraints = false
        monthlyDetailContainerView.translatesAutoresizingMaskIntoConstraints = false

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
            contentStack.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: mainContentView.bottomAnchor),
            headerSectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            currentSessionSectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            todayTimesSectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            summarySectionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            monthlyDetailBackButton.topAnchor.constraint(equalTo: monthlyDetailContainerView.topAnchor, constant: LayoutMetrics.monthlyDetailTopInset),
            monthlyDetailBackButton.leadingAnchor.constraint(equalTo: monthlyDetailContainerView.leadingAnchor, constant: 20),

            monthlyDetailView.topAnchor.constraint(equalTo: monthlyDetailBackButton.bottomAnchor, constant: LayoutMetrics.monthlyDetailSpacingAfterBackButton),
            monthlyDetailView.leadingAnchor.constraint(equalTo: monthlyDetailContainerView.leadingAnchor),
            monthlyDetailView.trailingAnchor.constraint(equalTo: monthlyDetailContainerView.trailingAnchor),
            monthlyDetailView.bottomAnchor.constraint(equalTo: monthlyDetailContainerView.bottomAnchor),
        ])

        view = rootView
        installRouteView(mainContentView)
        render()
        applyPreferredPopoverSize(mainPopoverSize())
    }

    func apply(state: MainPopoverViewState) {
        self.state = state
        currentSessionBinder.load(viewState: state)
        render()
    }

    func display(_ intent: MainPopoverDisplayIntent) {
        state = intent.viewState
        todayTimesBinder.loadSavedTimes(
            startTime: intent.startTime,
            endTime: intent.endTime,
            isVacation: intent.isVacation
        )
        currentSessionBinder.load(viewState: intent.viewState)

        if intent.isVacation {
            currentSessionBinder.stop()
            currentSessionBinder.apply(
                startTime: intent.startTime,
                endTime: intent.endTime,
                isVacation: true
            )
        } else if intent.allowsLiveCurrentSessionUpdates {
            currentSessionBinder.begin(
                startTime: intent.startTime,
                endTime: intent.endTime,
                isVacation: false
            )
        } else if intent.endTime != nil {
            currentSessionBinder.stop()
            currentSessionBinder.apply(
                startTime: intent.startTime,
                endTime: intent.endTime,
                isVacation: false
            )
        } else {
            currentSessionBinder.stop()
        }

        render()
    }

    func applyCurrentSession(startTime: Date?, endTime: Date?) {
        currentSessionBinder.apply(startTime: startTime, endTime: endTime)
    }

    func beginCurrentSessionUpdates(startTime: Date?, endTime: Date?) {
        todayTimesBinder.loadSavedTimes(startTime: startTime, endTime: endTime, isVacation: false)
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
        logGeometry(reason: "showWeeklyDetail")
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
        logGeometry(reason: "showMonthlyHistory")
    }

    func showMainView() {
        route = .main
        updateRoute()
        applyPreferredPopoverSize(mainPopoverSize())
        logGeometry(reason: "showMainView")
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

    func simulateSelectWeeklyDetailStatusSegment(at index: Int) {
        weeklyDetailSectionView.simulateSelectStatusSegment(at: index)
    }

    func simulateSelectMonthlyDetailDay(at index: Int) {
        monthlyHistoryViewController.simulateSelectDay(at: index)
    }

    func simulateTapReport() {
        headerSectionView.simulateTapReport()
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

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutRouteFrames()
        logGeometry(reason: "viewDidLayout")
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
        let targetView: NSView
        switch route {
        case .main:
            targetView = mainContentView
        case .weeklyDetail:
            targetView = weeklyDetailSectionView
        case .monthlyDetail:
            targetView = monthlyDetailContainerView
        }
        installRouteView(targetView)
    }

    private func applyPreferredPopoverSize(_ size: NSSize) {
        preferredContentSize = size
        guard isViewLoaded else { return }
        if view.window == nil {
            var frame = view.frame
            frame.size = size
            view.frame = frame
        }
        layoutRouteFrames()
        view.invalidateIntrinsicContentSize()
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        logGeometry(reason: "applyPreferredPopoverSize")
    }

    private func installRouteView(_ routeView: NSView) {
        guard activeRouteView !== routeView else { return }
        activeRouteView?.removeFromSuperview()
        routeView.translatesAutoresizingMaskIntoConstraints = true
        routeView.autoresizingMask = [.width, .height]
        routeView.frame = routeContainerView.bounds
        routeContainerView.addSubview(routeView)
        activeRouteView = routeView
        layoutRouteFrames()
        logGeometry(reason: "installRouteView")
    }

    private func layoutRouteFrames() {
        guard isViewLoaded else { return }
        routeContainerView.frame = view.bounds
        activeRouteView?.frame = routeContainerView.bounds
    }

    private func weeklyDetailPopoverSize() -> NSSize {
        return NSSize(
            width: MainPopoverStyle.Metrics.popoverSize.width,
            height: max(
                MainPopoverStyle.Metrics.popoverSize.height,
                ceil(weeklyDetailSectionView.requiredHeight())
            )
        )
    }

    private func mainPopoverSize() -> NSSize {
        mainContentView.layoutSubtreeIfNeeded()
        return NSSize(
            width: MainPopoverStyle.Metrics.popoverSize.width,
            height: max(
                MainPopoverStyle.Metrics.popoverSize.height,
                ceil(mainContentView.fittingSize.height)
            )
        )
    }

    private func monthlyHistoryPopoverSize() -> NSSize {
        return NSSize(
            width: MainPopoverStyle.Metrics.popoverSize.width,
            height: max(
                MainPopoverStyle.Metrics.popoverSize.height,
                ceil(
                    LayoutMetrics.monthlyDetailTopInset
                        + monthlyDetailBackButton.fittingSize.height
                        + LayoutMetrics.monthlyDetailSpacingAfterBackButton
                        + monthlyHistoryViewController.requiredHeight()
                )
            )
        )
    }

    @objc
    private func handleMonthlyDetailBack() {
        showMainView()
    }

    private func logGeometry(reason: String) {
        guard Self.isGeometryDebugEnabled else { return }

        let routeName: String = switch route {
        case .main: "main"
        case .weeklyDetail: "weekly"
        case .monthlyDetail: "monthly"
        }

        let rootFrame = NSStringFromRect(view.frame)
        let rootBounds = NSStringFromRect(view.bounds)
        let containerFrame = NSStringFromRect(routeContainerView.frame)
        let containerBounds = NSStringFromRect(routeContainerView.bounds)
        let activeFrame = activeRouteView.map { NSStringFromRect($0.frame) } ?? "nil"
        let activeBounds = activeRouteView.map { NSStringFromRect($0.bounds) } ?? "nil"

        print(
            "[PopoverGeometry] reason=\(reason) route=\(routeName) preferred=\(preferredContentSize) rootFrame=\(rootFrame) rootBounds=\(rootBounds) containerFrame=\(containerFrame) containerBounds=\(containerBounds) activeFrame=\(activeFrame) activeBounds=\(activeBounds)"
        )
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

    var routeConstraintCountForTesting: Int {
        let routeViews = [
            mainContentView,
            weeklyDetailSectionView,
            monthlyDetailContainerView,
        ]

        return routeContainerView.constraints.filter { constraint in
            routeViews.contains { routeView in
                (constraint.firstItem as AnyObject?) === routeView
                    || (constraint.secondItem as AnyObject?) === routeView
            }
        }.count
    }
}
