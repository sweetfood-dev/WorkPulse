import AppKit

struct MonthlyHistoryViewControllerSnapshot {
    let monthText: String
    let totalDurationText: String
    let weekdayCount: Int
    let cellCount: Int
    let workedCellCount: Int
    let activeCellCount: Int
    let overtimeCellCount: Int
    let annotationTexts: [String]
    let rowWidths: [CGFloat]
    let hasOverflowingAnnotationLayout: Bool
    let isShowingEditor: Bool
    let editorDateText: String
}

private final class MonthlyHistoryDayCellView: NSView {
    private let dayLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let annotationLabel = NSTextField(labelWithString: "")
    private var activity: MonthlyHistoryDayCellActivity = .outsideMonth
    private var isOvertime = false
    private var selectedDate: Date?
    private var isSelectable = false
    var onSelect: ((Date) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = MainPopoverStyle.Metrics.monthlyHistoryCellCornerRadius
        layer?.borderWidth = 1

        dayLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        statusLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        statusLabel.maximumNumberOfLines = 1
        statusLabel.lineBreakMode = .byTruncatingTail
        annotationLabel.font = .systemFont(ofSize: 8, weight: .medium)
        annotationLabel.maximumNumberOfLines = 1
        annotationLabel.lineBreakMode = .byTruncatingTail

        for label in [statusLabel, annotationLabel] {
            label.cell?.wraps = false
            label.cell?.usesSingleLineMode = true
            label.cell?.truncatesLastVisibleLine = true
            label.cell?.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        let stack = NSStackView(views: [dayLabel, statusLabel, annotationLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: MainPopoverStyle.Metrics.monthlyHistoryCellHeight),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: MonthlyHistoryDayCellViewState) {
        selectedDate = state.date
        isSelectable = state.isSelectable
        activity = state.activity
        isOvertime = state.isOvertime
        dayLabel.stringValue = state.dayText
        statusLabel.stringValue = state.statusText
        annotationLabel.stringValue = state.annotationText ?? ""
        annotationLabel.isHidden = state.annotationText == nil
        alphaValue = 1

        switch state.activity {
        case .outsideMonth:
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderColor = NSColor.clear.cgColor
            dayLabel.textColor = .clear
            statusLabel.textColor = .clear
            annotationLabel.textColor = .clear
        case .worked:
            applyWorkedPalette(for: state.dayCategory, isOvertime: state.isOvertime)
            alphaValue = state.isDimmed ? 0.55 : 1
        case .active:
            applyActivePalette(for: state.dayCategory, isOvertime: state.isOvertime)
            alphaValue = state.isDimmed ? 0.55 : 1
        case .vacation:
            applyVacationPalette()
            alphaValue = state.isDimmed ? 0.55 : 1
        case .empty:
            applyEmptyPalette(for: state.dayCategory)
            alphaValue = state.isDimmed ? 0.55 : 0.78
        }

        annotationLabel.textColor = accentColor(for: state.dayCategory)?
            .withAlphaComponent(0.92)
            ?? MainPopoverStyle.Colors.secondaryText.withAlphaComponent(0.78)

        switch state.activity {
        case .worked:
            dayLabel.font = .systemFont(ofSize: 10, weight: .semibold)
            statusLabel.font = .systemFont(ofSize: 9, weight: .bold)
        case .active:
            dayLabel.font = .systemFont(ofSize: 10, weight: .bold)
            statusLabel.font = .systemFont(ofSize: 9, weight: .bold)
        case .vacation:
            dayLabel.font = .systemFont(ofSize: 10, weight: .bold)
            statusLabel.font = .systemFont(ofSize: 9, weight: .bold)
        case .empty:
            dayLabel.font = .systemFont(ofSize: 10, weight: .semibold)
            statusLabel.font = .systemFont(ofSize: 9, weight: .medium)
        case .outsideMonth:
            dayLabel.font = .systemFont(ofSize: 10, weight: .semibold)
            statusLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        }
    }

    private func applyWorkedPalette(for category: CalendarDayCategory, isOvertime: Bool) {
        if isOvertime {
            layer?.backgroundColor = MainPopoverStyle.Colors.detailOvertimeBackground.cgColor
            layer?.borderColor = MainPopoverStyle.Colors.detailOvertimeBorder.cgColor
            dayLabel.textColor = MainPopoverStyle.Colors.detailOvertimeAccent
            statusLabel.textColor = MainPopoverStyle.Colors.detailOvertimeAccent
            return
        }

        if let accent = accentColor(for: category) {
            layer?.backgroundColor = accent.withAlphaComponent(0.10).cgColor
            layer?.borderColor = accent.withAlphaComponent(0.20).cgColor
            dayLabel.textColor = accent
            statusLabel.textColor = accent
        } else {
            layer?.backgroundColor = MainPopoverStyle.Colors.monthlyHistoryWorkedCellBackground.cgColor
            layer?.borderColor = MainPopoverStyle.Colors.monthlyHistoryWorkedCellBorder.cgColor
            dayLabel.textColor = MainPopoverStyle.Colors.primaryText
            statusLabel.textColor = MainPopoverStyle.Colors.monthlyHistoryWorkedText
        }
    }

    private func applyActivePalette(for category: CalendarDayCategory, isOvertime: Bool) {
        if isOvertime {
            layer?.backgroundColor = MainPopoverStyle.Colors.detailOvertimeAccent.withAlphaComponent(0.14).cgColor
            layer?.borderColor = MainPopoverStyle.Colors.detailOvertimeBorder.cgColor
            dayLabel.textColor = MainPopoverStyle.Colors.detailOvertimeAccent
            statusLabel.textColor = MainPopoverStyle.Colors.detailOvertimeAccent
            return
        }

        if let accent = accentColor(for: category) {
            layer?.backgroundColor = accent.withAlphaComponent(0.14).cgColor
            layer?.borderColor = accent.withAlphaComponent(0.24).cgColor
            dayLabel.textColor = accent
            statusLabel.textColor = accent
        } else {
            layer?.backgroundColor = MainPopoverStyle.Colors.monthlyHistoryActiveCellBackground.cgColor
            layer?.borderColor = MainPopoverStyle.Colors.monthlyHistoryActiveCellBorder.cgColor
            dayLabel.textColor = MainPopoverStyle.Colors.currentSessionValue
            statusLabel.textColor = MainPopoverStyle.Colors.currentSessionValue
        }
    }

    private func applyEmptyPalette(for category: CalendarDayCategory) {
        if let accent = accentColor(for: category) {
            layer?.backgroundColor = accent.withAlphaComponent(0.07).cgColor
            layer?.borderColor = accent.withAlphaComponent(0.16).cgColor
            dayLabel.textColor = accent
            statusLabel.textColor = accent.withAlphaComponent(0.9)
        } else {
            layer?.backgroundColor = MainPopoverStyle.Colors.monthlyHistoryPlaceholderCellBackground.cgColor
            layer?.borderColor = MainPopoverStyle.Colors.monthlyHistoryPlaceholderCellBorder.cgColor
            dayLabel.textColor = MainPopoverStyle.Colors.secondaryText
            statusLabel.textColor = MainPopoverStyle.Colors.secondaryText.withAlphaComponent(0.65)
        }
    }

    private func applyVacationPalette() {
        layer?.backgroundColor = MainPopoverStyle.Colors.vacationBackground.cgColor
        layer?.borderColor = MainPopoverStyle.Colors.vacationBorder.cgColor
        dayLabel.textColor = MainPopoverStyle.Colors.vacationAccent
        statusLabel.textColor = MainPopoverStyle.Colors.vacationAccent
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

    var isWorked: Bool {
        activity == .worked
    }

    var isActive: Bool {
        activity == .active
    }

    var isVacationState: Bool {
        activity == .vacation
    }

    var isOvertimeState: Bool {
        isOvertime
    }

    var hasOverflowingAnnotationLayout: Bool {
        guard annotationLabel.isHidden == false else {
            return false
        }

        layoutSubtreeIfNeeded()
        return annotationLabel.frame.maxX > bounds.maxX - 6
            || annotationLabel.frame.maxY > bounds.maxY - 6
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
}

@MainActor
final class MonthlyHistoryViewController: NSViewController {
    private static let isGeometryDebugEnabled =
        ProcessInfo.processInfo.environment["WORKPULSE_DEBUG_POPOVER_GEOMETRY"] == "1"

    private enum LayoutMetrics {
        static let headerHeight: CGFloat = 54
        static let footerHeight: CGFloat = 48
        static let contentTopInset: CGFloat = 8
        static let contentBottomInset: CGFloat = 8
        static let weekdayToGridSpacing: CGFloat = 4
        static let weekdayRowHeight: CGFloat = 12
    }

    var onNavigatePrevious: (() -> Void)?
    var onNavigateNext: (() -> Void)?
    var onSelectDay: ((Date) -> Void)?
    var onApplyEditedDayTimes: ((Date, Date?, Date?, Bool) -> Void)?

    private let previousButton = NSButton(title: "", target: nil, action: nil)
    private let nextButton = NSButton(title: "", target: nil, action: nil)
    private let titleIconView = NSImageView()
    private let monthLabel = NSTextField(labelWithString: "")
    private let totalLabel = NSTextField(labelWithString: "")
    private let totalDurationLabel = NSTextField(labelWithString: "")
    private let weekdayRow = NSStackView()
    private let gridRows = NSStackView()
    private let detailEditorView = MainPopoverDetailDayEditorView()

    private var weekdayLabels: [NSTextField] = []
    private var dayCellViews: [MonthlyHistoryDayCellView] = []
    private var detailEditorTopConstraint: NSLayoutConstraint?
    private var detailEditorBottomConstraint: NSLayoutConstraint?
    private var gridBottomConstraint: NSLayoutConstraint?
    private var isEditorVisible = false

    static func requiredHeight(forRowCount rowCount: Int) -> CGFloat {
        requiredHeight(forRowCount: rowCount, editorHeight: 0, editorSpacing: 0)
    }

    static func requiredHeight(
        forRowCount rowCount: Int,
        editorHeight: CGFloat,
        editorSpacing: CGFloat
    ) -> CGFloat {
        let safeRowCount = max(rowCount, 1)
        let gridHeight = CGFloat(safeRowCount) * MainPopoverStyle.Metrics.monthlyHistoryCellHeight
            + CGFloat(safeRowCount - 1) * MainPopoverStyle.Metrics.monthlyHistoryGridSpacing

        return LayoutMetrics.headerHeight
            + LayoutMetrics.footerHeight
            + LayoutMetrics.contentTopInset
            + LayoutMetrics.weekdayRowHeight
            + LayoutMetrics.weekdayToGridSpacing
            + gridHeight
            + editorSpacing
            + editorHeight
            + LayoutMetrics.contentBottomInset
    }

    override func loadView() {
        let rootView = NSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: MainPopoverStyle.Metrics.monthlyHistoryWindowSize.width,
                height: Self.requiredHeight(forRowCount: 5)
            )
        )
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = MainPopoverStyle.Colors.popoverBackground.cgColor

        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = MainPopoverStyle.Colors.monthlyHistoryHeaderBackground.cgColor

        let footerView = NSView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = MainPopoverStyle.Colors.monthlyHistoryFooterBackground.cgColor

        configureNavigationButton(
            previousButton,
            symbolName: "chevron.left",
            action: #selector(handleNavigatePrevious)
        )
        configureNavigationButton(
            nextButton,
            symbolName: "chevron.right",
            action: #selector(handleNavigateNext)
        )

        titleIconView.image = NSImage(
            systemSymbolName: "clock.arrow.circlepath",
            accessibilityDescription: nil
        )
        titleIconView.contentTintColor = MainPopoverStyle.Colors.currentSessionValue

        monthLabel.font = .systemFont(ofSize: 13, weight: .bold)
        monthLabel.textColor = MainPopoverStyle.Colors.primaryText

        let titleStack = NSStackView(views: [titleIconView, monthLabel])
        titleStack.orientation = .horizontal
        titleStack.alignment = .centerY
        titleStack.spacing = 8
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(previousButton)
        headerView.addSubview(titleStack)
        headerView.addSubview(nextButton)

        weekdayRow.orientation = .horizontal
        weekdayRow.distribution = .fillEqually
        weekdayRow.alignment = .centerY
        weekdayRow.spacing = MainPopoverStyle.Metrics.monthlyHistoryGridSpacing
        weekdayRow.translatesAutoresizingMaskIntoConstraints = false

        gridRows.orientation = .vertical
        gridRows.alignment = .leading
        gridRows.spacing = MainPopoverStyle.Metrics.monthlyHistoryGridSpacing
        gridRows.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(weekdayRow)
        contentView.addSubview(gridRows)
        contentView.addSubview(detailEditorView)

        totalLabel.font = .systemFont(ofSize: 10, weight: .bold)
        totalLabel.textColor = MainPopoverStyle.Colors.secondaryText
        totalLabel.alignment = .left

        totalDurationLabel.font = .systemFont(ofSize: 13, weight: .bold)
        totalDurationLabel.textColor = MainPopoverStyle.Colors.currentSessionValue
        totalDurationLabel.alignment = .right

        let footerRow = NSStackView(views: [
            makeFooterIconView(),
            totalLabel,
            NSView(),
            totalDurationLabel,
        ])
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY
        footerRow.spacing = 8
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        footerView.addSubview(footerRow)

        detailEditorView.onApplyEditedTimes = { [weak self] date, startTime, endTime, isVacation in
            self?.onApplyEditedDayTimes?(date, startTime, endTime, isVacation)
        }

        rootView.addSubview(headerView)
        rootView.addSubview(contentView)
        rootView.addSubview(footerView)

        let detailEditorTopConstraint = detailEditorView.topAnchor.constraint(
            equalTo: gridRows.bottomAnchor,
            constant: 0
        )
        self.detailEditorTopConstraint = detailEditorTopConstraint
        let detailEditorBottomConstraint = detailEditorView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -LayoutMetrics.contentBottomInset
        )
        self.detailEditorBottomConstraint = detailEditorBottomConstraint
        let gridBottomConstraint = gridRows.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -LayoutMetrics.contentBottomInset
        )
        self.gridBottomConstraint = gridBottomConstraint

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: rootView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: LayoutMetrics.headerHeight),

            previousButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 14),
            previousButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleStack.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            nextButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -14),
            nextButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            contentView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            contentView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),

            weekdayRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: LayoutMetrics.contentTopInset),
            weekdayRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            weekdayRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            weekdayRow.heightAnchor.constraint(equalToConstant: LayoutMetrics.weekdayRowHeight),

            gridRows.topAnchor.constraint(equalTo: weekdayRow.bottomAnchor, constant: LayoutMetrics.weekdayToGridSpacing),
            gridRows.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gridRows.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            detailEditorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            detailEditorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gridBottomConstraint,

            footerView.topAnchor.constraint(equalTo: contentView.bottomAnchor),
            footerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: LayoutMetrics.footerHeight),

            footerRow.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
            footerRow.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -16),
            footerRow.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
        ])

        view = rootView
        applyEditorLayout(isVisible: false)
    }

    func apply(
        _ state: MonthlyHistoryViewState,
        editorState: MainPopoverDetailDayEditingState? = nil
    ) {
        loadViewIfNeeded()
        monthLabel.stringValue = state.monthText
        totalLabel.stringValue = state.totalLabelText.uppercased()
        totalDurationLabel.stringValue = state.totalDurationText
        syncWeekdays(count: state.weekdayTexts.count)
        zip(weekdayLabels, state.weekdayTexts).forEach { label, text in
            label.stringValue = text
        }
        syncCells(count: state.cells.count)
        zip(dayCellViews, state.cells).forEach { cellView, cellState in
            cellView.onSelect = { [weak self] selectedDate in
                self?.onSelectDay?(selectedDate)
            }
            cellView.apply(cellState)
        }
        detailEditorView.apply(editorState)
        applyEditorLayout(isVisible: editorState != nil)
        logGeometry(reason: "apply")
    }

    var snapshot: MonthlyHistoryViewControllerSnapshot {
        view.layoutSubtreeIfNeeded()
        return MonthlyHistoryViewControllerSnapshot(
            monthText: monthLabel.stringValue,
            totalDurationText: totalDurationLabel.stringValue,
            weekdayCount: weekdayLabels.count,
            cellCount: dayCellViews.count,
            workedCellCount: dayCellViews.filter(\.isWorked).count,
            activeCellCount: dayCellViews.filter(\.isActive).count,
            overtimeCellCount: dayCellViews.filter(\.isOvertimeState).count,
            annotationTexts: dayCellViews.map(\.annotationText).filter { $0.isEmpty == false },
            rowWidths: gridRows.arrangedSubviews.map(\.frame.width),
            hasOverflowingAnnotationLayout: dayCellViews.contains { $0.hasOverflowingAnnotationLayout },
            isShowingEditor: isEditorVisible,
            editorDateText: detailEditorView.snapshot.dateText
        )
    }

    func simulateNavigatePrevious() {
        handleNavigatePrevious()
    }

    func simulateNavigateNext() {
        handleNavigateNext()
    }

    func simulateSelectDay(at index: Int) {
        guard dayCellViews.indices.contains(index) else { return }
        dayCellViews[index].simulateSelect()
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
        view.layoutSubtreeIfNeeded()

        let editorHeight: CGFloat
        let editorSpacing: CGFloat
        if isEditorVisible {
            editorSpacing = detailEditorTopConstraint?.constant ?? 0
            editorHeight = ceil(detailEditorView.fittingSize.height)
        } else {
            editorSpacing = 0
            editorHeight = 0
        }

        return Self.requiredHeight(
            forRowCount: max(gridRows.arrangedSubviews.count, 1),
            editorHeight: editorHeight,
            editorSpacing: editorSpacing
        )
    }

    private func applyEditorLayout(isVisible: Bool) {
        isEditorVisible = isVisible
        detailEditorView.isHidden = !isVisible
        detailEditorTopConstraint?.constant = isVisible ? 16 : 0
        gridBottomConstraint?.isActive = !isVisible
        detailEditorTopConstraint?.isActive = isVisible
        detailEditorBottomConstraint?.isActive = isVisible
        guard isViewLoaded else { return }
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        logGeometry(reason: "applyEditorLayout[\(isVisible)]")
    }

    private func logGeometry(reason: String) {
        guard Self.isGeometryDebugEnabled else { return }
        print(
            "[MonthlyDetailGeometry] reason=\(reason) frame=\(NSStringFromRect(view.frame)) bounds=\(NSStringFromRect(view.bounds)) weekdayRow=\(NSStringFromRect(weekdayRow.frame)) gridRows=\(NSStringFromRect(gridRows.frame)) editor=\(NSStringFromRect(detailEditorView.frame)) editorHidden=\(detailEditorView.isHidden) editorVisibleState=\(isEditorVisible) requiredHeight=\(requiredHeight())"
        )
    }

    @objc
    private func handleNavigatePrevious() {
        onNavigatePrevious?()
    }

    @objc
    private func handleNavigateNext() {
        onNavigateNext?()
    }

    private func configureNavigationButton(
        _ button: NSButton,
        symbolName: String,
        action: Selector
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        button.contentTintColor = MainPopoverStyle.Colors.secondaryText
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
    }

    private func makeFooterIconView() -> NSImageView {
        let view = NSImageView()
        view.image = NSImage(systemSymbolName: "sum", accessibilityDescription: nil)
        view.contentTintColor = MainPopoverStyle.Colors.secondaryText
        return view
    }

    private func syncWeekdays(count: Int) {
        while weekdayLabels.count < count {
            let label = NSTextField(labelWithString: "")
            label.font = .systemFont(ofSize: 9, weight: .bold)
            label.textColor = MainPopoverStyle.Colors.secondaryText
            label.alignment = .center
            weekdayLabels.append(label)
            weekdayRow.addArrangedSubview(label)
        }

        while weekdayLabels.count > count {
            let label = weekdayLabels.removeLast()
            weekdayRow.removeArrangedSubview(label)
            label.removeFromSuperview()
        }
    }

    private func syncCells(count: Int) {
        let rowCount = count / 7

        while gridRows.arrangedSubviews.count < rowCount {
            let row = NSStackView()
            row.orientation = .horizontal
            row.distribution = .fillEqually
            row.alignment = .centerY
            row.spacing = MainPopoverStyle.Metrics.monthlyHistoryGridSpacing
            row.translatesAutoresizingMaskIntoConstraints = false
            gridRows.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: gridRows.widthAnchor).isActive = true
        }

        while gridRows.arrangedSubviews.count > rowCount {
            guard let row = gridRows.arrangedSubviews.last else { break }
            gridRows.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        while dayCellViews.count < count {
            let cellView = MonthlyHistoryDayCellView()
            let rowIndex = dayCellViews.count / 7
            (gridRows.arrangedSubviews[rowIndex] as? NSStackView)?.addArrangedSubview(cellView)
            dayCellViews.append(cellView)
        }

        while dayCellViews.count > count {
            let cellView = dayCellViews.removeLast()
            cellView.superview.flatMap { superview in
                (superview as? NSStackView)?.removeArrangedSubview(cellView)
            }
            cellView.removeFromSuperview()
        }
    }
}
