import AppKit

struct MainPopoverWeeklyProgressSectionSnapshot {
    let titleText: String
    let weekText: String
    let statusText: String
    let todayDeltaText: String
    let todayDeltaVisualState: MainPopoverWeeklyProgressDeltaVisualState
    let progressFraction: CGFloat
    let selectedStatusSegment: Int
    let dayCount: Int
    let overtimeDayCount: Int
    let dayDetailTexts: [String]
    let dayValueTexts: [String]
    let annotationTexts: [String]
    let isShowingBackButton: Bool
    let isWarningState: Bool
    let isShowingEditor: Bool
    let editorDateText: String
}

private enum MainPopoverWeeklyProgressStatusSegment: Int {
    case progress = 0
    case quitTime = 1
}

private final class MainPopoverWeeklyProgressDayRowView: NSView {
    private let dayLabel = NSTextField(labelWithString: "")
    private let timeRangeLabel = NSTextField(labelWithString: "")
    private let workedLabel = NSTextField(labelWithString: "")
    private let annotationLabel = NSTextField(labelWithString: "")
    private let progressBar = CurrentSessionProgressBarView()
    private let row = NSStackView()
    private let contentStack = NSStackView()
    private var selectedDate: Date?
    private var isSelectable = false
    private var isOvertime = false
    private var isVacation = false
    private var currentState: MainPopoverWeeklyProgressDayViewState?
    private var displayMode: MainPopoverWeeklyProgressStatusSegment = .progress
    var onSelect: ((Date) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        dayLabel.font = MainPopoverStyle.Typography.sectionTitle
        dayLabel.textColor = MainPopoverStyle.Colors.primaryText

        timeRangeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        timeRangeLabel.textColor = MainPopoverStyle.Colors.secondaryText
        timeRangeLabel.lineBreakMode = .byTruncatingTail

        workedLabel.font = MainPopoverStyle.Typography.progressCaption
        workedLabel.textColor = MainPopoverStyle.Colors.secondaryText
        workedLabel.alignment = .right

        annotationLabel.font = .systemFont(ofSize: 10, weight: .medium)
        annotationLabel.lineBreakMode = .byTruncatingTail

        progressBar.preferredHeight = 8
        progressBar.applyVisualState(.normal)
        progressBar.applyTrackStyle(
            backgroundColor: MainPopoverStyle.Colors.weeklyProgressTrackBackground,
            borderColor: MainPopoverStyle.Colors.weeklyProgressTrackBorder,
            borderWidth: 0
        )

        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(dayLabel)
        row.addArrangedSubview(timeRangeLabel)
        row.addArrangedSubview(progressBar)
        row.addArrangedSubview(workedLabel)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 4
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(row)
        contentStack.addArrangedSubview(annotationLabel)

        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            dayLabel.widthAnchor.constraint(equalToConstant: 44),
            timeRangeLabel.widthAnchor.constraint(equalToConstant: 86),
            progressBar.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            workedLabel.widthAnchor.constraint(equalToConstant: 46),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: MainPopoverWeeklyProgressDayViewState) {
        currentState = state
        selectedDate = state.date
        isSelectable = state.isSelectable
        dayLabel.stringValue = state.dayText
        annotationLabel.stringValue = state.annotationText ?? ""
        annotationLabel.isHidden = state.annotationText == nil
        progressBar.progressFraction = state.progressFraction
        isOvertime = state.isOvertime
        isVacation = state.isVacation
        progressBar.applyVisualState(state.isOvertime ? .warning : .normal)

        let accentColor = state.isVacation
            ? MainPopoverStyle.Colors.vacationAccent
            : state.isOvertime
            ? MainPopoverStyle.Colors.detailOvertimeAccent
            : accentColor(for: state.dayCategory)
        dayLabel.font = .systemFont(
            ofSize: 13,
            weight: state.isToday ? .bold : .semibold
        )
        dayLabel.textColor = accentColor
            ?? (state.isToday ? MainPopoverStyle.Colors.currentSessionValue : MainPopoverStyle.Colors.primaryText)
        timeRangeLabel.textColor = accentColor?.withAlphaComponent(0.8)
            ?? MainPopoverStyle.Colors.secondaryText
        workedLabel.textColor = accentColor?.withAlphaComponent(0.95)
            ?? MainPopoverStyle.Colors.secondaryText
        annotationLabel.textColor = accentColor?.withAlphaComponent(0.9)
            ?? MainPopoverStyle.Colors.secondaryText
        updateDisplayedTexts()
    }

