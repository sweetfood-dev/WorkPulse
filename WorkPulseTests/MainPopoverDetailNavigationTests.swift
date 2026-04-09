import Foundation
import Testing
@testable import WorkPulse

@Suite("MainPopoverDetailNavigation")
struct MainPopoverDetailNavigationTests {
    @Test
    @MainActor
    func summarySectionEmitsWeeklyAndMonthlySelections() {
        let section = MainPopoverSummarySectionView()
        var selections: [MainPopoverSummarySelection] = []

        section.onSelect = { selections.append($0) }
        section.simulateSelection(.weekly)
        section.simulateSelection(.monthly)

        #expect(selections.count == 2)
        #expect(selections[0] == .weekly)
        #expect(selections[1] == .monthly)
    }

    @Test
    @MainActor
    func viewControllerShowsWeeklyDetailAndReturnsToMain() {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let weeklyState = MainPopoverWeeklyProgressViewState(
            titleText: "Weekly Progress",
            weekText: "Week 14",
            totalDurationText: "16:00",
            statusText: "8h 45m remaining to 40h",
            progressFraction: 0.4,
            visualState: .normal,
            days: [
                MainPopoverWeeklyProgressDayViewState(
                    dayText: "Mon 30",
                    timeRangeText: "09:00 - 18:00",
                    workedText: "08:00",
                    annotationText: nil,
                    dayCategory: .weekday,
                    progressFraction: 1,
                    isToday: false
                )
            ]
        )

        controller.loadViewIfNeeded()
        controller.showWeeklyDetail(weeklyState)

        #expect(controller.snapshot.isShowingWeeklyDetail)
        #expect(controller.snapshot.weeklyDetail.titleText == "Weekly Progress")
        #expect(controller.snapshot.weeklyDetail.weekText == "Week 14")
        #expect(controller.snapshot.weeklyDetail.statusText == "8h 45m remaining to 40h")
        #expect(controller.snapshot.weeklyDetail.selectedStatusSegment == 0)
        #expect(controller.snapshot.weeklyDetail.progressFraction == 0.4)
        #expect(controller.snapshot.weeklyDetail.dayCount == 1)
        #expect(controller.snapshot.weeklyDetail.isWarningState == false)

        controller.showMainView()

        #expect(controller.snapshot.isShowingWeeklyDetail == false)
    }

    @Test
    @MainActor
    func repeatedWeeklyDetailTransitionsDoNotAccumulateTopInset() {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let weeklyState = MainPopoverWeeklyProgressViewState(
            titleText: "Weekly Progress",
            weekText: "Week 14",
            totalDurationText: "16:00",
            statusText: "8h 45m remaining to 40h",
            progressFraction: 0.4,
            visualState: .normal,
            days: [
                MainPopoverWeeklyProgressDayViewState(
                    dayText: "Mon 30",
                    timeRangeText: "09:00 - 18:00",
                    workedText: "08:00",
                    annotationText: nil,
                    dayCategory: .weekday,
                    progressFraction: 1,
                    isToday: false
                )
            ]
        )

        controller.loadViewIfNeeded()
        let initialSize = controller.preferredContentSize

        for _ in 0..<3 {
            controller.showWeeklyDetail(weeklyState)
            controller.showMainView()
        }

        #expect(controller.preferredContentSize == initialSize)
        #expect(controller.snapshot.isShowingWeeklyDetail == false)
    }

    @Test
    @MainActor
    func weeklyDetailSnapshotCountsOvertimeDays() {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let weeklyState = MainPopoverWeeklyProgressViewState(
            titleText: "Weekly Progress",
            weekText: "Week 14",
            totalDurationText: "33:35",
            statusText: "1h 01m remaining to 40h",
            progressFraction: 0.97,
            visualState: .normal,
            days: makeWeeklyProgressDays()
        )

        controller.loadViewIfNeeded()
        controller.showWeeklyDetail(weeklyState)

        #expect(controller.snapshot.weeklyDetail.overtimeDayCount == 2)
    }

    @Test
    @MainActor
    func weeklyDetailAllowsSwitchingBetweenProgressAndQuitTimeStatuses() {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let weeklyState = MainPopoverWeeklyProgressViewState(
            titleText: "Weekly Progress",
            weekText: "Week 14",
            totalDurationText: "33:35",
            statusText: "1h 01m remaining to 40h",
            quitTimeStatusText: "Quit at 17:10",
            progressFraction: 0.97,
            visualState: .normal,
            days: makeWeeklyProgressDays()
        )

        controller.loadViewIfNeeded()
        controller.showWeeklyDetail(weeklyState)
        controller.simulateSelectWeeklyDetailStatusSegment(at: 1)

        #expect(controller.snapshot.weeklyDetail.selectedStatusSegment == 1)
        #expect(controller.snapshot.weeklyDetail.statusText == "Quit at 17:10")
        #expect(controller.snapshot.weeklyDetail.dayDetailTexts[1] == "08:00 - 17:30")
        #expect(controller.snapshot.weeklyDetail.dayValueTexts[1] == "+00:29")
        #expect(controller.snapshot.weeklyDetail.dayDetailTexts[5] == "08:10 - --:--")
        #expect(controller.snapshot.weeklyDetail.dayValueTexts[5] == "-04:22")

        controller.simulateSelectWeeklyDetailStatusSegment(at: 0)

        #expect(controller.snapshot.weeklyDetail.selectedStatusSegment == 0)
        #expect(controller.snapshot.weeklyDetail.statusText == "1h 01m remaining to 40h")
        #expect(controller.snapshot.weeklyDetail.dayDetailTexts[1] == "08:00 - 17:30")
        #expect(controller.snapshot.weeklyDetail.dayValueTexts[1] == "08:29")
    }

