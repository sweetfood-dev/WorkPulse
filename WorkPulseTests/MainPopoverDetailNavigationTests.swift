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
        #expect(state.items.count == 2)
        #expect(state.items[0].isInProgress)
        #expect(state.items[0].workedDurationText == "In progress")
        #expect(state.items[1].isInProgress == false)
        #expect(state.items[1].workedDurationText == "--")
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
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    calendar.locale = Locale(identifier: "ko_KR")
    return calendar
}
