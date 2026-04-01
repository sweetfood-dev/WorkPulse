import Foundation
import Testing
@testable import WorkPulse

@Suite("MainPopoverRenderModelFactory")
struct MainPopoverRenderModelFactoryTests {
    private let progressPolicy = MainPopoverCurrentSessionProgressPolicy()
    private let factory = MainPopoverRenderModelFactory(
        progressPolicy: MainPopoverCurrentSessionProgressPolicy()
    )

    @Test
    func usesZeroProgressForPlaceholderSession() {
        let renderModel = factory.make(
            viewState: .placeholder,
            currentSessionText: MainPopoverCopy.english.currentSessionPlaceholderText,
            currentSessionDuration: nil,
            editModeState: TodayTimeEditModeState(),
            fallbackTime: Date(timeIntervalSince1970: 0)
        )

        #expect(renderModel.currentSession.progressFraction == 0)
        #expect(renderModel.currentSession.leadingCaptionText == "0H")
        #expect(renderModel.currentSession.trailingCaptionText == "Goal: 8h")
    }

    @Test
    func clampsOverGoalProgressToVisibleTrackMaximum() {
        let renderModel = factory.make(
            viewState: .placeholder,
            currentSessionText: "09:30:00",
            currentSessionDuration: 9.5 * 60 * 60,
            editModeState: TodayTimeEditModeState(),
            fallbackTime: Date(timeIntervalSince1970: 0)
        )

        #expect(renderModel.currentSession.progressFraction == 0.94)
    }

    @Test
    func startTimeEditingShowsOnlyStartActionsAndPicker() {
        var editModeState = TodayTimeEditModeState()
        let startTime = Date(timeIntervalSince1970: 100)
        let endTime = Date(timeIntervalSince1970: 200)
        editModeState.loadSavedTimes(startTime: startTime, endTime: endTime)
        editModeState.beginEditing(.startTime)

        let renderModel = factory.make(
            viewState: .placeholder,
            currentSessionText: "00:00:00",
            currentSessionDuration: 0,
            editModeState: editModeState,
            fallbackTime: Date(timeIntervalSince1970: 0)
        )

        #expect(renderModel.todayTimes.showsEditingActions)
        #expect(renderModel.todayTimes.showsStartActions)
        #expect(renderModel.todayTimes.showsEndActions == false)
        #expect(renderModel.todayTimes.startRow.isPickerVisible)
        #expect(renderModel.todayTimes.startRow.isValueVisible == false)
        #expect(renderModel.todayTimes.endRow.isPickerVisible == false)
        #expect(renderModel.todayTimes.endRow.isValueVisible)
    }

    @Test
    func invalidDraftDisablesApply() {
        var editModeState = TodayTimeEditModeState()
        let startTime = Date(timeIntervalSince1970: 200)
        let endTime = Date(timeIntervalSince1970: 400)
        editModeState.loadSavedTimes(startTime: startTime, endTime: endTime)
        editModeState.beginEditing(.endTime)
        editModeState.updateDraftEndTime(Date(timeIntervalSince1970: 100))

        let renderModel = factory.make(
            viewState: .placeholder,
            currentSessionText: "00:00:00",
            currentSessionDuration: 0,
            editModeState: editModeState,
            fallbackTime: Date(timeIntervalSince1970: 0)
        )

        #expect(renderModel.todayTimes.isApplyEnabled == false)
    }

    @Test
    func usesInjectedCopyValuesForLabelsAndCaptions() {
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
                weeklyTitle: "Week",
                monthlyTitle: "Month",
                currentSessionGoalLabelPrefix: "Target"
            ),
            progressPolicy: progressPolicy
        )

        let renderModel = factory.make(
            viewState: .placeholder,
            currentSessionText: "00:00:00",
            currentSessionDuration: 0,
            editModeState: TodayTimeEditModeState(),
            fallbackTime: Date(timeIntervalSince1970: 0)
        )

        #expect(renderModel.currentSession.titleText == "SESSION")
        #expect(renderModel.currentSession.leadingCaptionText == "START")
        #expect(renderModel.currentSession.trailingCaptionText == "Target 8h")
        #expect(renderModel.todayTimes.startRow.titleText == "In")
        #expect(renderModel.todayTimes.endRow.titleText == "Out")
        #expect(renderModel.summary.weekly.titleText == "Week")
        #expect(renderModel.summary.monthly.titleText == "Month")
    }

    @Test
    func placeholderCopyCentralizesDefaultText() {
        let copy = MainPopoverCopy(
            placeholderDateText: "Placeholder Day",
            checkedInSummaryPrefix: "Arrived",
            currentSessionPlaceholderText: "00:00:00",
            timePlaceholderText: "--.--",
            totalPlaceholderText: "n/a",
            currentSessionTitle: "SESSION",
            currentSessionLeadingCaption: "0H",
            startTimeTitle: "In",
            endTimeTitle: "Out",
            weeklyTitle: "Week",
            monthlyTitle: "Month",
            currentSessionGoalLabelPrefix: "Goal:"
        )
        let state = MainPopoverViewState.placeholder(copy: copy)

        #expect(state.dateText == "Placeholder Day")
        #expect(state.checkedInSummaryText == "Arrived --.--")
        #expect(state.currentSessionText == "00:00:00")
        #expect(state.startTimeText == "--.--")
        #expect(state.endTimeText == "--.--")
        #expect(state.weeklyTotalText == "n/a")
        #expect(state.monthlyTotalText == "n/a")
    }
}
