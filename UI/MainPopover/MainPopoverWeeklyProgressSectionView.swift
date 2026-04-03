import AppKit

struct MainPopoverWeeklyProgressSectionSnapshot {
    let titleText: String
    let weekText: String
    let statusText: String
    let progressFraction: CGFloat
    let dayCount: Int
    let annotationTexts: [String]
    let isShowingBackButton: Bool
    let isWarningState: Bool
    let isShowingEditor: Bool
    let editorDateText: String
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
        selectedDate = state.date
        isSelectable = state.isSelectable
        dayLabel.stringValue = state.dayText
        annotationLabel.stringValue = state.annotationText ?? ""
        annotationLabel.isHidden = state.annotationText == nil
        timeRangeLabel.stringValue = state.timeRangeText
        workedLabel.stringValue = state.workedText
        progressBar.progressFraction = state.progressFraction

        let accentColor = accentColor(for: state.dayCategory)
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
}

@MainActor
final class MainPopoverWeeklyProgressSectionView: NSView {
    private static let isGeometryDebugEnabled =
        ProcessInfo.processInfo.environment["WORKPULSE_DEBUG_POPOVER_GEOMETRY"] == "1"

    private enum LayoutMetrics {
        static let topInset: CGFloat = 18
        static let backToCardSpacing: CGFloat = 12
        static let cardToRowsSpacing: CGFloat = 18
        static let bottomInset: CGFloat = 20
    }

    var onBack: (() -> Void)?
    var onSelectDay: ((Date) -> Void)?
    var onApplyEditedDayTimes: ((Date, Date?, Date?) -> Void)?

    private let backButton = NSButton(title: "", target: nil, action: nil)
    private let cardView = NSView()
    private let titleIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let weekLabel = NSTextField(labelWithString: "")
    private let statusIconView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let progressBar = CurrentSessionProgressBarView()
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
    private var isEditorVisible = false

    init(copy: MainPopoverCopy = .english) {
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
        titleLabel.stringValue = state.titleText
        weekLabel.stringValue = state.weekText
        statusLabel.stringValue = state.statusText
        progressBar.progressFraction = state.progressFraction
        applyVisualState(state.visualState)
        syncRows(count: state.days.count)

        zip(rowViews, state.days).forEach { row, day in
            row.onSelect = { [weak self] selectedDate in
                self?.onSelectDay?(selectedDate)
            }
            row.apply(day)
        }
        detailEditorView.apply(editorState)
        applyEditorLayout(isVisible: editorState != nil)
        logGeometry(reason: "apply")
    }

    var snapshot: MainPopoverWeeklyProgressSectionSnapshot {
        MainPopoverWeeklyProgressSectionSnapshot(
            titleText: titleLabel.stringValue,
            weekText: weekLabel.stringValue,
            statusText: statusLabel.stringValue,
            progressFraction: progressBar.progressFraction,
            dayCount: rowViews.count,
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
            + LayoutMetrics.backToCardSpacing
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
        cardContent.spacing = 20
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
        statusContainer.layer?.cornerRadius = MainPopoverStyle.Metrics.weeklyProgressStatusCornerRadius
        statusContainer.layer?.borderWidth = 1

        statusIconView.image = NSImage(systemSymbolName: "scope", accessibilityDescription: nil)
        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)

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

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = MainPopoverStyle.Metrics.weeklyDetailRowSpacing
        rowsStack.translatesAutoresizingMaskIntoConstraints = false

        detailEditorView.onApplyEditedTimes = { [weak self] date, startTime, endTime in
            self?.onApplyEditedDayTimes?(date, startTime, endTime)
        }

        addSubview(backButton)
        addSubview(cardView)
        addSubview(rowsStack)
        addSubview(detailEditorView)

        let detailEditorTopConstraint = detailEditorView.topAnchor.constraint(equalTo: rowsStack.bottomAnchor, constant: 0)
        self.detailEditorTopConstraint = detailEditorTopConstraint
        let detailEditorBottomConstraint = detailEditorView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -LayoutMetrics.bottomInset)
        self.detailEditorBottomConstraint = detailEditorBottomConstraint
        let rowsBottomConstraint = rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -LayoutMetrics.bottomInset)
        self.rowsBottomConstraint = rowsBottomConstraint

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: topAnchor, constant: LayoutMetrics.topInset),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            cardView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: LayoutMetrics.backToCardSpacing),
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.widthAnchor.constraint(equalToConstant: MainPopoverStyle.Metrics.weeklyProgressCardWidth),
            rowsStack.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: LayoutMetrics.cardToRowsSpacing),
            rowsStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            rowsStack.widthAnchor.constraint(equalTo: cardView.widthAnchor),
            detailEditorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            detailEditorView.widthAnchor.constraint(equalTo: cardView.widthAnchor),
            rowsBottomConstraint,

            cardContent.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            cardContent.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            cardContent.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            cardContent.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24),

            progressBar.widthAnchor.constraint(equalTo: cardContent.widthAnchor),
            statusContainer.widthAnchor.constraint(equalTo: cardContent.widthAnchor),

            statusRow.topAnchor.constraint(equalTo: statusContainer.topAnchor, constant: 11),
            statusRow.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            statusRow.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor, constant: -11),
        ])

        applyEditorLayout(isVisible: false)
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

        switch state {
        case .normal:
            titleIconView.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: nil)
            titleIconView.contentTintColor = MainPopoverStyle.Colors.currentSessionValue
            statusIconView.image = NSImage(systemSymbolName: "target", accessibilityDescription: nil)
            statusIconView.contentTintColor = MainPopoverStyle.Colors.weeklyProgressStatusText
            statusLabel.textColor = MainPopoverStyle.Colors.weeklyProgressStatusText
            statusContainer.layer?.backgroundColor = MainPopoverStyle.Colors.weeklyProgressStatusBackground.cgColor
            statusContainer.layer?.borderColor = MainPopoverStyle.Colors.weeklyProgressStatusBorder.cgColor
        case .warning:
            titleIconView.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
            titleIconView.contentTintColor = MainPopoverStyle.Colors.weeklyProgressWarningStatusText
            statusIconView.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
            statusIconView.contentTintColor = MainPopoverStyle.Colors.weeklyProgressWarningStatusText
            statusLabel.textColor = MainPopoverStyle.Colors.weeklyProgressWarningStatusText
            statusContainer.layer?.backgroundColor = MainPopoverStyle.Colors.weeklyProgressWarningStatusBackground.cgColor
            statusContainer.layer?.borderColor = MainPopoverStyle.Colors.weeklyProgressWarningStatusBorder.cgColor
        }
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