    func setDisplayMode(_ mode: MainPopoverWeeklyProgressStatusSegment) {
        displayMode = mode
        updateDisplayedTexts()
    }

    override func mouseDown(with event: NSEvent) {
        guard isSelectable, let selectedDate else {
            super.mouseDown(with: event)
            return
        }

        onSelect?(selectedDate)
    }

    func simulateSelect() {
        guard isSelectable, let selectedDate else { return }
        onSelect?(selectedDate)
    }

    private func accentColor(for category: CalendarDayCategory) -> NSColor? {
        switch category {
        case .weekday:
            return nil
        case .weekend:
            return MainPopoverStyle.Colors.weekendAccent
        case .holiday:
            return MainPopoverStyle.Colors.holidayAccent
        case .substituteHoliday:
            return MainPopoverStyle.Colors.substituteHolidayAccent
        }
    }

    var annotationText: String {
        annotationLabel.stringValue
    }

    var detailText: String {
        timeRangeLabel.stringValue
    }

    var valueText: String {
        workedLabel.stringValue
    }

    var isOvertimeState: Bool {
        isOvertime
    }

    private func updateDisplayedTexts() {
        guard let currentState else { return }

        timeRangeLabel.stringValue = currentState.timeRangeText

        switch displayMode {
        case .progress:
            workedLabel.stringValue = currentState.workedText
        case .quitTime:
            workedLabel.stringValue = currentState.quitDeltaText
        }
    }
}

@MainActor
final class MainPopoverWeeklyProgressSectionView: NSView {
    private static let isGeometryDebugEnabled =
        ProcessInfo.processInfo.environment["WORKPULSE_DEBUG_POPOVER_GEOMETRY"] == "1"

    private enum LayoutMetrics {
        static let topInset: CGFloat = 18
        static let backToSegmentSpacing: CGFloat = 10
        static let segmentToCardSpacing: CGFloat = 10
        static let cardToRowsSpacing: CGFloat = 14
        static let bottomInset: CGFloat = 20
        static let cardPadding: CGFloat = 18
        static let cardContentSpacing: CGFloat = 14
        static let statusVerticalPadding: CGFloat = 8
    }

    var onBack: (() -> Void)?
    var onSelectDay: ((Date) -> Void)?
    var onApplyEditedDayTimes: ((Date, Date?, Date?, Bool) -> Void)?
    private let copy: MainPopoverCopy

    private let backButton = NSButton(title: "", target: nil, action: nil)
    private let cardView = NSView()
    private let titleIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let weekLabel = NSTextField(labelWithString: "")
    private let statusIconView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let todayDeltaLabel = NSTextField(labelWithString: "")
    private let progressBar = CurrentSessionProgressBarView()
    private let statusSegmentedControl = NSSegmentedControl()
    private let headerRow = NSStackView()
    private let titleRow = NSStackView()
    private let statusContainer = NSView()
    private let statusRow = NSStackView()
    private let rowsStack = NSStackView()
    private let detailEditorView = MainPopoverDetailDayEditorView()

    private var isWarningState = false
    private var rowViews: [MainPopoverWeeklyProgressDayRowView] = []
    private var detailEditorTopConstraint: NSLayoutConstraint?
    private var detailEditorBottomConstraint: NSLayoutConstraint?
    private var rowsBottomConstraint: NSLayoutConstraint?
    private var cardHeightConstraint: NSLayoutConstraint?
    private var isEditorVisible = false
    private var currentState: MainPopoverWeeklyProgressViewState?

