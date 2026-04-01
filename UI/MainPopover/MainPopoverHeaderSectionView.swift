import AppKit

struct MainPopoverHeaderSectionSnapshot {
    let dateText: String
    let checkedInSummaryText: String
    let isDateIconLeading: Bool
    let isSettingsIconTrailing: Bool
    let isCheckInIconLeading: Bool
    let dateFontPointSize: CGFloat
    let checkedInSummaryFontPointSize: CGFloat
}

final class MainPopoverHeaderSectionView: NSView {
    private let dateLabel = NSTextField(labelWithString: "")
    private let checkedInSummaryLabel = NSTextField(labelWithString: "")
    private let dateIconView = MainPopoverSectionIconFactory.makeSymbolImageView(systemName: "calendar")
    private let settingsIconView = MainPopoverSectionIconFactory.makeSymbolImageView(systemName: "gearshape")
    private let checkInIconView = MainPopoverSectionIconFactory.makeTintedSymbolImageView(
        systemName: "arrow.right.to.line",
        color: MainPopoverStyle.Colors.checkInAccent
    )
    private let dateRow = NSStackView()
    private let checkInRow = NSStackView()

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

    var snapshot: MainPopoverHeaderSectionSnapshot {
        MainPopoverHeaderSectionSnapshot(
            dateText: dateLabel.stringValue,
            checkedInSummaryText: checkedInSummaryLabel.stringValue,
            isDateIconLeading: dateRow.arrangedSubviews.first === dateIconView,
            isSettingsIconTrailing: dateRow.arrangedSubviews.last === settingsIconView,
            isCheckInIconLeading: checkInRow.arrangedSubviews.first === checkInIconView,
            dateFontPointSize: dateLabel.font?.pointSize ?? 0,
            checkedInSummaryFontPointSize: checkedInSummaryLabel.font?.pointSize ?? 0
        )
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
