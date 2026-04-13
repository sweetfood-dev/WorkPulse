import CoreGraphics
import Foundation

enum MainPopoverCurrentSessionVisualState {
    case normal
    case warning
}

struct MainPopoverHeaderRenderModel {
    let dateText: String
    let checkedInSummaryText: String
    let reportActionTitle: String
}

struct MainPopoverCurrentSessionRenderModel {
    let titleText: String
    let valueText: String
    let leadingCaptionText: String
    let trailingCaptionText: String
    let progressFraction: CGFloat
    let visualState: MainPopoverCurrentSessionVisualState
}

struct MainPopoverTimeRowRenderModel {
    let titleText: String
    let valueText: String
    let isValueVisible: Bool
    let isPickerVisible: Bool
    let pickerDateValue: Date
    let isEnabled: Bool

    init(
        titleText: String,
        valueText: String,
        isValueVisible: Bool,
        isPickerVisible: Bool,
        pickerDateValue: Date,
        isEnabled: Bool = true
    ) {
        self.titleText = titleText
        self.valueText = valueText
        self.isValueVisible = isValueVisible
        self.isPickerVisible = isPickerVisible
        self.pickerDateValue = pickerDateValue
        self.isEnabled = isEnabled
    }
}

struct MainPopoverTodayTimesRenderModel {
    let startRow: MainPopoverTimeRowRenderModel
    let endRow: MainPopoverTimeRowRenderModel
    let vacationToggleTitle: String
    let isVacationSelected: Bool
    let showsEditingActions: Bool
    let showsStartActions: Bool
    let showsEndActions: Bool
    let showsEndDeleteAction: Bool
    let isApplyEnabled: Bool

    init(
        startRow: MainPopoverTimeRowRenderModel,
        endRow: MainPopoverTimeRowRenderModel,
        vacationToggleTitle: String = MainPopoverCopy.english.vacationToggleTitle,
        isVacationSelected: Bool = false,
        showsEditingActions: Bool,
        showsStartActions: Bool,
        showsEndActions: Bool,
        showsEndDeleteAction: Bool,
        isApplyEnabled: Bool
    ) {
        self.startRow = startRow
        self.endRow = endRow
        self.vacationToggleTitle = vacationToggleTitle
        self.isVacationSelected = isVacationSelected
        self.showsEditingActions = showsEditingActions
        self.showsStartActions = showsStartActions
        self.showsEndActions = showsEndActions
        self.showsEndDeleteAction = showsEndDeleteAction
        self.isApplyEnabled = isApplyEnabled
    }
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

    init(
        copy: MainPopoverCopy = .english
    ) {
        self.copy = copy
    }

    func make(
        viewState: MainPopoverViewState,
        currentSession: MainPopoverCurrentSessionRenderModel,
        todayTimes: MainPopoverTodayTimesRenderModel
    ) -> MainPopoverRenderModel {
        MainPopoverRenderModel(
            header: MainPopoverHeaderRenderModel(
                dateText: viewState.dateText,
                checkedInSummaryText: viewState.checkedInSummaryText,
                reportActionTitle: copy.reportActionTitle
            ),
            currentSession: currentSession,
            todayTimes: todayTimes,
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
}
