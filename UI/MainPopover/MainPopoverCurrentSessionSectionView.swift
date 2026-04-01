import AppKit

struct MainPopoverCurrentSessionSectionSnapshot {
    let titleText: String
    let valueText: String
    let leadingCaptionText: String
    let trailingCaptionText: String
    let progressFraction: CGFloat
    let trackBorderWidth: CGFloat
    let isTitleIconLeading: Bool
    let valueFontPointSize: CGFloat
    let captionFontPointSize: CGFloat
    let captionRowItemCount: Int
}

final class MainPopoverCurrentSessionSectionView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let progressBar = CurrentSessionProgressBarView()
    private let leadingCaptionLabel = NSTextField(labelWithString: "")
    private let trailingCaptionLabel = NSTextField(labelWithString: "")
    private let titleIconView = MainPopoverSectionIconFactory.makeTintedSymbolImageView(
        systemName: "hourglass",
        color: MainPopoverStyle.Colors.currentSessionValue
    )
    private let titleRow = NSStackView()
    private let captionRow = NSStackView()

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

    var snapshot: MainPopoverCurrentSessionSectionSnapshot {
        MainPopoverCurrentSessionSectionSnapshot(
            titleText: titleLabel.stringValue,
            valueText: valueLabel.stringValue,
            leadingCaptionText: leadingCaptionLabel.stringValue,
            trailingCaptionText: trailingCaptionLabel.stringValue,
            progressFraction: progressBar.progressFraction,
            trackBorderWidth: progressBar.trackBorderWidth,
            isTitleIconLeading: titleRow.arrangedSubviews.first === titleIconView,
            valueFontPointSize: valueLabel.font?.pointSize ?? 0,
            captionFontPointSize: leadingCaptionLabel.font?.pointSize ?? 0,
            captionRowItemCount: captionRow.arrangedSubviews.count
        )
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
