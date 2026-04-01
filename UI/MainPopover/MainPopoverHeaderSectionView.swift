import AppKit

final class MainPopoverHeaderSectionView: NSView {
    let dateLabel = NSTextField(labelWithString: "")
    let checkedInSummaryLabel = NSTextField(labelWithString: "")

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

        let dateRow = NSStackView(views: [
            MainPopoverSectionIconFactory.makeSymbolImageView(systemName: "calendar"),
            dateLabel,
            NSView(),
            MainPopoverSectionIconFactory.makeSymbolImageView(systemName: "gearshape")
        ])
        dateRow.orientation = .horizontal
        dateRow.alignment = .centerY
        dateRow.spacing = MainPopoverStyle.Metrics.headerSpacing

        let checkInRow = NSStackView(views: [
            MainPopoverSectionIconFactory.makeTintedSymbolImageView(
                systemName: "arrow.right.to.line",
                color: MainPopoverStyle.Colors.checkInAccent
            ),
            checkedInSummaryLabel,
            NSView(),
        ])
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
