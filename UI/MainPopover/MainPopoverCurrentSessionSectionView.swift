import AppKit

final class MainPopoverCurrentSessionSectionView: NSView {
    let titleLabel = NSTextField(labelWithString: "")
    let valueLabel = NSTextField(labelWithString: "")
    let progressBar = CurrentSessionProgressBarView()
    let leadingCaptionLabel = NSTextField(labelWithString: "")
    let trailingCaptionLabel = NSTextField(labelWithString: "")
    let titleIconView = MainPopoverSectionIconFactory.makeTintedSymbolImageView(
        systemName: "hourglass",
        color: MainPopoverStyle.Colors.currentSessionValue
    )
    let titleRow = NSStackView()
    let captionRow = NSStackView()

    private let container = MainPopoverSectionContainerView(
        insets: MainPopoverStyle.Metrics.currentSessionInsets
    )

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ renderModel: MainPopoverCurrentSessionRenderModel) {
        titleLabel.attributedStringValue = NSAttributedString(
            string: renderModel.titleText,
            attributes: MainPopoverStyle.Typography.currentSessionTitleAttributes
        )
        valueLabel.stringValue = renderModel.valueText
        leadingCaptionLabel.stringValue = renderModel.leadingCaptionText
        trailingCaptionLabel.stringValue = renderModel.trailingCaptionText
        progressBar.progressFraction = renderModel.progressFraction
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.contentStack.alignment = .centerX
        container.contentStack.spacing = MainPopoverStyle.Metrics.currentSessionSpacing

        titleRow.addArrangedSubview(titleIconView)
        titleRow.addArrangedSubview(titleLabel)
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8

        valueLabel.font = MainPopoverStyle.Typography.currentSessionValue
        valueLabel.textColor = MainPopoverStyle.Colors.currentSessionValue
        valueLabel.alignment = .center

        leadingCaptionLabel.font = MainPopoverStyle.Typography.progressCaption
        leadingCaptionLabel.textColor = MainPopoverStyle.Colors.secondaryText
        trailingCaptionLabel.font = MainPopoverStyle.Typography.progressCaption
        trailingCaptionLabel.textColor = MainPopoverStyle.Colors.secondaryText
        trailingCaptionLabel.alignment = .right

        captionRow.addArrangedSubview(leadingCaptionLabel)
        captionRow.addArrangedSubview(NSView())
        captionRow.addArrangedSubview(trailingCaptionLabel)
        captionRow.orientation = .horizontal
        captionRow.alignment = .centerY
        captionRow.spacing = MainPopoverStyle.Metrics.currentSessionProgressCaptionSpacing

        container.contentStack.addArrangedSubview(titleRow)
        container.contentStack.addArrangedSubview(valueLabel)
        container.contentStack.addArrangedSubview(progressBar)
        container.contentStack.addArrangedSubview(captionRow)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressBar.widthAnchor.constraint(
                equalTo: container.contentStack.widthAnchor,
                constant: -(MainPopoverStyle.Metrics.currentSessionInsets.left + MainPopoverStyle.Metrics.currentSessionInsets.right)
            ),
        ])
    }
}
