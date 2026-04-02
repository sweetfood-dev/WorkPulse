import AppKit

struct MainPopoverWeeklyProgressSectionSnapshot {
    let titleText: String
    let subtitleText: String
    let totalText: String
    let dayCount: Int
    let isShowingBackButton: Bool
}

private final class MainPopoverWeeklyProgressDayRowView: NSView {
    private let dayLabel = NSTextField(labelWithString: "")
    private let workedLabel = NSTextField(labelWithString: "")
    private let progressBar = CurrentSessionProgressBarView()
    private let row = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        dayLabel.font = MainPopoverStyle.Typography.sectionTitle
        dayLabel.textColor = MainPopoverStyle.Colors.primaryText

        workedLabel.font = MainPopoverStyle.Typography.progressCaption
        workedLabel.textColor = MainPopoverStyle.Colors.secondaryText
        workedLabel.alignment = .right

        progressBar.applyVisualState(.normal)

        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(dayLabel)
        row.addArrangedSubview(progressBar)
        row.addArrangedSubview(workedLabel)

        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressBar.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            workedLabel.widthAnchor.constraint(equalToConstant: 48),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: MainPopoverWeeklyProgressDayViewState) {
        dayLabel.stringValue = state.dayText
        dayLabel.textColor = state.isToday
            ? MainPopoverStyle.Colors.currentSessionValue
            : MainPopoverStyle.Colors.primaryText
        workedLabel.stringValue = state.workedText
        progressBar.progressFraction = state.progressFraction
    }
}

final class MainPopoverWeeklyProgressSectionView: NSView {
    var onBack: (() -> Void)?

    private let backButton = NSButton(title: "", target: nil, action: nil)
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let totalLabel = NSTextField(labelWithString: "")
    private let rowsStack = NSStackView()
    private let container = MainPopoverSectionContainerView(
        insets: MainPopoverStyle.Metrics.weeklyDetailInsets
    )
    private var rowViews: [MainPopoverWeeklyProgressDayRowView] = []

    init(copy: MainPopoverCopy = .english) {
        super.init(frame: .zero)
        backButton.title = copy.backActionTitle
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: MainPopoverWeeklyProgressViewState) {
        titleLabel.stringValue = state.titleText
        subtitleLabel.stringValue = state.subtitleText
        totalLabel.stringValue = state.totalText
        syncRows(count: state.days.count)

        zip(rowViews, state.days).forEach { row, day in
            row.apply(day)
        }
    }

    var snapshot: MainPopoverWeeklyProgressSectionSnapshot {
        MainPopoverWeeklyProgressSectionSnapshot(
            titleText: titleLabel.stringValue,
            subtitleText: subtitleLabel.stringValue,
            totalText: totalLabel.stringValue,
            dayCount: rowViews.count,
            isShowingBackButton: backButton.isHidden == false
        )
    }

    @objc
    private func handleBack() {
        onBack?()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.contentStack.spacing = MainPopoverStyle.Metrics.weeklyDetailSpacing

        backButton.bezelStyle = .inline
        backButton.target = self
        backButton.action = #selector(handleBack)

        titleLabel.font = MainPopoverStyle.Typography.dateTitle
        titleLabel.textColor = MainPopoverStyle.Colors.primaryText

        subtitleLabel.font = MainPopoverStyle.Typography.secondary
        subtitleLabel.textColor = MainPopoverStyle.Colors.secondaryText

        totalLabel.font = MainPopoverStyle.Typography.summaryValue
        totalLabel.textColor = MainPopoverStyle.Colors.primaryText

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = MainPopoverStyle.Metrics.weeklyDetailRowSpacing

        container.contentStack.addArrangedSubview(backButton)
        container.contentStack.addArrangedSubview(titleLabel)
        container.contentStack.addArrangedSubview(subtitleLabel)
        container.contentStack.addArrangedSubview(totalLabel)
        container.contentStack.addArrangedSubview(rowsStack)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
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