    @Test
    @MainActor
    func routeTransitionsUpdatePreferredSize() {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let weeklyState = MainPopoverWeeklyProgressViewState(
            titleText: "Weekly Progress",
            weekText: "Week 14",
            totalDurationText: "16:00",
            statusText: "8h 45m remaining to 40h",
            progressFraction: 0.4,
            visualState: .normal,
            days: makeWeeklyProgressDays()
        )

        controller.loadViewIfNeeded()
        let initialSize = controller.preferredContentSize
        #expect(initialSize.height >= MainPopoverStyle.Metrics.popoverSize.height)

        controller.showWeeklyDetail(weeklyState)
        #expect(controller.preferredContentSize.height >= MainPopoverStyle.Metrics.popoverSize.height)

        controller.showMainView()
        #expect(controller.preferredContentSize == initialSize)
    }

    @Test
    @MainActor
    func routeTransitionsDoNotAccumulateContainerConstraints() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let weeklyState = MainPopoverWeeklyProgressViewState(
            titleText: "Weekly Progress",
            weekText: "Week 14",
            totalDurationText: "16:00",
            statusText: "8h 45m remaining to 40h",
            progressFraction: 0.4,
            visualState: .normal,
            days: makeWeeklyProgressDays()
        )
        let monthlyState = MonthlyHistoryViewState(
            referenceDate: try #require(makeDate("2026-04-01T00:00:00+09:00")),
            titleText: "MONTHLY HISTORY",
            monthText: "April 2026",
            weekdayTexts: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
            totalLabelText: "Monthly Total",
            totalDurationText: "7h 51m",
            cells: makeMonthlyHistoryCells(dayCount: 35)
        )

        controller.loadViewIfNeeded()
        let mainConstraintCount = controller.routeConstraintCountForTesting
        controller.showWeeklyDetail(weeklyState)
        let weeklyConstraintCount = controller.routeConstraintCountForTesting
        controller.showMonthlyHistory(monthlyState)
        let monthlyConstraintCount = controller.routeConstraintCountForTesting
        controller.showMainView()

        #expect(controller.routeConstraintCountForTesting == mainConstraintCount)

