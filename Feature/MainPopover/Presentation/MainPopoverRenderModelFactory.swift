import CoreGraphics
import Foundation

struct MainPopoverHeaderRenderModel {
    let dateText: String
    let checkedInSummaryText: String
}

struct MainPopoverCurrentSessionRenderModel {
    let titleText: String
    let valueText: String
    let leadingCaptionText: String
    let trailingCaptionText: String
    let progressFraction: CGFloat
}

struct MainPopoverTimeRowRenderModel {
    let titleText: String
    let valueText: String
    let isValueVisible: Bool
    let isPickerVisible: Bool
    let pickerDateValue: Date
}

struct MainPopoverTodayTimesRenderModel {
    let startRow: MainPopoverTimeRowRenderModel
    let endRow: MainPopoverTimeRowRenderModel
    let showsEditingActions: Bool
    let showsStartActions: Bool
    let showsEndActions: Bool
    let isApplyEnabled: Bool
}

struct MainPopoverSummaryItemRenderModel {
    let titleText: String
    let valueText: String
}

struct MainPopoverSummaryRenderModel {
    let weekly: MainPopoverSummaryItemRenderModel
    let monthly: MainPopoverSummaryItemRenderModel
}

struct MainPopoverRenderModel {
    let header: MainPopoverHeaderRenderModel
    let currentSession: MainPopoverCurrentSessionRenderModel
    let todayTimes: MainPopoverTodayTimesRenderModel
    let summary: MainPopoverSummaryRenderModel
}

struct MainPopoverRenderModelFactory {
    private let copy: MainPopoverCopy
    private let progressPolicy: MainPopoverCurrentSessionProgressPolicy

    init(
        copy: MainPopoverCopy = .english,
        progressPolicy: MainPopoverCurrentSessionProgressPolicy
    ) {
        self.copy = copy
        self.progressPolicy = progressPolicy
    }

    func make(
        viewState: MainPopoverViewState,
        currentSessionText: String,
        currentSessionDuration: TimeInterval?,
        editModeState: TodayTimeEditModeState,
        fallbackTime: Date
    ) -> MainPopoverRenderModel {
        MainPopoverRenderModel(
            header: MainPopoverHeaderRenderModel(
                dateText: viewState.dateText,
                checkedInSummaryText: viewState.checkedInSummaryText
            ),
            currentSession: MainPopoverCurrentSessionRenderModel(
                titleText: copy.currentSessionTitle,
                valueText: currentSessionText,
                leadingCaptionText: copy.currentSessionLeadingCaption,
                trailingCaptionText: copy.currentSessionTrailingCaption(
                    goalDuration: progressPolicy.goalDuration
                ),
                progressFraction: progressPolicy.fraction(for: currentSessionDuration)
            ),
            todayTimes: MainPopoverTodayTimesRenderModel(
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
            ),
            summary: MainPopoverSummaryRenderModel(
                weekly: MainPopoverSummaryItemRenderModel(
                    titleText: copy.weeklyTitle,
                    valueText: viewState.weeklyTotalText
                ),
                monthly: MainPopoverSummaryItemRenderModel(
                    titleText: copy.monthlyTitle,
                    valueText: viewState.monthlyTotalText
                )
            )
        )
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
