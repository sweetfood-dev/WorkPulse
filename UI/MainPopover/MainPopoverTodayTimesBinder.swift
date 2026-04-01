import Foundation

struct MainPopoverAppliedTodayTimes {
    let startTime: Date?
    let endTime: Date?
}

@MainActor
final class MainPopoverTodayTimesBinder {
    private let sectionView: MainPopoverTodayTimesSectionView
    private let copy: MainPopoverCopy
    private var editModeState = TodayTimeEditModeState()

    var onDidChange: (() -> Void)?
    var onDidApplyTimes: ((MainPopoverAppliedTodayTimes) -> Void)?

    init(
        sectionView: MainPopoverTodayTimesSectionView,
        copy: MainPopoverCopy = .english
    ) {
        self.sectionView = sectionView
        self.copy = copy
        bindSectionEvents()
    }

    func loadSavedTimes(startTime: Date?, endTime: Date?) {
        editModeState.loadSavedTimes(startTime: startTime, endTime: endTime)
    }

    func beginEditing(_ field: TodayTimeField) {
        editModeState.beginEditing(field)
        onDidChange?()
    }

    func cancelEditing() {
        editModeState.cancel()
        onDidChange?()
    }

    func applyEditing() {
        let draft = sectionView.currentDraft()

        switch editModeState.editingField {
        case .startTime:
            editModeState.updateDraftStartTime(draft.startTime)
        case .endTime:
            editModeState.updateDraftEndTime(draft.endTime)
        case nil:
            return
        }

        guard editModeState.hasValidDraftTimes else {
            onDidChange?()
            return
        }

        guard let appliedTimes = editModeState.apply() else { return }
        onDidApplyTimes?(
            MainPopoverAppliedTodayTimes(
                startTime: appliedTimes.startTime,
                endTime: appliedTimes.endTime
            )
        )
        onDidChange?()
    }

    func setEditingDraft(_ draft: MainPopoverTodayTimesDraft) {
        sectionView.setEditingDraft(draft)
    }

    func makeRenderModel(
        viewState: MainPopoverViewState,
        fallbackTime: Date
    ) -> MainPopoverTodayTimesRenderModel {
        MainPopoverTodayTimesRenderModel(
            startRow: makeTimeRow(
                titleText: copy.startTimeTitle,
                valueText: viewState.startTimeText,
                isEditing: editModeState.isEditingStartTime,
                draftTime: editModeState.draftStartTime,
                fallbackTime: fallbackTime
            ),
            endRow: makeTimeRow(
                titleText: copy.endTimeTitle,
                valueText: viewState.endTimeText,
                isEditing: editModeState.isEditingEndTime,
                draftTime: editModeState.draftEndTime,
                fallbackTime: fallbackTime
            ),
            showsEditingActions: editModeState.editingField != nil,
            showsStartActions: editModeState.isEditingStartTime,
            showsEndActions: editModeState.isEditingEndTime,
            isApplyEnabled: editModeState.hasValidDraftTimes
        )
    }

    private func bindSectionEvents() {
        sectionView.onEvent = { [weak self] event in
            switch event {
            case .beginEditing(let field):
                self?.beginEditing(field)
            case .applyEditing:
                self?.applyEditing()
            case .cancelEditing:
                self?.cancelEditing()
            case .draftChanged(let draft):
                self?.updateDraft(draft)
            }
        }
    }

    private func updateDraft(_ draft: MainPopoverTodayTimesDraft) {
        switch editModeState.editingField {
        case .startTime:
            editModeState.updateDraftStartTime(draft.startTime)
        case .endTime:
            editModeState.updateDraftEndTime(draft.endTime)
        case nil:
            return
        }

        onDidChange?()
    }

    private func makeTimeRow(
        titleText: String,
        valueText: String,
        isEditing: Bool,
        draftTime: Date?,
        fallbackTime: Date
    ) -> MainPopoverTimeRowRenderModel {
        MainPopoverTimeRowRenderModel(
            titleText: titleText,
            valueText: valueText,
            isValueVisible: !isEditing,
            isPickerVisible: isEditing,
            pickerDateValue: draftTime ?? fallbackTime
        )
    }
}