        for _ in 0..<4 {
            controller.showWeeklyDetail(weeklyState)
            #expect(controller.routeConstraintCountForTesting == weeklyConstraintCount)
            controller.showMonthlyHistory(monthlyState)
            #expect(controller.routeConstraintCountForTesting == monthlyConstraintCount)
            controller.showMainView()
            #expect(controller.routeConstraintCountForTesting == mainConstraintCount)
        }
    }

    @Test
    @MainActor
    func returningToMainAfterTallWeeklyEditorRestoresBaseHeight() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let weeklyState = MainPopoverWeeklyProgressViewState(
            titleText: "Weekly Progress",
            weekText: "Week 14",
            totalDurationText: "16:00",
            statusText: "8h 45m remaining to 40h",
            progressFraction: 0.4,
            visualState: .normal,
            days: makeWeeklyProgressDays()
        )
        let editorState = MainPopoverDetailDayEditingState(
            referenceDate: try #require(makeDate("2026-03-31T00:00:00+09:00")),
            dateText: "Tuesday, Mar 31",
            startTimeText: "08:24",
            endTimeText: "17:30",
            startTime: try #require(makeDate("2026-03-31T08:24:00+09:00")),
            endTime: try #require(makeDate("2026-03-31T17:30:00+09:00")),
            fallbackStartTime: try #require(makeDate("2026-03-31T08:24:00+09:00")),
            fallbackEndTime: try #require(makeDate("2026-03-31T17:30:00+09:00"))
        )

        controller.loadViewIfNeeded()
        let initialSize = controller.preferredContentSize
        controller.showWeeklyDetail(weeklyState, editorState: editorState)
        #expect(controller.preferredContentSize.height > MainPopoverStyle.Metrics.popoverSize.height)

        controller.showMainView()

        #expect(controller.preferredContentSize == initialSize)
        #expect(controller.view.frame.size == initialSize)
    }

    @Test
    @MainActor
    func returningToMainAfterTallMonthlyEditorRestoresBaseHeight() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let monthlyState = MonthlyHistoryViewState(
            referenceDate: try #require(makeDate("2026-04-01T00:00:00+09:00")),
            titleText: "MONTHLY HISTORY",
            monthText: "April 2026",
            weekdayTexts: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
            totalLabelText: "Monthly Total",
            totalDurationText: "7h 51m",
            cells: makeMonthlyHistoryCells(dayCount: 35)
        )
        let editorState = MainPopoverDetailDayEditingState(
            referenceDate: try #require(makeDate("2026-04-02T00:00:00+09:00")),
            dateText: "Thursday, Apr 2",
            startTimeText: "08:10",
            endTimeText: "--:--",
            startTime: try #require(makeDate("2026-04-02T08:10:00+09:00")),
            endTime: nil,
            fallbackStartTime: try #require(makeDate("2026-04-02T08:10:00+09:00")),
            fallbackEndTime: try #require(makeDate("2026-04-02T18:00:00+09:00"))
        )

        controller.loadViewIfNeeded()
        let initialSize = controller.preferredContentSize
        controller.showMonthlyHistory(monthlyState, editorState: editorState)
        #expect(controller.preferredContentSize.height > MainPopoverStyle.Metrics.popoverSize.height)

        controller.showMainView()

        #expect(controller.preferredContentSize == initialSize)
        #expect(controller.view.frame.size == initialSize)
    }

    @Test
    @MainActor
    func viewControllerEmitsSelectedDetailDateFromWeeklyDetail() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let selectedDate = try #require(makeDate("2026-03-31T00:00:00+09:00"))
        var selection: (surface: MainPopoverDetailSurface, date: Date)?

        controller.onSelectDetailDate = { selection = ($0, $1) }
        controller.loadViewIfNeeded()
        controller.showWeeklyDetail(
            MainPopoverWeeklyProgressViewState(
                titleText: "Weekly Progress",
                weekText: "Week 14",
                totalDurationText: "16:00",
                statusText: "24h 00m remaining to 40h",
                progressFraction: 0.4,
                visualState: .normal,
                days: [
                    MainPopoverWeeklyProgressDayViewState(
                        date: selectedDate,
                        dayText: "Tue 31",
                        timeRangeText: "09:00 - 18:00",
                        workedText: "08:00",
                        annotationText: nil,
                        dayCategory: .weekday,
                        progressFraction: 1,
                        isToday: false,
                        isSelectable: true
                    )
                ]
            )
        )

        controller.simulateSelectWeeklyDetailDay(at: 0)

        #expect(selection?.surface == .weekly)
        #expect(selection?.date == selectedDate)
    }

    @Test
    @MainActor
    func viewControllerShowsInlineEditorWithinWeeklyDetail() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )

        controller.loadViewIfNeeded()
        controller.showWeeklyDetail(
            MainPopoverWeeklyProgressViewState(
                titleText: "Weekly Progress",
                weekText: "Week 14",
                totalDurationText: "16:00",
                statusText: "24h 00m remaining to 40h",
                progressFraction: 0.4,
                visualState: .normal,
                days: []
            ),
            editorState: MainPopoverDetailDayEditingState(
                referenceDate: try #require(makeDate("2026-03-31T00:00:00+09:00")),
                dateText: "Tuesday, Mar 31",
                startTimeText: "09:00",
                endTimeText: "--:--",
                startTime: try #require(makeDate("2026-03-31T09:00:00+09:00")),
                endTime: nil,
                fallbackStartTime: try #require(makeDate("2026-03-31T09:00:00+09:00")),
                fallbackEndTime: try #require(makeDate("2026-03-31T18:00:00+09:00"))
            )
        )

        #expect(controller.snapshot.isShowingWeeklyDetail)
        #expect(controller.snapshot.weeklyDetail.isShowingEditor)
        #expect(controller.snapshot.weeklyDetail.editorDateText == "Tuesday, Mar 31")
    }

    @Test
    @MainActor
    func weeklyInlineEditorDoesNotAccumulatePopoverHeightAcrossSelections() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let weeklyState = MainPopoverWeeklyProgressViewState(
            titleText: "Weekly Progress",
            weekText: "Week 14",
            totalDurationText: "16:00",
            statusText: "24h 00m remaining to 40h",
            progressFraction: 0.4,
            visualState: .normal,
            days: makeWeeklyProgressDays()
        )
        let firstEditorState = MainPopoverDetailDayEditingState(
            referenceDate: try #require(makeDate("2026-03-31T00:00:00+09:00")),
            dateText: "Tuesday, Mar 31",
            startTimeText: "08:24",
            endTimeText: "17:30",
            startTime: try #require(makeDate("2026-03-31T08:24:00+09:00")),
            endTime: try #require(makeDate("2026-03-31T17:30:00+09:00")),
            fallbackStartTime: try #require(makeDate("2026-03-31T08:24:00+09:00")),
            fallbackEndTime: try #require(makeDate("2026-03-31T17:30:00+09:00"))
        )
        let secondEditorState = MainPopoverDetailDayEditingState(
            referenceDate: try #require(makeDate("2026-04-01T00:00:00+09:00")),
            dateText: "Wednesday, Apr 1",
            startTimeText: "08:45",
            endTimeText: "17:36",
            startTime: try #require(makeDate("2026-04-01T08:45:00+09:00")),
            endTime: try #require(makeDate("2026-04-01T17:36:00+09:00")),
            fallbackStartTime: try #require(makeDate("2026-04-01T08:45:00+09:00")),
            fallbackEndTime: try #require(makeDate("2026-04-01T17:36:00+09:00"))
        )

        controller.loadViewIfNeeded()
        controller.showWeeklyDetail(weeklyState, editorState: firstEditorState)
        let firstHeight = controller.preferredContentSize.height

        controller.showWeeklyDetail(weeklyState, editorState: secondEditorState)
        let secondHeight = controller.preferredContentSize.height

        #expect(firstHeight == secondHeight)
    }

    @Test
    @MainActor
    func viewControllerShowsMonthlyDetailNavigatesMonthsAndReturnsToMain() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        var navigations: [Int] = []

        controller.onNavigateMonthlyHistory = { navigations.append($0) }
        controller.loadViewIfNeeded()
        controller.showMonthlyHistory(
            MonthlyHistoryViewState(
                referenceDate: try #require(makeDate("2026-04-01T00:00:00+09:00")),
                titleText: "MONTHLY HISTORY",
                monthText: "April 2026",
                weekdayTexts: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                totalLabelText: "Monthly Total",
                totalDurationText: "7h 51m",
                cells: [
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "1", statusText: "7h 51m", annotationText: nil, activity: .worked, dayCategory: .weekday, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "2", statusText: "Active", annotationText: "어린이날", activity: .active, dayCategory: .holiday, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "3", statusText: "—", annotationText: nil, activity: .empty, dayCategory: .weekday, isDimmed: true),
                    MonthlyHistoryDayCellViewState(dayText: "4", statusText: "Off", annotationText: nil, activity: .empty, dayCategory: .weekend, isDimmed: true),
                ]
            )
        )

        #expect(controller.snapshot.isShowingMonthlyDetail)
        #expect(controller.snapshot.monthlyDetail.monthText == "April 2026")
        #expect(controller.snapshot.monthlyDetail.activeCellCount == 1)
        #expect(controller.snapshot.monthlyDetail.annotationTexts == ["어린이날"])

        controller.simulateMonthlyNavigatePrevious()
        controller.simulateMonthlyNavigateNext()
        #expect(navigations == [-1, 1])

        controller.showMainView()
        #expect(controller.snapshot.isShowingMonthlyDetail == false)
    }

    @Test
    @MainActor
    func viewControllerEmitsSelectedDetailDateFromMonthlyDetail() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let selectedDate = try #require(makeDate("2026-04-02T00:00:00+09:00"))
        var selection: (surface: MainPopoverDetailSurface, date: Date)?

        controller.onSelectDetailDate = { selection = ($0, $1) }
        controller.loadViewIfNeeded()
        controller.showMonthlyHistory(
            MonthlyHistoryViewState(
                referenceDate: try #require(makeDate("2026-04-01T00:00:00+09:00")),
                titleText: "MONTHLY HISTORY",
                monthText: "April 2026",
                weekdayTexts: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                totalLabelText: "Monthly Total",
                totalDurationText: "7h 51m",
                cells: [
                    MonthlyHistoryDayCellViewState(
                        dayText: "",
                        statusText: "",
                        annotationText: nil,
                        activity: .outsideMonth,
                        dayCategory: .weekday,
                        isDimmed: false,
                        isSelectable: false
                    ),
                    MonthlyHistoryDayCellViewState(
                        date: selectedDate,
                        dayText: "2",
                        statusText: "Active",
                        annotationText: nil,
                        activity: .active,
                        dayCategory: .weekday,
                        isDimmed: false,
                        isSelectable: true
                    ),
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false, isSelectable: false),
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false, isSelectable: false),
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false, isSelectable: false),
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false, isSelectable: false),
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false, isSelectable: false),
                ]
            )
        )

        controller.simulateSelectMonthlyDetailDay(at: 1)

        #expect(selection?.surface == .monthly)
        #expect(selection?.date == selectedDate)
    }

    @Test
    @MainActor
    func viewControllerShowsInlineEditorWithinMonthlyDetail() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )

        controller.loadViewIfNeeded()
        controller.showMonthlyHistory(
            MonthlyHistoryViewState(
                referenceDate: try #require(makeDate("2026-04-01T00:00:00+09:00")),
                titleText: "MONTHLY HISTORY",
                monthText: "April 2026",
                weekdayTexts: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                totalLabelText: "Monthly Total",
                totalDurationText: "7h 51m",
                cells: []
            ),
            editorState: MainPopoverDetailDayEditingState(
                referenceDate: try #require(makeDate("2026-04-02T00:00:00+09:00")),
                dateText: "Thursday, Apr 2",
                startTimeText: "08:10",
                endTimeText: "--:--",
                startTime: try #require(makeDate("2026-04-02T08:10:00+09:00")),
                endTime: nil,
                fallbackStartTime: try #require(makeDate("2026-04-02T08:10:00+09:00")),
                fallbackEndTime: try #require(makeDate("2026-04-02T18:00:00+09:00"))
            )
        )

        #expect(controller.snapshot.isShowingMonthlyDetail)
        #expect(controller.snapshot.monthlyDetail.isShowingEditor)
        #expect(controller.snapshot.monthlyDetail.editorDateText == "Thursday, Apr 2")
    }

    @Test
    @MainActor
    func monthlyInlineEditorDoesNotAccumulatePopoverHeightAcrossSelections() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )
        let monthlyState = MonthlyHistoryViewState(
            referenceDate: try #require(makeDate("2026-04-01T00:00:00+09:00")),
            titleText: "MONTHLY HISTORY",
            monthText: "April 2026",
            weekdayTexts: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
            totalLabelText: "Monthly Total",
            totalDurationText: "7h 51m",
            cells: makeMonthlyHistoryCells(dayCount: 35)
        )
        let firstEditorState = MainPopoverDetailDayEditingState(
            referenceDate: try #require(makeDate("2026-04-02T00:00:00+09:00")),
            dateText: "Thursday, Apr 2",
            startTimeText: "08:10",
            endTimeText: "--:--",
            startTime: try #require(makeDate("2026-04-02T08:10:00+09:00")),
            endTime: nil,
            fallbackStartTime: try #require(makeDate("2026-04-02T08:10:00+09:00")),
            fallbackEndTime: try #require(makeDate("2026-04-02T18:00:00+09:00"))
        )
        let secondEditorState = MainPopoverDetailDayEditingState(
            referenceDate: try #require(makeDate("2026-04-03T00:00:00+09:00")),
            dateText: "Friday, Apr 3",
            startTimeText: "08:24",
            endTimeText: "17:30",
            startTime: try #require(makeDate("2026-04-03T08:24:00+09:00")),
            endTime: try #require(makeDate("2026-04-03T17:30:00+09:00")),
            fallbackStartTime: try #require(makeDate("2026-04-03T08:24:00+09:00")),
            fallbackEndTime: try #require(makeDate("2026-04-03T17:30:00+09:00"))
        )

        controller.loadViewIfNeeded()
        controller.showMonthlyHistory(monthlyState, editorState: firstEditorState)
        let firstHeight = controller.preferredContentSize.height

        controller.showMonthlyHistory(monthlyState, editorState: secondEditorState)
        let secondHeight = controller.preferredContentSize.height

        #expect(firstHeight == secondHeight)
    }

    @Test
    @MainActor
    func viewControllerExpandsPopoverForSixWeekMonthlyDetail() throws {
        let controller = MainPopoverViewController(
            state: MainPopoverViewStateFactory(copy: .english).makePlaceholder(),
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )

        controller.loadViewIfNeeded()
        controller.showMonthlyHistory(
            MonthlyHistoryViewState(
                referenceDate: try #require(makeDate("2026-05-01T00:00:00+09:00")),
                titleText: "MONTHLY HISTORY",
                monthText: "May 2026",
                weekdayTexts: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                totalLabelText: "Monthly Total",
                totalDurationText: "0h 00m",
                cells: Array(
                    repeating: MonthlyHistoryDayCellViewState(
                        dayText: "1",
                        statusText: "—",
                        annotationText: nil,
                        activity: .empty,
                        dayCategory: .weekday,
                        isDimmed: false
                    ),
                    count: 42
                )
            )
        )

        #expect(controller.snapshot.isShowingMonthlyDetail)
        #expect(controller.snapshot.monthlyDetail.cellCount == 42)
        #expect(controller.preferredContentSize.height > MainPopoverStyle.Metrics.popoverSize.height)
    }
}

