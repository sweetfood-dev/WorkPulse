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
        #expect(controller.snapshot.weeklyDetail.progressFraction == 0.4)
        #expect(controller.snapshot.weeklyDetail.dayCount == 1)
        #expect(controller.snapshot.weeklyDetail.isWarningState == false)

        controller.showMainView()

        #expect(controller.snapshot.isShowingWeeklyDetail == false)
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
        #expect(controller.view.frame.height > MainPopoverStyle.Metrics.popoverSize.height)
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
        #expect(state.progressFraction == 0.4)
        #expect(state.visualState == .normal)
        #expect(state.days.count == 7)
        #expect(state.days[1].timeRangeText == "09:00 - 18:00")
        #expect(state.days[1].workedText == "08:00")
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
        #expect(state.progressFraction > 0.27)
        #expect(state.progressFraction < 0.28)
        #expect(state.visualState == .normal)
        #expect(state.days.first(where: { $0.isToday })?.timeRangeText == "09:00 - --:--")
        #expect(state.days.first(where: { $0.isToday })?.workedText == "03:00")
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
                    MonthlyHistoryDayCellViewState(dayText: "2", statusText: "Active", annotationText: longHolidayName, activity: .active, dayCategory: .holiday, isDimmed: false),
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
