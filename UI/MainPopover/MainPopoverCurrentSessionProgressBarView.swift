import AppKit
import QuartzCore

final class CurrentSessionProgressBarView: NSView {
    private let trackView = NSView()
    private let fillView = NSView()
    private var heightConstraint: NSLayoutConstraint?
    private let gradientLayer = CAGradientLayer()
    private var fillColors: [CGColor] = []

    var progressFraction: CGFloat = 0 {
        didSet {
            needsLayout = true
        }
    }

    var preferredHeight: CGFloat = MainPopoverStyle.Metrics.progressBarHeight {
        didSet {
            heightConstraint?.constant = preferredHeight
        }
    }

    private(set) var visualState: MainPopoverCurrentSessionVisualState = .normal {
        didSet {
            updatePalette()
        }
    }

    var trackBorderWidth: CGFloat {
        trackView.layer?.borderWidth ?? 0
    }

    var fillLeadingColor: CGColor? {
        fillColors.first
    }

    var fillTrailingColor: CGColor? {
        fillColors.last
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
        fillView.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width * max(0, min(progressFraction, 1)),
            height: bounds.height
        )
        gradientLayer.frame = fillView.bounds
    }

    func applyVisualState(_ visualState: MainPopoverCurrentSessionVisualState) {
        self.visualState = visualState
    }

    func applyTrackStyle(
        backgroundColor: NSColor,
        borderColor: NSColor,
        borderWidth: CGFloat
    ) {
        trackView.layer?.backgroundColor = backgroundColor.cgColor
        trackView.layer?.borderColor = borderColor.cgColor
        trackView.layer?.borderWidth = borderWidth
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
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = MainPopoverStyle.Metrics.progressCornerRadius
        fillView.autoresizingMask = [.height]

        addSubview(trackView)
        addSubview(fillView)

        heightConstraint = heightAnchor.constraint(equalToConstant: preferredHeight)

        NSLayoutConstraint.activate([
            heightConstraint!,
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.topAnchor.constraint(equalTo: topAnchor),
            trackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updatePalette()
    }

    private func updatePalette() {
        let colors: [CGColor]
        switch visualState {
        case .normal:
            colors = [
                MainPopoverStyle.Colors.currentSessionAccentStart.cgColor,
                MainPopoverStyle.Colors.currentSessionAccentEnd.cgColor,
            ]
        case .warning:
            colors = [
                MainPopoverStyle.Colors.currentSessionWarningAccentStart.cgColor,
                MainPopoverStyle.Colors.currentSessionWarningAccentEnd.cgColor,
            ]
        }

        fillColors = colors
        gradientLayer.colors = colors
    }
}
