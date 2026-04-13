import Foundation

struct MainPopoverTodayTimesDisplayState {
    let startTimeText: String
    let endTimeText: String
}

struct MainPopoverAppliedTodayTimes {
    let startTime: Date?
    let endTime: Date?
    let isVacation: Bool

    init(startTime: Date?, endTime: Date?, isVacation: Bool = false) {
        self.startTime = startTime
        self.endTime = endTime
        self.isVacation = isVacation
    }
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
        sectionView.setDeleteActionTitle(copy.deleteActionTitle)
        bindSectionEvents()
    }

    func loadSavedTimes(
        startTime: Date?,
        endTime: Date?,
        isVacation: Bool = false,
        forceReload: Bool = false
    ) {
        if forceReload {
            editModeState = TodayTimeEditModeState()
        }
        editModeState.loadSavedTimes(startTime: startTime, endTime: endTime, isVacation: isVacation)
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
                endTime: appliedTimes.endTime,
                isVacation: editModeState.isVacationSelected
            )
        )
        onDidChange?()
    }

    func deleteEndTime() {
        guard let appliedTimes = editModeState.deleteEndTime() else { return }

        onDidApplyTimes?(
            MainPopoverAppliedTodayTimes(
                startTime: appliedTimes.startTime,
                endTime: appliedTimes.endTime,
                isVacation: false
            )
        )
        onDidChange?()
    }

    func setVacation(_ isVacation: Bool) {
        let appliedTimes = editModeState.setVacation(isVacation)
        onDidApplyTimes?(
            MainPopoverAppliedTodayTimes(
                startTime: appliedTimes.startTime,
                endTime: appliedTimes.endTime,
                isVacation: isVacation
            )
        )
        onDidChange?()
    }

    func setEditingDraft(_ draft: MainPopoverTodayTimesDraft) {
        sectionView.setEditingDraft(draft)
    }

    func makeRenderModel(
        displayState: MainPopoverTodayTimesDisplayState,
        fallbackStartTime: Date,
        fallbackEndTime: Date
    ) -> MainPopoverTodayTimesRenderModel {
        MainPopoverTodayTimesRenderModel(
            startRow: makeTimeRow(
                titleText: copy.startTimeTitle,
                valueText: displayState.startTimeText,
                isEditing: editModeState.isEditingStartTime,
                draftTime: editModeState.draftStartTime,
                fallbackTime: fallbackStartTime
            ),
            endRow: makeTimeRow(
                titleText: copy.endTimeTitle,
                valueText: displayState.endTimeText,
                isEditing: editModeState.isEditingEndTime,
                draftTime: editModeState.draftEndTime,
                fallbackTime: fallbackEndTime
            ),
            vacationToggleTitle: copy.vacationToggleTitle,
            isVacationSelected: editModeState.isVacationSelected,
            showsEditingActions: editModeState.editingField != nil,
            showsStartActions: editModeState.isEditingStartTime,
            showsEndActions: editModeState.isEditingEndTime,
            showsEndDeleteAction: editModeState.isEditingEndTime && editModeState.savedEndTime != nil,
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
            case .deleteEndTime:
                self?.deleteEndTime()
            case .toggleVacation(let isVacation):
                self?.setVacation(isVacation)
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
            pickerDateValue: draftTime ?? fallbackTime,
            isEnabled: editModeState.isVacationSelected == false
        )
    }
}
