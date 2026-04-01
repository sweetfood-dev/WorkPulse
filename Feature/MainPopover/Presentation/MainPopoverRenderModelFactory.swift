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
    let showsEndDeleteAction: Bool
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
                checkedInSummaryText: viewState.checkedInSummaryText
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