@Suite("MainPopoverDetailLoaders")
struct MainPopoverDetailLoadersTests {
    @Test
    func weeklyProgressLoaderBuildsWeeklyCardAndDailyRows() throws {
        let referenceDate = try #require(
            makeDate("2026-04-01T12:00:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-03-30T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-03-30T09:00:00+09:00")),
                endTime: try #require(makeDate("2026-03-30T18:00:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-03-31T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-03-31T09:00:00+09:00")),
                endTime: try #require(makeDate("2026-03-31T18:00:00+09:00"))
            )
        ])
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        #expect(state.titleText == "Weekly Progress")
        #expect(state.weekText == "Week 14")
        #expect(state.totalDurationText == "16:00")
        #expect(state.statusText == "24h 00m remaining to 40h")
        #expect(state.quitTimeStatusText == "No check-in record")
        #expect(state.todayDeltaStatusText == "Through today: On track")
        #expect(state.todayDeltaVisualState == .neutral)
        #expect(state.progressFraction == 0.4)
        #expect(state.visualState == .normal)
        #expect(state.days.count == 7)
        #expect(state.days[1].timeRangeText == "09:00 - 18:00")
        #expect(state.days[1].workedText == "08:00")
        #expect(state.days[1].quitDeltaText == "00:00")
    }

    @Test
    func weeklyProgressLoaderIncludesInProgressTodayInTotal() throws {
        let referenceDate = try #require(
            makeDate("2026-04-01T12:00:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-03-30T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-03-30T09:00:00+09:00")),
                endTime: try #require(makeDate("2026-03-30T18:00:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-01T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-01T09:00:00+09:00")),
                endTime: nil
            )
        ])
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        #expect(state.weekText == "Week 14")
        #expect(state.totalDurationText == "11:00")
        #expect(state.statusText == "29h 00m remaining to 40h")
        #expect(state.quitTimeStatusText == "Quit at 18:00")
        #expect(state.todayDeltaStatusText == "Through today: 8h 00m remaining")
        #expect(state.todayDeltaVisualState == .remaining)
        #expect(state.progressFraction > 0.27)
        #expect(state.progressFraction < 0.28)
        #expect(state.visualState == .normal)
        #expect(state.days.first(where: { $0.isToday })?.timeRangeText == "09:00 - --:--")
        #expect(state.days.first(where: { $0.isToday })?.workedText == "03:00")
        #expect(state.days.first(where: { $0.isToday })?.quitDeltaText == "-05:00")
    }

    @Test
    func weeklyProgressLoaderKeepsPriorOvertimeWhileTodayIsStillInProgress() throws {
        let referenceDate = try #require(
            makeDate("2026-04-09T12:13:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-04-06T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-06T07:40:00+09:00")),
                endTime: try #require(makeDate("2026-04-06T17:00:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-07T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-07T08:05:00+09:00")),
                endTime: try #require(makeDate("2026-04-07T17:31:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-08T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-08T08:15:00+09:00")),
                endTime: try #require(makeDate("2026-04-08T17:30:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-09T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-09T09:48:00+09:00")),
                endTime: nil
            ),
        ])
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        #expect(state.todayDeltaStatusText == "Through today: 1h 01m Overtime")
        #expect(state.todayDeltaVisualState == .overtime)
    }

    @Test
    func weeklyProgressLoaderCountsWeekendWorkInThroughTodayDelta() throws {
        let referenceDate = try #require(
            makeDate("2026-04-08T12:00:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-04-05T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-05T09:00:00+09:00")),
                endTime: try #require(makeDate("2026-04-05T13:00:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-06T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-06T08:00:00+09:00")),
                endTime: try #require(makeDate("2026-04-06T17:00:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-07T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-07T08:00:00+09:00")),
                endTime: try #require(makeDate("2026-04-07T17:00:00+09:00"))
            )
        ])
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        #expect(state.todayDeltaStatusText == "Through today: 3h 00m Overtime")
        #expect(state.todayDeltaVisualState == .overtime)
    }

    @Test
    func weeklyProgressLoaderShowsFullDeficitForZeroWorkedDay() throws {
        let referenceDate = try #require(
            makeDate("2026-04-01T12:00:00+09:00")
        )
        let startTime = try #require(makeDate("2026-03-31T09:00:00+09:00"))
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-03-31T00:00:00+09:00")),
                startTime: startTime,
                endTime: startTime
            )
        ])
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        #expect(state.days[2].timeRangeText == "09:00 - 09:00")
        #expect(state.days[2].workedText == "--")
        #expect(state.days[2].quitDeltaText == "-08:00")
    }

    @Test
    func monthlyHistoryLoaderSortsNewestFirstAndMarksInProgressRows() throws {
        let referenceDate = try #require(
            makeDate("2026-04-02T10:00:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-04-01T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-01T09:00:00+09:00")),
                endTime: nil
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-02T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-02T08:45:00+09:00")),
                endTime: nil
            )
        ])
        let loader = MonthlyHistoryLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        #expect(state.titleText == "MONTHLY HISTORY")
        #expect(state.monthText == "April 2026")
        #expect(state.totalLabelText == "Monthly Total")
        #expect(state.totalDurationText == "0h 00m")
        #expect(state.weekdayTexts == ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        #expect(state.cells.count == 35)
        #expect(state.cells.first(where: { $0.dayText == "1" })?.activity == .empty)
        #expect(state.cells.first(where: { $0.dayText == "2" })?.activity == .active)
        #expect(state.cells.first(where: { $0.dayText == "2" })?.statusText == "Active")
        #expect(state.cells.first(where: { $0.dayText == "4" })?.dayCategory == .weekend)
    }

    @Test
    func monthlyHistoryLoaderKeepsWeekendWorkAndAddsHolidayAnnotations() throws {
        let referenceDate = try #require(
            makeDate("2025-05-06T10:00:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2025-05-03T00:00:00+09:00")),
                startTime: try #require(makeDate("2025-05-03T09:00:00+09:00")),
                endTime: try #require(makeDate("2025-05-03T18:00:00+09:00"))
            )
        ])
        let loader = MonthlyHistoryLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        let weekendWorkedCell = try #require(state.cells.first(where: { $0.dayText == "3" }))
        let holidayCell = try #require(state.cells.first(where: { $0.dayText == "5" }))
        let substituteCell = try #require(state.cells.first(where: { $0.dayText == "6" }))

        #expect(weekendWorkedCell.activity == .worked)
        #expect(weekendWorkedCell.dayCategory == .weekend)
        #expect(holidayCell.dayCategory == .holiday)
        #expect(holidayCell.annotationText?.contains("어린이날") == true)
        #expect(substituteCell.dayCategory == .substituteHoliday)
        #expect(substituteCell.annotationText?.contains("대체공휴일") == true)
    }

    @Test
    func monthlyHistoryLoaderUsesRuntimeTimezoneForHolidayMetadata() throws {
        let referenceDate = try #require(
            makeDate("2026-03-02T12:00:00+11:00")
        )
        let sydneyTimeZone = try #require(TimeZone(identifier: "Australia/Sydney"))
        let loader = MonthlyHistoryLoader(
            recordStore: DetailTestAttendanceRecordStore(records: []),
            calendar: makeCalendar(timeZone: sydneyTimeZone),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: sydneyTimeZone,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)
        let substituteCell = try #require(state.cells.first(where: { $0.dayText == "2" }))

        #expect(substituteCell.dayCategory == .substituteHoliday)
        #expect(substituteCell.annotationText?.contains("대체공휴일") == true)
        #expect(substituteCell.annotationText?.contains("3·1절") == true)
    }

    @Test
    func monthlyHistoryLoaderMarksEightHourDaysAsOvertime() throws {
        let referenceDate = try #require(
            makeDate("2026-04-02T12:00:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-04-02T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-02T08:22:00+09:00")),
                endTime: try #require(makeDate("2026-04-02T18:31:00+09:00"))
            ),
        ])
        let loader = MonthlyHistoryLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)
        let overtimeCell = try #require(state.cells.first(where: { $0.dayText == "2" }))

        #expect(overtimeCell.isOvertime)
    }

    @Test
    func weeklyProgressLoaderAnnotatesHolidayRowsWithoutChangingTotals() throws {
        let referenceDate = try #require(
            makeDate("2026-03-02T12:00:00+09:00")
        )
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: DetailTestAttendanceRecordStore(records: []),
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        #expect(state.totalDurationText == "00:00")
        #expect(state.days.first(where: { $0.annotationText?.contains("3·1절") == true })?.dayCategory == .holiday)
        #expect(state.days.first(where: { $0.annotationText?.contains("대체공휴일") == true })?.dayCategory == .substituteHoliday)
    }

    @Test
    func weeklyProgressLoaderUsesRuntimeTimezoneForHolidayMetadata() throws {
        let referenceDate = try #require(
            makeDate("2026-03-02T12:00:00+11:00")
        )
        let sydneyTimeZone = try #require(TimeZone(identifier: "Australia/Sydney"))
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: DetailTestAttendanceRecordStore(records: []),
            calendar: makeCalendar(timeZone: sydneyTimeZone),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: sydneyTimeZone,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)
        let mondayState = try #require(state.days.first(where: { $0.dayText.contains("Mon 2") }))

        #expect(mondayState.dayCategory == .substituteHoliday)
        #expect(mondayState.annotationText?.contains("대체공휴일") == true)
        #expect(mondayState.annotationText?.contains("3·1절") == true)
    }

    @Test
    func weeklyProgressLoaderMarksEightHourDaysAsOvertime() throws {
        let referenceDate = try #require(
            makeDate("2026-04-02T12:00:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-04-02T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-02T08:22:00+09:00")),
                endTime: try #require(makeDate("2026-04-02T18:31:00+09:00"))
            ),
        ])
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)
        let overtimeDay = try #require(state.days.first(where: { $0.dayText == "Thu 2" }))

        #expect(overtimeDay.isOvertime)
        #expect(overtimeDay.progressFraction == 1)
    }

    @Test
    func weeklyProgressLoaderFillsTopProgressWhenWeekExceedsGoal() throws {
        let referenceDate = try #require(
            makeDate("2026-04-03T20:00:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-03-30T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-03-30T08:00:00+09:00")),
                endTime: try #require(makeDate("2026-03-30T18:30:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-03-31T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-03-31T08:00:00+09:00")),
                endTime: try #require(makeDate("2026-03-31T18:30:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-01T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-01T08:00:00+09:00")),
                endTime: try #require(makeDate("2026-04-01T18:30:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-02T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-02T08:00:00+09:00")),
                endTime: try #require(makeDate("2026-04-02T18:30:00+09:00"))
            ),
            AttendanceRecord(
                date: try #require(makeDate("2026-04-03T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-03T08:00:00+09:00")),
                endTime: try #require(makeDate("2026-04-03T18:30:00+09:00"))
            ),
        ])
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        #expect(state.totalDurationText == "42:30")
        #expect(state.statusText == "2h 30m Overtime")
        #expect(state.quitTimeStatusText == "Checked out 18:30")
        #expect(state.todayDeltaStatusText == "Through today: 2h 30m Overtime")
        #expect(state.todayDeltaVisualState == .overtime)
        #expect(state.progressFraction == 1)
        #expect(state.visualState == .warning)
        #expect(state.days[1].quitDeltaText == "+01:30")
    }

    @Test
    func weeklyProgressLoaderShowsCanLeaveSinceForTodayAfterEarliestQuitTime() throws {
        let referenceDate = try #require(
            makeDate("2026-04-03T18:30:00+09:00")
        )
        let store = DetailTestAttendanceRecordStore(records: [
            AttendanceRecord(
                date: try #require(makeDate("2026-04-03T00:00:00+09:00")),
                startTime: try #require(makeDate("2026-04-03T08:00:00+09:00")),
                endTime: nil
            ),
        ])
        let loader = MainPopoverWeeklyProgressLoader(
            recordStore: store,
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "Asia/Seoul")!,
            currentDateProvider: { referenceDate }
        )

        let state = loader.load(referenceDate: referenceDate)

        #expect(state.quitTimeStatusText == "Can leave since 17:00")
    }

    @Test
    @MainActor
    func monthlyHistoryViewControllerAppliesCalendarGridAndNavigation() throws {
        let controller = MonthlyHistoryViewController()
        var navigations: [Int] = []
        let longHolidayName = "부처님오신날 대체공휴일"

        controller.onNavigatePrevious = { navigations.append(-1) }
        controller.onNavigateNext = { navigations.append(1) }
        controller.loadViewIfNeeded()
        controller.apply(
            MonthlyHistoryViewState(
                referenceDate: try #require(makeDate("2026-04-01T00:00:00+09:00")),
                titleText: "MONTHLY HISTORY",
                monthText: "April 2026",
                weekdayTexts: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                totalLabelText: "Monthly Total",
                totalDurationText: "9h 06m",
                cells: [
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "", statusText: "", annotationText: nil, activity: .outsideMonth, dayCategory: .weekday, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "1", statusText: "7h 51m", annotationText: nil, activity: .worked, dayCategory: .weekday, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "2", statusText: "Active", annotationText: longHolidayName, activity: .active, dayCategory: .holiday, isOvertime: true, isDimmed: false),
                    MonthlyHistoryDayCellViewState(dayText: "3", statusText: "—", annotationText: nil, activity: .empty, dayCategory: .weekday, isDimmed: true),
                    MonthlyHistoryDayCellViewState(dayText: "4", statusText: "Off", annotationText: nil, activity: .empty, dayCategory: .weekend, isDimmed: true),
                ]
            )
        )

        controller.simulateNavigatePrevious()
        controller.simulateNavigateNext()

        #expect(controller.snapshot.monthText == "April 2026")
        #expect(controller.snapshot.totalDurationText == "9h 06m")
        #expect(controller.snapshot.weekdayCount == 7)
        #expect(controller.snapshot.cellCount == 7)
        #expect(controller.snapshot.workedCellCount == 1)
        #expect(controller.snapshot.activeCellCount == 1)
        #expect(controller.snapshot.overtimeCellCount == 1)
        #expect(controller.snapshot.annotationTexts == [longHolidayName])
        #expect(controller.snapshot.rowWidths.count == 1)
        #expect(controller.snapshot.rowWidths.first ?? 0 > 0)
        #expect(controller.snapshot.hasOverflowingAnnotationLayout == false)
        #expect(navigations == [-1, 1])
    }
}

