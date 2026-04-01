import AppKit

struct MainPopoverTimeRowSnapshot {
    let titleText: String
    let valueText: String
    let isValueVisible: Bool
    let isPickerVisible: Bool
    let pickerDateValue: Date
}

struct MainPopoverTodayTimesDraft {
    let startTime: Date
    let endTime: Date
}

final class MainPopoverTimeRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valuePillView = NSView()
    private let valueLabel = NSTextField(labelWithString: "")
    private let picker = NSDatePicker()
    private var isPickerTextEditing = false
    var onPickerDateChange: ((Date) -> Void)?

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
        if renderModel.isPickerVisible == false {
            isPickerTextEditing = false
        }
        guard isPickerTextEditing == false else { return }
        picker.dateValue = renderModel.pickerDateValue
    }

    func setPickerDate(_ date: Date) {
        picker.dateValue = date
    }

    var pickerDateValue: Date {
        picker.dateValue
    }

    var snapshot: MainPopoverTimeRowSnapshot {
        MainPopoverTimeRowSnapshot(
            titleText: titleLabel.stringValue,
            valueText: valueLabel.stringValue,
            isValueVisible: valueLabel.isHidden == false,
            isPickerVisible: picker.isHidden == false,
            pickerDateValue: picker.dateValue
        )
    }

    func containsDescendant(_ view: NSView) -> Bool {
        view.isDescendant(of: valuePillView)
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
        picker.target = self
        picker.action = #selector(handlePickerDateChange)

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePickerTextDidBeginEditing),
            name: NSControl.textDidBeginEditingNotification,
            object: picker
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePickerTextDidEndEditing),
            name: NSControl.textDidEndEditingNotification,
            object: picker
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePickerTextDidChange),
            name: NSControl.textDidChangeNotification,
            object: picker
        )

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

    @objc
    private func handlePickerDateChange() {
        onPickerDateChange?(picker.dateValue)
    }

    @objc
    private func handlePickerTextDidBeginEditing() {
        isPickerTextEditing = true
    }

    @objc
    private func handlePickerTextDidEndEditing() {
        isPickerTextEditing = false
        onPickerDateChange?(picker.dateValue)
    }

    @objc
    private func handlePickerTextDidChange() {
        onPickerDateChange?(picker.dateValue)
    }
}

struct MainPopoverTodayTimesSectionSnapshot {
    let startRow: MainPopoverTimeRowSnapshot
    let endRow: MainPopoverTimeRowSnapshot
    let isStartApplyVisible: Bool
    let isStartCancelVisible: Bool
    let isEndApplyVisible: Bool
    let isEndCancelVisible: Bool
    let isApplyEnabled: Bool
    let isBackgroundFullWidth: Bool
    let areEditingActionsOutsideValuePills: Bool
}

enum MainPopoverTodayTimesSectionEvent {
    case beginEditing(TodayTimeField)
    case applyEditing
    case cancelEditing
    case draftChanged(MainPopoverTodayTimesDraft)
}

final class MainPopoverTodayTimesSectionView: NSView {
    private let startRowView = MainPopoverTimeRowView(iconSystemName: "arrow.right.to.line")
    private let endRowView = MainPopoverTimeRowView(iconSystemName: "rectangle.portrait.and.arrow.right")
    private let startTimeApplyButton = NSButton(title: "Apply", target: nil, action: nil)
    private let startTimeCancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let endTimeApplyButton = NSButton(title: "Apply", target: nil, action: nil)
    private let endTimeCancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    private let container = MainPopoverSectionContainerView(
        insets: MainPopoverStyle.Metrics.todayTimesInsets,
        backgroundColor: MainPopoverStyle.Colors.todayTimesBackground,
        shadow: true
    )
    private let editingActionRow = NSStackView()

    var onEvent: ((MainPopoverTodayTimesSectionEvent) -> Void)?

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

    func setEditingDraft(_ draft: MainPopoverTodayTimesDraft) {
        startRowView.setPickerDate(draft.startTime)
        endRowView.setPickerDate(draft.endTime)
    }

    func currentDraft() -> MainPopoverTodayTimesDraft {
        MainPopoverTodayTimesDraft(
            startTime: startRowView.pickerDateValue,
            endTime: endRowView.pickerDateValue
        )
    }

    var snapshot: MainPopoverTodayTimesSectionSnapshot {
        let backgroundView = container.backgroundView
        return MainPopoverTodayTimesSectionSnapshot(
            startRow: startRowView.snapshot,
            endRow: endRowView.snapshot,
            isStartApplyVisible: startTimeApplyButton.isHidden == false,
            isStartCancelVisible: startTimeCancelButton.isHidden == false,
            isEndApplyVisible: endTimeApplyButton.isHidden == false,
            isEndCancelVisible: endTimeCancelButton.isHidden == false,
            isApplyEnabled: (
                startTimeApplyButton.isHidden == false && startTimeApplyButton.isEnabled
            ) || (
                endTimeApplyButton.isHidden == false && endTimeApplyButton.isEnabled
            ),
            isBackgroundFullWidth: backgroundView.map {
                $0.frame.minX == bounds.minX && $0.frame.maxX == bounds.maxX
            } ?? false,
            areEditingActionsOutsideValuePills:
                startRowView.containsDescendant(editingActionRow) == false &&
                endRowView.containsDescendant(editingActionRow) == false
        )
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.contentStack.spacing = MainPopoverStyle.Metrics.todayTimesSpacing

        [startTimeApplyButton, startTimeCancelButton, endTimeApplyButton, endTimeCancelButton].forEach { button in
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.target = self
        }
        startTimeApplyButton.action = #selector(handleApplyEditing)
        endTimeApplyButton.action = #selector(handleApplyEditing)
        startTimeCancelButton.action = #selector(handleCancelEditing)
        endTimeCancelButton.action = #selector(handleCancelEditing)

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

        let startTapRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleStartRowTap))
        startRowView.addGestureRecognizer(startTapRecognizer)

        let endTapRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleEndRowTap))
        endRowView.addGestureRecognizer(endTapRecognizer)

        startRowView.onPickerDateChange = { [weak self] _ in
            guard let self else { return }
            self.onEvent?(.draftChanged(self.currentDraft()))
        }
        endRowView.onPickerDateChange = { [weak self] _ in
            guard let self else { return }
            self.onEvent?(.draftChanged(self.currentDraft()))
        }

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func simulatePickerChange(_ date: Date, for field: TodayTimeField) {
        switch field {
        case .startTime:
            startRowView.setPickerDate(date)
        case .endTime:
            endRowView.setPickerDate(date)
        }
        onEvent?(.draftChanged(currentDraft()))
    }

    @objc
    private func handleStartRowTap() {
        onEvent?(.beginEditing(.startTime))
    }

    @objc
    private func handleEndRowTap() {
        onEvent?(.beginEditing(.endTime))
    }

    @objc
    private func handleApplyEditing() {
        onEvent?(.applyEditing)
    }

    @objc
    private func handleCancelEditing() {
        onEvent?(.cancelEditing)
    }

}