    init(copy: MainPopoverCopy = .korean) {
        self.copy = copy
        super.init(frame: .zero)
        backButton.title = copy.backActionTitle
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        _ state: MainPopoverWeeklyProgressViewState,
        editorState: MainPopoverDetailDayEditingState? = nil
    ) {
        currentState = state
        titleLabel.stringValue = state.titleText
        weekLabel.stringValue = state.weekText
        progressBar.progressFraction = state.progressFraction
        applyVisualState(state.visualState)
        updateSelectedStatusPresentation()
        syncRows(count: state.days.count)

        zip(rowViews, state.days).forEach { row, day in
            row.onSelect = { [weak self] selectedDate in
                self?.onSelectDay?(selectedDate)
            }
            row.apply(day)
        }
        updateSelectedStatusPresentation()
        detailEditorView.apply(editorState)
        applyEditorLayout(isVisible: editorState != nil)
        updateCardHeight()
        logGeometry(reason: "apply")
    }

    var snapshot: MainPopoverWeeklyProgressSectionSnapshot {
        MainPopoverWeeklyProgressSectionSnapshot(
            titleText: titleLabel.stringValue,
            weekText: weekLabel.stringValue,
            statusText: statusLabel.stringValue,
            todayDeltaText: todayDeltaLabel.stringValue,
            todayDeltaVisualState: currentState?.todayDeltaVisualState ?? .neutral,
            progressFraction: progressBar.progressFraction,
            selectedStatusSegment: statusSegmentedControl.selectedSegment,
            dayCount: rowViews.count,
            overtimeDayCount: rowViews.filter(\.isOvertimeState).count,
            dayDetailTexts: rowViews.map(\.detailText),
            dayValueTexts: rowViews.map(\.valueText),
            annotationTexts: rowViews.map(\.annotationText).filter { $0.isEmpty == false },
            isShowingBackButton: backButton.isHidden == false,
            isWarningState: isWarningState,
            isShowingEditor: isEditorVisible,
            editorDateText: detailEditorView.snapshot.dateText
        )
    }

    func simulateSelectDay(at index: Int) {
        guard rowViews.indices.contains(index) else { return }
        rowViews[index].simulateSelect()
    }

    func simulateSelectStatusSegment(at index: Int) {
        guard (0..<statusSegmentedControl.segmentCount).contains(index) else { return }
        statusSegmentedControl.selectedSegment = index
        updateSelectedStatusPresentation()
    }

    func beginEditingSelectedDay(_ field: TodayTimeField) {
        detailEditorView.beginEditing(field)
    }

    func setEditingPickerDate(_ date: Date, for field: TodayTimeField) {
        detailEditorView.setEditingPickerDate(date, for: field)
    }

    func applyEditingSelectedDay() {
        detailEditorView.applyEditing()
    }

    func requiredHeight() -> CGFloat {
        layoutSubtreeIfNeeded()

        let editorHeight: CGFloat
        if isEditorVisible {
            editorHeight = (detailEditorTopConstraint?.constant ?? 0)
                + ceil(detailEditorView.fittingSize.height)
        } else {
            editorHeight = 0
        }

        return LayoutMetrics.topInset
            + ceil(backButton.fittingSize.height)
            + LayoutMetrics.backToSegmentSpacing
            + ceil(statusSegmentedControl.fittingSize.height)
            + LayoutMetrics.segmentToCardSpacing
            + ceil(cardView.fittingSize.height)
            + LayoutMetrics.cardToRowsSpacing
            + ceil(rowsStack.fittingSize.height)
            + editorHeight
            + LayoutMetrics.bottomInset
    }