private struct DetailTestAttendanceRecordStore: AttendanceRecordStore {
    let records: [AttendanceRecord]

    func record(on date: Date, calendar: Calendar) -> AttendanceRecord? {
        records.last { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func records(equalTo date: Date, toGranularity granularity: Calendar.Component, calendar: Calendar) -> [AttendanceRecord] {
        records.filter { calendar.isDate($0.date, equalTo: date, toGranularity: granularity) }
    }

    func upsertRecord(_ record: AttendanceRecord) throws {
        Issue.record("upsertRecord should not be called in detail loader tests")
    }
}

private func makeDate(_ value: String) -> Date? {
    ISO8601DateFormatter().date(from: value)
}

private func makeSeoulCalendar() -> Calendar {
    makeCalendar(timeZone: TimeZone(identifier: "Asia/Seoul")!)
}

private func makeCalendar(timeZone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.locale = Locale(identifier: "ko_KR")
    return calendar
}

private func makeWeeklyProgressDays() -> [MainPopoverWeeklyProgressDayViewState] {
    [
        MainPopoverWeeklyProgressDayViewState(
            date: makeDate("2026-03-29T00:00:00+09:00")!,
            dayText: "Sun 29",
            timeRangeText: "—:— - —:—",
            workedText: "--",
            quitDeltaText: "--",
            annotationText: nil,
            dayCategory: .weekend,
            progressFraction: 0,
            isToday: false,
            isSelectable: true
        ),
        MainPopoverWeeklyProgressDayViewState(
            date: makeDate("2026-03-30T00:00:00+09:00")!,
            dayText: "Mon 30",
            timeRangeText: "08:00 - 17:30",
            workedText: "08:29",
            quitDeltaText: "+00:29",
            annotationText: nil,
            dayCategory: .weekday,
            isOvertime: true,
            progressFraction: 1,
            isToday: false,
            isSelectable: true
        ),
        MainPopoverWeeklyProgressDayViewState(
            date: makeDate("2026-03-31T00:00:00+09:00")!,
            dayText: "Tue 31",
            timeRangeText: "08:24 - 17:30",
            workedText: "08:05",
            quitDeltaText: "+00:05",
            annotationText: nil,
            dayCategory: .weekday,
            isOvertime: true,
            progressFraction: 1,
            isToday: false,
            isSelectable: true
        ),
        MainPopoverWeeklyProgressDayViewState(
            date: makeDate("2026-04-01T00:00:00+09:00")!,
            dayText: "Wed 1",
            timeRangeText: "08:45 - 17:36",
            workedText: "07:51",
            quitDeltaText: "-00:09",
            annotationText: nil,
            dayCategory: .weekday,
            progressFraction: 0.98,
            isToday: false,
            isSelectable: true
        ),
        MainPopoverWeeklyProgressDayViewState(
            date: makeDate("2026-04-02T00:00:00+09:00")!,
            dayText: "Thu 2",
            timeRangeText: "08:22 - 18:31",
            workedText: "09:08",
            quitDeltaText: "+01:08",
            annotationText: nil,
            dayCategory: .weekday,
            progressFraction: 1,
            isToday: false,
            isSelectable: true
        ),
        MainPopoverWeeklyProgressDayViewState(
            date: makeDate("2026-04-03T00:00:00+09:00")!,
            dayText: "Fri 3",
            timeRangeText: "08:10 - --:--",
            workedText: "03:38",
            quitDeltaText: "-04:22",
            annotationText: nil,
            dayCategory: .weekday,
            progressFraction: 0.45,
            isToday: true,
            isSelectable: true
        ),
        MainPopoverWeeklyProgressDayViewState(
            date: makeDate("2026-04-04T00:00:00+09:00")!,
            dayText: "Sat 4",
            timeRangeText: "—:— - —:—",
            workedText: "--",
            quitDeltaText: "--",
            annotationText: nil,
            dayCategory: .weekend,
            progressFraction: 0,
            isToday: false,
            isSelectable: true
        ),
    ]
}

private func makeMonthlyHistoryCells(dayCount: Int) -> [MonthlyHistoryDayCellViewState] {
    (1...dayCount).map { index in
        MonthlyHistoryDayCellViewState(
            date: makeDate(String(format: "2026-04-%02dT00:00:00+09:00", index)),
            dayText: "\(index)",
            statusText: index == 2 ? "Active" : (index == 3 ? "08:05" : "—"),
            annotationText: nil,
            activity: index == 2 ? .active : (index == 3 ? .worked : .empty),
            dayCategory: .weekday,
            isOvertime: index == 3,
            isDimmed: index > 7,
            isSelectable: true
        )
    }
}
