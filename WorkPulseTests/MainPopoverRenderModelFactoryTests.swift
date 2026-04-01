import Foundation
import Testing
@testable import WorkPulse

@Suite("MainPopoverRenderModelFactory")
struct MainPopoverRenderModelFactoryTests {
    private let factory = MainPopoverRenderModelFactory(
        currentSessionGoalDuration: MainPopoverStyle.Metrics.currentSessionGoalDuration,
        maximumVisibleProgressFraction: MainPopoverStyle.Metrics.maximumVisibleProgressFraction
    )

    @Test
    func usesZeroProgressForPlaceholderSession() {
        let renderModel = factory.make(
            viewState: .placeholder,
            currentSessionText: MainPopoverViewState.placeholder.currentSessionText,
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
}
