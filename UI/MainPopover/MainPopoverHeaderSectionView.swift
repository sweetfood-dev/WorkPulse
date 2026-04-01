import AppKit

final class MainPopoverHeaderSectionView: NSView {
    let dateLabel = NSTextField(labelWithString: "")
    let checkedInSummaryLabel = NSTextField(labelWithString: "")
    let dateIconView = MainPopoverSectionIconFactory.makeSymbolImageView(systemName: "calendar")
    let settingsIconView = MainPopoverSectionIconFactory.makeSymbolImageView(systemName: "gearshape")
    let checkInIconView = MainPopoverSectionIconFactory.makeTintedSymbolImageView(
        systemName: "arrow.right.to.line",
        color: MainPopoverStyle.Colors.checkInAccent
    )
    let dateRow = NSStackView()
    let checkInRow = NSStackView()

    private let container = MainPopoverSectionContainerView(
        insets: MainPopoverStyle.Metrics.headerInsets
    )

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ renderModel: MainPopoverHeaderRenderModel) {
        dateLabel.stringValue = renderModel.dateText
        checkedInSummaryLabel.stringValue = renderModel.checkedInSummaryText
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font = MainPopoverStyle.Typography.dateTitle
        dateLabel.textColor = MainPopoverStyle.Colors.primaryText
        checkedInSummaryLabel.font = MainPopoverStyle.Typography.secondary
        checkedInSummaryLabel.textColor = MainPopoverStyle.Colors.secondaryText

        dateRow.addArrangedSubview(dateIconView)
        dateRow.addArrangedSubview(dateLabel)
        dateRow.addArrangedSubview(NSView())
        dateRow.addArrangedSubview(settingsIconView)
        dateRow.orientation = .horizontal
        dateRow.alignment = .centerY
        dateRow.spacing = MainPopoverStyle.Metrics.headerSpacing

        checkInRow.addArrangedSubview(checkInIconView)
        checkInRow.addArrangedSubview(checkedInSummaryLabel)
        checkInRow.addArrangedSubview(NSView())
        checkInRow.orientation = .horizontal
        checkInRow.alignment = .centerY
        checkInRow.spacing = 8

        container.contentStack.spacing = MainPopoverStyle.Metrics.headerSpacing
        container.contentStack.addArrangedSubview(dateRow)
        container.contentStack.addArrangedSubview(checkInRow)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
