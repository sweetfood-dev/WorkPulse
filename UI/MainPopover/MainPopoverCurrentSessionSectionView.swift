import AppKit
import QuartzCore

final class CurrentSessionProgressBarView: NSView {
    private let trackView = NSView()
    private let fillView = NSView()
    private var fillWidthConstraint: NSLayoutConstraint?
    private let gradientLayer = CAGradientLayer()

    var progressFraction: CGFloat = 0 {
        didSet {
            needsLayout = true
        }
    }

    var trackBorderWidth: CGFloat {
        trackView.layer?.borderWidth ?? 0
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        fillWidthConstraint?.constant = bounds.width * max(0, min(progressFraction, 1))
    }

    private func configure() {
        wantsLayer = true

        trackView.wantsLayer = true
        trackView.layer?.backgroundColor = MainPopoverStyle.Colors.progressTrackBackground.cgColor
        trackView.layer?.borderColor = MainPopoverStyle.Colors.progressTrackBorder.cgColor
        trackView.layer?.borderWidth = MainPopoverStyle.Metrics.progressTrackBorderWidth
        trackView.layer?.cornerRadius = MainPopoverStyle.Metrics.progressCornerRadius
        trackView.translatesAutoresizingMaskIntoConstraints = false

        fillView.wantsLayer = true
        fillView.layer = gradientLayer
        gradientLayer.colors = [
            MainPopoverStyle.Colors.currentSessionAccentStart.cgColor,
            MainPopoverStyle.Colors.currentSessionAccentEnd.cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = MainPopoverStyle.Metrics.progressCornerRadius
        fillView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(trackView)
        addSubview(fillView)

        fillWidthConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: MainPopoverStyle.Metrics.progressBarHeight),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.topAnchor.constraint(equalTo: topAnchor),
            trackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fillView.topAnchor.constraint(equalTo: topAnchor),
            fillView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fillWidthConstraint!,
        ])
    }
}

final class MainPopoverCurrentSessionSectionView: NSView {
    let titleLabel = NSTextField(labelWithString: "")
    let valueLabel = NSTextField(labelWithString: "")
    let progressBar = CurrentSessionProgressBarView()
    let leadingCaptionLabel = NSTextField(labelWithString: "")
    let trailingCaptionLabel = NSTextField(labelWithString: "")

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

        let titleRow = NSStackView(views: [
            MainPopoverSectionIconFactory.makeTintedSymbolImageView(
                systemName: "hourglass",
                color: MainPopoverStyle.Colors.currentSessionValue
            ),
            titleLabel,
        ])
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

        let captionRow = NSStackView(views: [
            leadingCaptionLabel,
            NSView(),
            trailingCaptionLabel,
        ])
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
