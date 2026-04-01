import AppKit
import Testing
@testable import WorkPulse

@Suite("MainPopoverSectionViews")
struct MainPopoverSectionViewsTests {
    @Test
    @MainActor
    func todayTimesSectionUsesFullWidthBackground() {
        let section = MainPopoverTodayTimesSectionView(frame: NSRect(x: 0, y: 0, width: 392, height: 146))

        section.layoutSubtreeIfNeeded()

        #expect(section.backgroundView.frame.minX == section.bounds.minX)
        #expect(section.backgroundView.frame.maxX == section.bounds.maxX)
    }

    @Test
    @MainActor
    func editingActionsStayOutsideTheValuePills() {
        let section = MainPopoverTodayTimesSectionView(frame: NSRect(x: 0, y: 0, width: 392, height: 146))
        let renderModel = MainPopoverTodayTimesRenderModel(
            startRow: MainPopoverTimeRowRenderModel(
                titleText: "Start Time",
                valueText: "08:45",
                isValueVisible: false,
                isPickerVisible: true,
                pickerDateValue: Date(timeIntervalSince1970: 0)
            ),
            endRow: MainPopoverTimeRowRenderModel(
                titleText: "End Time",
                valueText: "--:--",
                isValueVisible: true,
                isPickerVisible: false,
                pickerDateValue: Date(timeIntervalSince1970: 0)
            ),
            showsEditingActions: true,
            showsStartActions: true,
            showsEndActions: false,
            isApplyEnabled: true
        )

        section.apply(renderModel)

        #expect(section.editingActionRow.isDescendant(of: section.startRowView.valuePillView) == false)
        #expect(section.editingActionRow.isDescendant(of: section.endRowView.valuePillView) == false)
    }

    @Test
    @MainActor
    func summarySectionPreservesTwoColumnStructureAndTrailingAlignment() {
        let section = MainPopoverSummarySectionView(frame: NSRect(x: 0, y: 0, width: 392, height: 90))
        let renderModel = MainPopoverSummaryRenderModel(
            weekly: MainPopoverSummaryItemRenderModel(titleText: "This Week", valueText: "132:59"),
            monthly: MainPopoverSummaryItemRenderModel(titleText: "This Month", valueText: "9:05")
        )

        section.apply(renderModel)
        section.layoutSubtreeIfNeeded()

        #expect(section.columnsRow.arrangedSubviews.count == 3)
        #expect(section.columnsRow.arrangedSubviews[0] === section.weeklyColumn)
        #expect(section.columnsRow.arrangedSubviews[2] === section.monthlyColumn)
        #expect(section.weeklyColumn.alignment == .leading)
        #expect(section.monthlyColumn.alignment == .trailing)
        #expect(section.monthlyTitleLabel.alignment == .right)
        #expect(section.monthlyValueLabel.alignment == .right)
    }

    @Test
    @MainActor
    func progressBarKeepsVisibleTrackAtZeroFill() {
        let progressBar = CurrentSessionProgressBarView(frame: NSRect(x: 0, y: 0, width: 280, height: 10))
        progressBar.progressFraction = 0
        progressBar.layoutSubtreeIfNeeded()

        #expect(progressBar.trackBorderWidth > 0)
    }
}
