import AppKit
import QuartzCore

final class MainPopoverSectionContainerView: NSView {
    let contentStack = NSStackView()
    let backgroundView: NSView?

    init(
        insets: NSEdgeInsets,
        backgroundColor: NSColor? = nil,
        shadow: Bool = false
    ) {
        let backgroundView: NSView?
        if let backgroundColor {
            let view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = backgroundColor.cgColor
            if shadow {
                view.layer?.shadowColor = MainPopoverStyle.Colors.shadow.cgColor
                view.layer?.shadowOpacity = MainPopoverStyle.Metrics.shadowOpacity
                view.layer?.shadowRadius = MainPopoverStyle.Metrics.shadowRadius
                view.layer?.shadowOffset = MainPopoverStyle.Metrics.shadowOffset
            }
            view.translatesAutoresizingMaskIntoConstraints = false
            backgroundView = view
        } else {
            backgroundView = nil
        }
        self.backgroundView = backgroundView
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        if let backgroundView {
            addSubview(backgroundView)
            NSLayoutConstraint.activate([
                backgroundView.topAnchor.constraint(equalTo: topAnchor),
                backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
                backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
                backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

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
            Self.makeSymbolImageView(systemName: "calendar"),
            dateLabel,
            NSView(),
            Self.makeSymbolImageView(systemName: "gearshape")
        ])
        dateRow.orientation = .horizontal
        dateRow.alignment = .centerY
        dateRow.spacing = MainPopoverStyle.Metrics.headerSpacing

        let checkInRow = NSStackView(views: [
            Self.makeTintedSymbolImageView(systemName: "arrow.right.to.line", color: MainPopoverStyle.Colors.checkInAccent),
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

    static func makeSymbolImageView(systemName: String) -> NSImageView {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
        imageView.contentTintColor = MainPopoverStyle.Colors.iconTint
        return imageView
    }

    static func makeTintedSymbolImageView(systemName: String, color: NSColor) -> NSImageView {
        let imageView = makeSymbolImageView(systemName: systemName)
        imageView.contentTintColor = color
        return imageView
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
            MainPopoverHeaderSectionView.makeTintedSymbolImageView(
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

final class MainPopoverTimeRowView: NSView {
    let titleLabel = NSTextField(labelWithString: "")
    let valuePillView = NSView()
    let valueLabel = NSTextField(labelWithString: "")
    let picker = NSDatePicker()

    init(iconSystemName: String) {
        super.init(frame: .zero)
        configure(iconSystemName: iconSystemName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ renderModel: MainPopoverTimeRowRenderModel) {
        titleLabel.stringValue = renderModel.titleText
        valueLabel.stringValue = renderModel.valueText
        valueLabel.isHidden = !renderModel.isValueVisible
        picker.isHidden = !renderModel.isPickerVisible
        picker.dateValue = renderModel.pickerDateValue
    }

    private func configure(iconSystemName: String) {
        translatesAutoresizingMaskIntoConstraints = false
        let iconView = MainPopoverHeaderSectionView.makeSymbolImageView(systemName: iconSystemName)
        let trailingContainer = NSView()
        trailingContainer.translatesAutoresizingMaskIntoConstraints = false
        valuePillView.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        picker.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = MainPopoverStyle.Typography.sectionTitle
        titleLabel.textColor = MainPopoverStyle.Colors.primaryText

        valueLabel.font = MainPopoverStyle.Typography.rowValue
        valueLabel.textColor = MainPopoverStyle.Colors.primaryText
        valueLabel.alignment = .center

        picker.datePickerElements = [.hourMinute]
        picker.datePickerStyle = .textField
        picker.datePickerMode = .single
        picker.controlSize = .regular
        picker.alignment = .center
        picker.isBordered = false
        picker.isBezeled = false
        picker.drawsBackground = false
        picker.font = MainPopoverStyle.Typography.rowValue

        valuePillView.wantsLayer = true
        valuePillView.layer?.backgroundColor = MainPopoverStyle.Colors.valuePillBackground.cgColor
        valuePillView.layer?.borderColor = MainPopoverStyle.Colors.valuePillBorder.cgColor
        valuePillView.layer?.borderWidth = MainPopoverStyle.Metrics.valuePillBorderWidth
        valuePillView.layer?.cornerRadius = MainPopoverStyle.Metrics.valuePillCornerRadius

        trailingContainer.addSubview(valuePillView)
        valuePillView.addSubview(valueLabel)
        trailingContainer.addSubview(picker)

        let row = NSStackView(views: [iconView, titleLabel, NSView(), trailingContainer])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = MainPopoverStyle.Metrics.timeRowSpacing
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            trailingContainer.widthAnchor.constraint(equalToConstant: MainPopoverStyle.Metrics.valuePillWidth),
            valuePillView.leadingAnchor.constraint(equalTo: trailingContainer.leadingAnchor),
            valuePillView.trailingAnchor.constraint(equalTo: trailingContainer.trailingAnchor),
            valuePillView.topAnchor.constraint(equalTo: trailingContainer.topAnchor),
            valuePillView.bottomAnchor.constraint(equalTo: trailingContainer.bottomAnchor),
            valuePillView.heightAnchor.constraint(equalToConstant: MainPopoverStyle.Metrics.valuePillHeight),
            valueLabel.leadingAnchor.constraint(equalTo: valuePillView.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: valuePillView.trailingAnchor, constant: -12),
            valueLabel.centerYAnchor.constraint(equalTo: valuePillView.centerYAnchor),
            picker.leadingAnchor.constraint(equalTo: trailingContainer.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: trailingContainer.trailingAnchor),
            picker.topAnchor.constraint(equalTo: trailingContainer.topAnchor),
            picker.bottomAnchor.constraint(equalTo: trailingContainer.bottomAnchor),
        ])
    }
}

final class MainPopoverTodayTimesSectionView: NSView {
    let startRowView = MainPopoverTimeRowView(iconSystemName: "arrow.right.to.line")
    let endRowView = MainPopoverTimeRowView(iconSystemName: "rectangle.portrait.and.arrow.right")
    let startTimeApplyButton = NSButton(title: "Apply", target: nil, action: nil)
    let startTimeCancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    let endTimeApplyButton = NSButton(title: "Apply", target: nil, action: nil)
    let endTimeCancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    private let container = MainPopoverSectionContainerView(
        insets: MainPopoverStyle.Metrics.todayTimesInsets,
        backgroundColor: MainPopoverStyle.Colors.todayTimesBackground,
        shadow: true
    )
    let editingActionRow = NSStackView()

    var backgroundView: NSView {
        guard let backgroundView = container.backgroundView else {
            fatalError("Today times section requires a background view")
        }
        return backgroundView
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ renderModel: MainPopoverTodayTimesRenderModel) {
        startRowView.apply(renderModel.startRow)
        endRowView.apply(renderModel.endRow)

        editingActionRow.isHidden = !renderModel.showsEditingActions
        startTimeApplyButton.isHidden = !renderModel.showsStartActions
        startTimeCancelButton.isHidden = !renderModel.showsStartActions
        endTimeApplyButton.isHidden = !renderModel.showsEndActions
        endTimeCancelButton.isHidden = !renderModel.showsEndActions
        startTimeApplyButton.isEnabled = renderModel.isApplyEnabled
        endTimeApplyButton.isEnabled = renderModel.isApplyEnabled
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.contentStack.spacing = MainPopoverStyle.Metrics.todayTimesSpacing

        [startTimeApplyButton, startTimeCancelButton, endTimeApplyButton, endTimeCancelButton].forEach { button in
            button.bezelStyle = .rounded
            button.controlSize = .small
        }

        editingActionRow.orientation = .horizontal
        editingActionRow.alignment = .centerY
        editingActionRow.spacing = MainPopoverStyle.Metrics.actionRowSpacing
        editingActionRow.addArrangedSubview(NSView())
        editingActionRow.addArrangedSubview(startTimeCancelButton)
        editingActionRow.addArrangedSubview(startTimeApplyButton)
        editingActionRow.addArrangedSubview(endTimeCancelButton)
        editingActionRow.addArrangedSubview(endTimeApplyButton)
        editingActionRow.isHidden = true

        container.contentStack.addArrangedSubview(startRowView)
        container.contentStack.addArrangedSubview(endRowView)
        container.contentStack.addArrangedSubview(editingActionRow)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

final class MainPopoverSummarySectionView: NSView {
    let weeklyTitleLabel = NSTextField(labelWithString: "")
    let weeklyValueLabel = NSTextField(labelWithString: "")
    let monthlyTitleLabel = NSTextField(labelWithString: "")
    let monthlyValueLabel = NSTextField(labelWithString: "")
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

        let weeklyTitleRow = NSStackView(views: [
            MainPopoverHeaderSectionView.makeSymbolImageView(systemName: "calendar"),
            weeklyTitleLabel,
        ])
        weeklyTitleRow.orientation = .horizontal
        weeklyTitleRow.alignment = .centerY
        weeklyTitleRow.spacing = MainPopoverStyle.Metrics.summaryTitleRowSpacing

        let monthlyTitleRow = NSStackView(views: [
            NSView(),
            monthlyTitleLabel,
            MainPopoverHeaderSectionView.makeSymbolImageView(systemName: "chart.bar"),
        ])
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