    @objc
    private func handleBack() {
        onBack?()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        backButton.bezelStyle = .rounded
        backButton.target = self
        backButton.action = #selector(handleBack)
        backButton.font = .systemFont(ofSize: 11, weight: .semibold)
        backButton.translatesAutoresizingMaskIntoConstraints = false

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.setContentHuggingPriority(.required, for: .vertical)
        cardView.setContentCompressionResistancePriority(.required, for: .vertical)
        cardView.layer?.backgroundColor = MainPopoverStyle.Colors.weeklyProgressCardBackground.cgColor
        cardView.layer?.cornerRadius = MainPopoverStyle.Metrics.weeklyProgressCardCornerRadius
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = MainPopoverStyle.Colors.weeklyProgressCardBorder.cgColor
        cardView.layer?.shadowColor = MainPopoverStyle.Colors.shadow.cgColor
        cardView.layer?.shadowOpacity = MainPopoverStyle.Metrics.shadowOpacity
        cardView.layer?.shadowRadius = MainPopoverStyle.Metrics.shadowRadius
        cardView.layer?.shadowOffset = MainPopoverStyle.Metrics.shadowOffset

        let cardContent = NSStackView()
        cardContent.orientation = .vertical
        cardContent.alignment = .leading
        cardContent.spacing = LayoutMetrics.cardContentSpacing
        cardContent.translatesAutoresizingMaskIntoConstraints = false

        titleIconView.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: nil)
        titleIconView.contentTintColor = MainPopoverStyle.Colors.currentSessionValue

        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = MainPopoverStyle.Colors.primaryText

        weekLabel.font = .systemFont(ofSize: 11, weight: .medium)
        weekLabel.textColor = MainPopoverStyle.Colors.secondaryText

        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8
        titleRow.addArrangedSubview(titleIconView)
        titleRow.addArrangedSubview(titleLabel)

        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.distribution = .fill
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addArrangedSubview(titleRow)
        headerRow.addArrangedSubview(NSView())
        headerRow.addArrangedSubview(weekLabel)

        progressBar.preferredHeight = MainPopoverStyle.Metrics.weeklyProgressBarHeight
        progressBar.applyVisualState(.normal)
        progressBar.applyTrackStyle(
            backgroundColor: MainPopoverStyle.Colors.weeklyProgressTrackBackground,
            borderColor: MainPopoverStyle.Colors.weeklyProgressTrackBorder,
            borderWidth: 0
        )

        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.wantsLayer = true
        statusContainer.setContentHuggingPriority(.required, for: .vertical)
        statusContainer.setContentCompressionResistancePriority(.required, for: .vertical)
        statusContainer.layer?.cornerRadius = MainPopoverStyle.Metrics.weeklyProgressStatusCornerRadius
        statusContainer.layer?.borderWidth = 1

        statusSegmentedControl.segmentCount = 2
        statusSegmentedControl.setLabel(copy.weeklyProgressSegmentTitle, forSegment: MainPopoverWeeklyProgressStatusSegment.progress.rawValue)
        statusSegmentedControl.setLabel(copy.weeklyQuitTimeSegmentTitle, forSegment: MainPopoverWeeklyProgressStatusSegment.quitTime.rawValue)
        statusSegmentedControl.selectedSegment = MainPopoverWeeklyProgressStatusSegment.progress.rawValue
        statusSegmentedControl.trackingMode = .selectOne
        statusSegmentedControl.segmentStyle = .rounded
        statusSegmentedControl.target = self
        statusSegmentedControl.action = #selector(handleStatusSegmentChange)
        statusSegmentedControl.translatesAutoresizingMaskIntoConstraints = false

        statusIconView.image = NSImage(systemSymbolName: "scope", accessibilityDescription: nil)
        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        todayDeltaLabel.font = .systemFont(ofSize: 11, weight: .medium)
        todayDeltaLabel.textColor = MainPopoverStyle.Colors.secondaryText
        todayDeltaLabel.lineBreakMode = .byTruncatingTail
        todayDeltaLabel.alignment = .center
        todayDeltaLabel.maximumNumberOfLines = 1
        todayDeltaLabel.isHidden = true

        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 7
        statusRow.distribution = .fill
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        statusRow.addArrangedSubview(statusIconView)
        statusRow.addArrangedSubview(statusLabel)

        statusContainer.addSubview(statusRow)
        cardView.addSubview(cardContent)

        cardContent.addArrangedSubview(headerRow)
        cardContent.addArrangedSubview(progressBar)
        cardContent.addArrangedSubview(statusContainer)
        cardContent.addArrangedSubview(todayDeltaLabel)

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = MainPopoverStyle.Metrics.weeklyDetailRowSpacing
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.setContentHuggingPriority(.required, for: .vertical)
        rowsStack.setContentCompressionResistancePriority(.required, for: .vertical)

