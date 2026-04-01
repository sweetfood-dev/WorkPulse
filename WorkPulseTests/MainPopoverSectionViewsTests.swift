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

        #expect(section.snapshot.isBackgroundFullWidth)
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
        let snapshot = section.snapshot

        #expect(snapshot.areEditingActionsOutsideValuePills)
    }

    @Test
    @MainActor
    func todayTimesSectionAppliesReadOnlyValueTexts() {
        let section = MainPopoverTodayTimesSectionView(frame: NSRect(x: 0, y: 0, width: 392, height: 146))
        let renderModel = MainPopoverTodayTimesRenderModel(
            startRow: MainPopoverTimeRowRenderModel(
                titleText: "Start Time",
                valueText: "08:45",
                isValueVisible: true,
                isPickerVisible: false,
                pickerDateValue: Date(timeIntervalSince1970: 0)
            ),
            endRow: MainPopoverTimeRowRenderModel(
                titleText: "End Time",
                valueText: "--:--",
                isValueVisible: true,
                isPickerVisible: false,
                pickerDateValue: Date(timeIntervalSince1970: 0)
            ),
            showsEditingActions: false,
            showsStartActions: false,
            showsEndActions: false,
            isApplyEnabled: false
        )

        section.apply(renderModel)
        let snapshot = section.snapshot

        #expect(snapshot.startRow.titleText == "Start Time")
        #expect(snapshot.startRow.valueText == "08:45")
        #expect(snapshot.startRow.isValueVisible)
        #expect(snapshot.endRow.titleText == "End Time")
        #expect(snapshot.endRow.valueText == "--:--")
        #expect(snapshot.endRow.isValueVisible)
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
        let snapshot = section.snapshot

        #expect(snapshot.arrangedSubviewCount == 3)
        #expect(snapshot.isWeeklyColumnLeadingAligned)
        #expect(snapshot.isMonthlyColumnTrailingAligned)
        #expect(snapshot.isMonthlyTextRightAligned)
        #expect(snapshot.weeklyTitleText == "This Week")
        #expect(snapshot.weeklyValueText == "132:59")
        #expect(snapshot.monthlyTitleText == "This Month")
        #expect(snapshot.monthlyValueText == "9:05")
    }

    @Test
    @MainActor
    func progressBarKeepsVisibleTrackAtZeroFill() {
        let progressBar = CurrentSessionProgressBarView(frame: NSRect(x: 0, y: 0, width: 280, height: 10))
        progressBar.progressFraction = 0
        progressBar.layoutSubtreeIfNeeded()

        #expect(progressBar.trackBorderWidth > 0)
    }

    @Test
    @MainActor
    func headerSectionPreservesIconPlacementAndTypographyHierarchy() {
        let section = MainPopoverHeaderSectionView(frame: NSRect(x: 0, y: 0, width: 392, height: 90))
        section.apply(
            MainPopoverHeaderRenderModel(
                dateText: "Wednesday, Apr 1",
                checkedInSummaryText: "Checked in at 08:45"
            )
        )
        let snapshot = section.snapshot

        #expect(snapshot.dateText == "Wednesday, Apr 1")
        #expect(snapshot.checkedInSummaryText == "Checked in at 08:45")
        #expect(snapshot.isDateIconLeading)
        #expect(snapshot.isSettingsIconTrailing)
        #expect(snapshot.isCheckInIconLeading)
        #expect(snapshot.dateFontPointSize > snapshot.checkedInSummaryFontPointSize)
    }

    @Test
    @MainActor
    func currentSessionSectionAppliesTitleHierarchyAndIconPlacement() {
        let section = MainPopoverCurrentSessionSectionView(frame: NSRect(x: 0, y: 0, width: 392, height: 180))
        section.apply(
            MainPopoverCurrentSessionRenderModel(
                titleText: "CURRENT SESSION",
                valueText: "01:26:18",
                leadingCaptionText: "0H",
                trailingCaptionText: "Goal: 8h",
                progressFraction: 0.18
            )
        )
        let snapshot = section.snapshot

        #expect(snapshot.titleText == "CURRENT SESSION")
        #expect(snapshot.valueText == "01:26:18")
        #expect(snapshot.leadingCaptionText == "0H")
        #expect(snapshot.trailingCaptionText == "Goal: 8h")
        #expect(snapshot.isTitleIconLeading)
        #expect(snapshot.valueFontPointSize > snapshot.captionFontPointSize)
        #expect(snapshot.captionRowItemCount == 3)
    }

    @Test
    @MainActor
    func dividerUsesConfiguredProminence() {
        let divider = MainPopoverDividerView(frame: .zero)

        #expect(divider.layer?.backgroundColor == MainPopoverStyle.Colors.divider.cgColor)
    }
}
