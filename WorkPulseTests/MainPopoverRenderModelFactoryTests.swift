import Foundation
import Testing
@testable import WorkPulse

@Suite("MainPopoverRenderModelFactory")
struct MainPopoverRenderModelFactoryTests {
    private let factory = MainPopoverRenderModelFactory()
    private let placeholderState = MainPopoverViewStateFactory(copy: .english).makePlaceholder()

    @Test
    func composesInjectedCurrentSessionAndTodayTimesRenderModels() {
        let currentSession = MainPopoverCurrentSessionRenderModel(
            titleText: "SESSION",
            valueText: "00:12:34",
            leadingCaptionText: "0H",
            trailingCaptionText: "Goal: 8h",
            progressFraction: 0.12
        )
        let todayTimes = MainPopoverTodayTimesRenderModel(
            startRow: MainPopoverTimeRowRenderModel(
                titleText: "In",
                valueText: "08:45",
                isValueVisible: true,
                isPickerVisible: false,
                pickerDateValue: Date(timeIntervalSince1970: 0)
            ),
            endRow: MainPopoverTimeRowRenderModel(
                titleText: "Out",
                valueText: "--:--",
                isValueVisible: true,
                isPickerVisible: false,
                pickerDateValue: Date(timeIntervalSince1970: 0)
            ),
            showsEditingActions: false,
            showsStartActions: false,
            showsEndActions: false,
            showsEndDeleteAction: false,
            isApplyEnabled: false
        )

        let renderModel = factory.make(
            viewState: placeholderState,
            currentSession: currentSession,
            todayTimes: todayTimes
        )

        #expect(renderModel.currentSession.titleText == "SESSION")
        #expect(renderModel.currentSession.valueText == "00:12:34")
        #expect(renderModel.todayTimes.startRow.titleText == "In")
        #expect(renderModel.todayTimes.endRow.titleText == "Out")
    }

    @Test
    func usesInjectedCopyValuesForSummaryLabels() {
        let factory = MainPopoverRenderModelFactory(
            copy: MainPopoverCopy(
                placeholderDateText: "Today",
                checkedInSummaryPrefix: "Checked in at",
                currentSessionPlaceholderText: "--:--:--",
                timePlaceholderText: "--:--",
                totalPlaceholderText: "--",
                currentSessionTitle: "SESSION",
                currentSessionLeadingCaption: "START",
                startTimeTitle: "In",
                endTimeTitle: "Out",
                deleteActionTitle: "Delete",
                weeklyTitle: "Week",
                monthlyTitle: "Month",
                currentSessionGoalLabelPrefix: "Target"
            )
        )

        let renderModel = factory.make(
            viewState: placeholderState,
            currentSession: MainPopoverCurrentSessionRenderModel(
                titleText: "SESSION",
                valueText: "00:00:00",
                leadingCaptionText: "START",
                trailingCaptionText: "Target 8h",
                progressFraction: 0
            ),
            todayTimes: MainPopoverTodayTimesRenderModel(
                startRow: MainPopoverTimeRowRenderModel(
                    titleText: "In",
                    valueText: "--:--",
                    isValueVisible: true,
                    isPickerVisible: false,
                    pickerDateValue: Date(timeIntervalSince1970: 0)
                ),
                endRow: MainPopoverTimeRowRenderModel(
                    titleText: "Out",
                    valueText: "--:--",
                    isValueVisible: true,
                    isPickerVisible: false,
                    pickerDateValue: Date(timeIntervalSince1970: 0)
                ),
                showsEditingActions: false,
                showsStartActions: false,
                showsEndActions: false,
                showsEndDeleteAction: false,
                isApplyEnabled: false
            )
        )

        #expect(renderModel.summary.weekly.titleText == "Week")
        #expect(renderModel.summary.monthly.titleText == "Month")
    }
}
