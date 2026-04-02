import AppKit

private final class MonthlyHistoryRowView: NSView {
    private let dateLabel = NSTextField(labelWithString: "")
    private let timeRangeLabel = NSTextField(labelWithString: "")
    private let workedDurationLabel = NSTextField(labelWithString: "")
    private let row = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = MainPopoverStyle.Colors.todayTimesBackground.cgColor
        layer?.cornerRadius = MainPopoverStyle.Metrics.valuePillCornerRadius

        dateLabel.font = MainPopoverStyle.Typography.sectionTitle
        dateLabel.textColor = MainPopoverStyle.Colors.primaryText

        timeRangeLabel.font = MainPopoverStyle.Typography.secondary
        timeRangeLabel.textColor = MainPopoverStyle.Colors.secondaryText

        workedDurationLabel.font = MainPopoverStyle.Typography.rowValue
        workedDurationLabel.textColor = MainPopoverStyle.Colors.primaryText
        workedDurationLabel.alignment = .right

        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(dateLabel)
        row.addArrangedSubview(timeRangeLabel)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(workedDurationLabel)

        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            workedDurationLabel.widthAnchor.constraint(equalToConstant: 88),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: MonthlyHistoryItemViewState) {
        dateLabel.stringValue = state.dateText
        timeRangeLabel.stringValue = state.timeRangeText
        workedDurationLabel.stringValue = state.workedDurationText
        workedDurationLabel.textColor = state.isInProgress
            ? MainPopoverStyle.Colors.currentSessionValue
            : MainPopoverStyle.Colors.primaryText
    }
}

@MainActor
final class MonthlyHistoryViewController: NSViewController {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let totalLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "")
    private let rowsStack = NSStackView()
    private let scrollView = NSScrollView()
    private var rowViews: [MonthlyHistoryRowView] = []

    override func loadView() {
        let rootView = NSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: MainPopoverStyle.Metrics.monthlyHistoryWindowSize.width,
                height: MainPopoverStyle.Metrics.monthlyHistoryWindowSize.height
            )
        )
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = MainPopoverStyle.Colors.popoverBackground.cgColor

        titleLabel.font = MainPopoverStyle.Typography.dateTitle
        titleLabel.textColor = MainPopoverStyle.Colors.primaryText

        subtitleLabel.font = MainPopoverStyle.Typography.secondary
        subtitleLabel.textColor = MainPopoverStyle.Colors.secondaryText

        totalLabel.font = MainPopoverStyle.Typography.summaryValue
        totalLabel.textColor = MainPopoverStyle.Colors.primaryText

        emptyLabel.font = MainPopoverStyle.Typography.secondary
        emptyLabel.textColor = MainPopoverStyle.Colors.secondaryText
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = MainPopoverStyle.Metrics.monthlyHistoryRowSpacing
        rowsStack.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            rowsStack.widthAnchor.constraint(equalTo: documentView.widthAnchor),
        ])

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        rootView.addSubview(titleLabel)
        rootView.addSubview(subtitleLabel)
        rootView.addSubview(totalLabel)
        rootView.addSubview(emptyLabel)
        rootView.addSubview(scrollView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            totalLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            totalLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            totalLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -20),
            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        view = rootView
    }

    func apply(_ state: MonthlyHistoryViewState) {
        loadViewIfNeeded()
        titleLabel.stringValue = state.titleText
        subtitleLabel.stringValue = state.subtitleText
        totalLabel.stringValue = state.totalText
        emptyLabel.stringValue = state.emptyText
        emptyLabel.isHidden = state.items.isEmpty == false
        syncRows(count: state.items.count)

        zip(rowViews, state.items).forEach { row, item in
            row.apply(item)
        }
    }

    private func syncRows(count: Int) {
        while rowViews.count < count {
            let rowView = MonthlyHistoryRowView()
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
