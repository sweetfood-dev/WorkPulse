import AppKit

final class MainPopoverSummarySectionView: NSView {
    let weeklyTitleLabel = NSTextField(labelWithString: "")
    let weeklyValueLabel = NSTextField(labelWithString: "")
    let monthlyTitleLabel = NSTextField(labelWithString: "")
    let monthlyValueLabel = NSTextField(labelWithString: "")
    let weeklyIconView = MainPopoverSectionIconFactory.makeSymbolImageView(systemName: "calendar")
    let monthlyIconView = MainPopoverSectionIconFactory.makeSymbolImageView(systemName: "chart.bar")
    let weeklyTitleRow = NSStackView()
    let monthlyTitleRow = NSStackView()
    let weeklyColumn = NSStackView()
    let monthlyColumn = NSStackView()
    let columnsRow = NSStackView()

    private let container = MainPopoverSectionContainerView(
        insets: MainPopoverStyle.Metrics.summaryInsets
    )

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ renderModel: MainPopoverSummaryRenderModel) {
        weeklyTitleLabel.stringValue = renderModel.weekly.titleText
        weeklyValueLabel.stringValue = renderModel.weekly.valueText
        monthlyTitleLabel.stringValue = renderModel.monthly.titleText
        monthlyValueLabel.stringValue = renderModel.monthly.valueText
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.contentStack.spacing = MainPopoverStyle.Metrics.summarySpacing

        weeklyTitleLabel.font = MainPopoverStyle.Typography.sectionTitle
        weeklyTitleLabel.textColor = MainPopoverStyle.Colors.secondaryText
        weeklyValueLabel.font = MainPopoverStyle.Typography.summaryValue
        weeklyValueLabel.textColor = MainPopoverStyle.Colors.primaryText

        monthlyTitleLabel.font = MainPopoverStyle.Typography.sectionTitle
        monthlyTitleLabel.textColor = MainPopoverStyle.Colors.secondaryText
        monthlyTitleLabel.alignment = .right
        monthlyValueLabel.font = MainPopoverStyle.Typography.summaryValue
        monthlyValueLabel.textColor = MainPopoverStyle.Colors.primaryText
        monthlyValueLabel.alignment = .right

        weeklyTitleRow.addArrangedSubview(weeklyIconView)
        weeklyTitleRow.addArrangedSubview(weeklyTitleLabel)
        weeklyTitleRow.orientation = .horizontal
        weeklyTitleRow.alignment = .centerY
        weeklyTitleRow.spacing = MainPopoverStyle.Metrics.summaryTitleRowSpacing

        monthlyTitleRow.addArrangedSubview(NSView())
        monthlyTitleRow.addArrangedSubview(monthlyTitleLabel)
        monthlyTitleRow.addArrangedSubview(monthlyIconView)
        monthlyTitleRow.orientation = .horizontal
        monthlyTitleRow.alignment = .centerY
        monthlyTitleRow.spacing = MainPopoverStyle.Metrics.summaryTitleRowSpacing

        weeklyColumn.addArrangedSubview(weeklyTitleRow)
        weeklyColumn.addArrangedSubview(weeklyValueLabel)
        weeklyColumn.orientation = .vertical
        weeklyColumn.alignment = .leading
        weeklyColumn.spacing = MainPopoverStyle.Metrics.summarySpacing

        monthlyColumn.addArrangedSubview(monthlyTitleRow)
        monthlyColumn.addArrangedSubview(monthlyValueLabel)
        monthlyColumn.orientation = .vertical
        monthlyColumn.alignment = .trailing
        monthlyColumn.spacing = MainPopoverStyle.Metrics.summarySpacing

        columnsRow.addArrangedSubview(weeklyColumn)
        columnsRow.addArrangedSubview(NSView())
        columnsRow.addArrangedSubview(monthlyColumn)
        columnsRow.orientation = .horizontal
        columnsRow.alignment = .top
        columnsRow.spacing = MainPopoverStyle.Metrics.summaryRowSpacing

        container.contentStack.addArrangedSubview(columnsRow)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