        detailEditorView.onApplyEditedTimes = { [weak self] date, startTime, endTime, isVacation in
            self?.onApplyEditedDayTimes?(date, startTime, endTime, isVacation)
        }

        addSubview(backButton)
        addSubview(statusSegmentedControl)
        addSubview(cardView)
        addSubview(rowsStack)
        addSubview(detailEditorView)

        let detailEditorTopConstraint = detailEditorView.topAnchor.constraint(equalTo: rowsStack.bottomAnchor, constant: 0)
        self.detailEditorTopConstraint = detailEditorTopConstraint
        let detailEditorBottomConstraint = detailEditorView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -LayoutMetrics.bottomInset)
        self.detailEditorBottomConstraint = detailEditorBottomConstraint
        let rowsBottomConstraint = rowsStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -LayoutMetrics.bottomInset)
        self.rowsBottomConstraint = rowsBottomConstraint
        let cardHeightConstraint = cardView.heightAnchor.constraint(equalToConstant: 0)
        self.cardHeightConstraint = cardHeightConstraint

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: topAnchor, constant: LayoutMetrics.topInset),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            statusSegmentedControl.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: LayoutMetrics.backToSegmentSpacing),
            statusSegmentedControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusSegmentedControl.widthAnchor.constraint(equalToConstant: MainPopoverStyle.Metrics.weeklyProgressCardWidth),

            cardView.topAnchor.constraint(equalTo: statusSegmentedControl.bottomAnchor, constant: LayoutMetrics.segmentToCardSpacing),
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.widthAnchor.constraint(equalToConstant: MainPopoverStyle.Metrics.weeklyProgressCardWidth),
            cardHeightConstraint,
            rowsStack.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: LayoutMetrics.cardToRowsSpacing),
            rowsStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            rowsStack.widthAnchor.constraint(equalTo: cardView.widthAnchor),
            detailEditorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            detailEditorView.widthAnchor.constraint(equalTo: cardView.widthAnchor),
            rowsBottomConstraint,

            cardContent.topAnchor.constraint(equalTo: cardView.topAnchor, constant: LayoutMetrics.cardPadding),
            cardContent.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: LayoutMetrics.cardPadding),
            cardContent.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -LayoutMetrics.cardPadding),
            cardContent.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -LayoutMetrics.cardPadding),

            progressBar.widthAnchor.constraint(equalTo: cardContent.widthAnchor),
            statusContainer.widthAnchor.constraint(equalTo: cardContent.widthAnchor),

            statusRow.topAnchor.constraint(equalTo: statusContainer.topAnchor, constant: LayoutMetrics.statusVerticalPadding),
            statusRow.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            statusRow.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor, constant: -LayoutMetrics.statusVerticalPadding),
        ])

        applyEditorLayout(isVisible: false)
        updateCardHeight()
    }

    private func applyEditorLayout(isVisible: Bool) {
        isEditorVisible = isVisible
        detailEditorView.isHidden = !isVisible
        detailEditorTopConstraint?.constant = isVisible ? 16 : 0
        rowsBottomConstraint?.isActive = !isVisible
        detailEditorTopConstraint?.isActive = isVisible
        detailEditorBottomConstraint?.isActive = isVisible
        needsLayout = true
        layoutSubtreeIfNeeded()
        logGeometry(reason: "applyEditorLayout[\(isVisible)]")
    }

    private func logGeometry(reason: String) {
        guard Self.isGeometryDebugEnabled else { return }
        print(
            "[WeeklyDetailGeometry] reason=\(reason) frame=\(NSStringFromRect(frame)) bounds=\(NSStringFromRect(bounds)) card=\(NSStringFromRect(cardView.frame)) rows=\(NSStringFromRect(rowsStack.frame)) editor=\(NSStringFromRect(detailEditorView.frame)) editorHidden=\(detailEditorView.isHidden) editorVisibleState=\(isEditorVisible) requiredHeight=\(requiredHeight())"
        )
    }

    private func applyVisualState(_ state: MainPopoverCurrentSessionVisualState) {
        isWarningState = state == .warning
        progressBar.applyVisualState(state)

        let statusTextColor: NSColor
        switch state {
        case .normal:
            titleIconView.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: nil)
            titleIconView.contentTintColor = MainPopoverStyle.Colors.currentSessionValue
            statusTextColor = MainPopoverStyle.Colors.weeklyProgressStatusText
            statusContainer.layer?.backgroundColor = MainPopoverStyle.Colors.weeklyProgressStatusBackground.cgColor
            statusContainer.layer?.borderColor = MainPopoverStyle.Colors.weeklyProgressStatusBorder.cgColor
        case .warning:
            titleIconView.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
            titleIconView.contentTintColor = MainPopoverStyle.Colors.weeklyProgressWarningStatusText
            statusTextColor = MainPopoverStyle.Colors.weeklyProgressWarningStatusText
            statusContainer.layer?.backgroundColor = MainPopoverStyle.Colors.weeklyProgressWarningStatusBackground.cgColor
            statusContainer.layer?.borderColor = MainPopoverStyle.Colors.weeklyProgressWarningStatusBorder.cgColor
        }

        statusLabel.textColor = statusTextColor
        updateSelectedStatusPresentation()
    }

    private func updateCardHeight() {
        layoutSubtreeIfNeeded()
        statusContainer.layoutSubtreeIfNeeded()

        let todayDeltaHeight: CGFloat
        if todayDeltaLabel.isHidden {
            todayDeltaHeight = 0
        } else {
            todayDeltaHeight = LayoutMetrics.cardContentSpacing + ceil(todayDeltaLabel.fittingSize.height)
        }

        let contentHeight =
            ceil(headerRow.fittingSize.height)
            + LayoutMetrics.cardContentSpacing
            + MainPopoverStyle.Metrics.weeklyProgressBarHeight
            + LayoutMetrics.cardContentSpacing
            + ceil(statusContainer.fittingSize.height)
            + todayDeltaHeight

        cardHeightConstraint?.constant = LayoutMetrics.cardPadding * 2 + contentHeight
    }

    @objc
    private func handleStatusSegmentChange() {
        updateSelectedStatusPresentation()
    }

    private func updateSelectedStatusPresentation() {
        guard let currentState else { return }
        let selectedSegment = MainPopoverWeeklyProgressStatusSegment(
            rawValue: max(0, statusSegmentedControl.selectedSegment)
        ) ?? .progress

        rowViews.forEach { $0.setDisplayMode(selectedSegment) }

        switch selectedSegment {
        case .progress:
            statusLabel.stringValue = currentState.statusText
            statusIconView.image = progressStatusIcon()
        case .quitTime:
            statusLabel.stringValue = currentState.quitTimeStatusText
            statusIconView.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
        }

        todayDeltaLabel.stringValue = currentState.todayDeltaStatusText
        todayDeltaLabel.isHidden = currentState.todayDeltaStatusText.isEmpty
        switch currentState.todayDeltaVisualState {
        case .neutral:
            todayDeltaLabel.textColor = MainPopoverStyle.Colors.secondaryText
        case .remaining:
            todayDeltaLabel.textColor = MainPopoverStyle.Colors.currentSessionValue
        case .overtime:
            todayDeltaLabel.textColor = MainPopoverStyle.Colors.detailOvertimeAccent
        }

        statusIconView.contentTintColor = statusLabel.textColor
    }

    private func progressStatusIcon() -> NSImage? {
        isWarningState
            ? NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
            : NSImage(systemSymbolName: "target", accessibilityDescription: nil)
    }

    private func syncRows(count: Int) {
        while rowViews.count < count {
            let rowView = MainPopoverWeeklyProgressDayRowView()
            rowViews.append(rowView)
            rowsStack.addArrangedSubview(rowView)
        }

        while rowViews.count > count {
            let rowView = rowViews.removeLast()
            rowsStack.removeArrangedSubview(rowView)
            rowView.removeFromSuperview()
        }
    }
}
