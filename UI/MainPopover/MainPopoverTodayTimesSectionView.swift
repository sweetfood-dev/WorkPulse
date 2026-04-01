import AppKit

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
        let iconView = MainPopoverSectionIconFactory.makeSymbolImageView(systemName: iconSystemName)
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
