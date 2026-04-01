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
    private let currentSessionGoalDuration: TimeInterval
    private let maximumVisibleProgressFraction: CGFloat

    init(
        currentSessionGoalDuration: TimeInterval,
        maximumVisibleProgressFraction: CGFloat
    ) {
        self.currentSessionGoalDuration = currentSessionGoalDuration
        self.maximumVisibleProgressFraction = maximumVisibleProgressFraction
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
                titleText: "CURRENT SESSION",
                valueText: currentSessionText,
                leadingCaptionText: "0H",
                trailingCaptionText: "Goal: 8h",
                progressFraction: progressFraction(for: currentSessionDuration)
            ),
            todayTimes: MainPopoverTodayTimesRenderModel(
                startRow: makeTimeRow(
                    titleText: "Start Time",
                    valueText: viewState.startTimeText,
                    isEditing: editModeState.isEditingStartTime,
                    draftTime: editModeState.draftStartTime,
                    fallbackTime: fallbackTime
                ),
                endRow: makeTimeRow(
                    titleText: "End Time",
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
                    titleText: "This Week",
                    valueText: viewState.weeklyTotalText
                ),
                monthly: MainPopoverSummaryItemRenderModel(
                    titleText: "This Month",
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

    private func progressFraction(for duration: TimeInterval?) -> CGFloat {
        guard let duration else { return 0 }

        let rawFraction = CGFloat(duration / currentSessionGoalDuration)
        if rawFraction >= 1 {
            return maximumVisibleProgressFraction
        }

        return max(0, rawFraction)
    }
}
