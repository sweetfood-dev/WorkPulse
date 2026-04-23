import Foundation
import Testing
@testable import WorkPulse

@Suite("TodayQuitReportBuilder")
struct TodayQuitReportBuilderTests {
    @Test
    func reportsEarliestQuitTimeAfterLunchDeduction() throws {
        let builder = TodayQuitReportBuilder(
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "ko_KR"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T08:10:00+09:00")
        )
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T10:00:00+09:00")
        )

        let report = builder.make(
            todayRecord: AttendanceRecord(date: startTime, startTime: startTime, endTime: nil),
            now: now,
            throughTodayStatusText: "Through today: 8h 00m remaining"
        )

        #expect(
            report == """
            [퇴근 가능 시간 보고]
            오늘 출근 시간: 08:10
            오늘 퇴근 가능 시간: 17:10
            현재 상태: 업무 중
            오늘까지 누적 상태: 8h 00m 부족
            """
        )
    }

    @Test
    func reportsActualCheckoutWhenDayIsAlreadyFinished() throws {
        let builder = TodayQuitReportBuilder(
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "ko_KR"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T08:10:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T17:30:00+09:00")
        )

        let report = builder.make(
            todayRecord: AttendanceRecord(date: startTime, startTime: startTime, endTime: endTime),
            now: endTime,
            throughTodayStatusText: "Through today: 0h 20m Overtime"
        )

        #expect(
            report == """
            [퇴근 가능 시간 보고]
            오늘 출근 시간: 08:10
            오늘 퇴근 가능 시간: 17:10
            현재 상태: 퇴근 완료
            오늘까지 누적 상태: 0h 20m 초과
            오늘 퇴근 시간: 17:30
            """
        )
    }

    @Test
    func reportsMalformedRecordWhenEndExistsWithoutStart() throws {
        let builder = TodayQuitReportBuilder(
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "ko_KR"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        )
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T18:00:00+09:00")
        )
        let endTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T17:30:00+09:00")
        )

        let report = builder.make(
            todayRecord: AttendanceRecord(date: now, startTime: nil, endTime: endTime),
            now: now,
            throughTodayStatusText: "Through today: Unavailable"
        )

        #expect(
            report == """
            [퇴근 가능 시간 보고]
            오늘 출근 시간: 기록 이상
            오늘 퇴근 가능 시간: 계산 불가
            현재 상태: 기록 이상
            오늘까지 누적 상태: 계산 불가
            """
        )
    }

    @Test
    func reportsKnownStartTimeForInvalidCheckoutRecord() throws {
        let builder = TodayQuitReportBuilder(
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "ko_KR"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T08:10:00+09:00")
        )
        let invalidEndTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T07:30:00+09:00")
        )

        let report = builder.make(
            todayRecord: AttendanceRecord(date: startTime, startTime: startTime, endTime: invalidEndTime),
            now: startTime,
            throughTodayStatusText: "Through today: On track"
        )

        #expect(
            report == """
            [퇴근 가능 시간 보고]
            오늘 출근 시간: 08:10
            오늘 퇴근 가능 시간: 계산 불가
            현재 상태: 기록 이상
            오늘까지 누적 상태: 목표 달성
            """
        )
    }

    @Test
    func reportsVacationDay() throws {
        let builder = TodayQuitReportBuilder(
            calendar: makeSeoulCalendar(),
            locale: Locale(identifier: "ko_KR"),
            timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        )
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T10:00:00+09:00")
        )

        let report = builder.make(
            todayRecord: AttendanceRecord(
                date: now,
                startTime: nil,
                endTime: nil,
                isVacation: true
            ),
            now: now,
            throughTodayStatusText: "Through today: On track"
        )

        #expect(
            report == """
            [퇴근 가능 시간 보고]
            오늘 출근 시간: 휴가
            오늘 퇴근 가능 시간: 해당 없음
            현재 상태: 휴가
            오늘까지 누적 상태: 목표 달성
            """
        )
    }
}

@Suite("QuitReportCopy", .serialized)
struct QuitReportCopyTests {
    @Test
    @MainActor
    func tappingReportCopiesTodayQuitReportToClipboard() throws {
        let currentDate = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T10:00:00+09:00")
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T08:10:00+09:00")
        )
        let store = InMemoryAttendanceRecordStoreForQuitReport(records: [
            AttendanceRecord(date: currentDate, startTime: startTime, endTime: nil)
        ])
        let clipboard = ClipboardSpy()
        let coordinator = MainPopoverCoordinator(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: makeSeoulCalendar(),
                locale: Locale(identifier: "ko_KR"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { currentDate },
                currentSessionScheduler: NoopCurrentSessionScheduler()
            ),
            recordStore: store,
            clipboardWriter: clipboard
        )

        let controller = coordinator.makePopoverViewController(referenceDate: currentDate)
        controller.simulateTapReport()

        #expect(
            clipboard.lastCopiedString == """
            [퇴근 가능 시간 보고]
            오늘 출근 시간: 08:10
            오늘 퇴근 가능 시간: 17:10
            현재 상태: 업무 중
            오늘까지 누적 상태: 8시간 00분 부족
            """
        )
    }

    @Test
    @MainActor
    func tappingReportUsesCurrentTimestampAtCopyTime() throws {
        let mondayMorning = try #require(
            ISO8601DateFormatter().date(from: "2026-04-06T10:00:00+09:00")
        )
        let tuesdayMidnight = try #require(
            ISO8601DateFormatter().date(from: "2026-04-07T00:00:00+09:00")
        )
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-04-06T08:10:00+09:00")
        )
        let store = InMemoryAttendanceRecordStoreForQuitReport(records: [
            AttendanceRecord(date: mondayMorning, startTime: startTime, endTime: nil)
        ])
        let clipboard = ClipboardSpy()
        let currentDateProvider = SequencedCurrentDateProvider([
            mondayMorning,
            mondayMorning,
            mondayMorning,
            tuesdayMidnight,
        ])
        let coordinator = MainPopoverCoordinator(
            runtimeDependencies: MainPopoverRuntimeDependencies(
                calendar: makeSeoulCalendar(),
                locale: Locale(identifier: "ko_KR"),
                timeZone: try #require(TimeZone(secondsFromGMT: 9 * 60 * 60)),
                calendarDayMetadataProvider: KoreanCalendarDayMetadataProvider(),
                currentDateProvider: { currentDateProvider.next() },
                currentSessionScheduler: NoopCurrentSessionScheduler()
            ),
            recordStore: store,
            clipboardWriter: clipboard
        )

        let controller = coordinator.makePopoverViewController(referenceDate: mondayMorning)
        controller.simulateTapReport()

        #expect(
            clipboard.lastCopiedString == """
            [퇴근 가능 시간 보고]
            오늘 출근 시간: 기록 없음
            오늘 퇴근 가능 시간: 계산 불가
            현재 상태: 출근 전
            오늘까지 누적 상태: 계산 불가
            """
        )
    }
}

private final class ClipboardSpy: StringClipboardWriting {
    private(set) var lastCopiedString: String?

    func copy(_ string: String) {
        lastCopiedString = string
    }
}

private final class InMemoryAttendanceRecordStoreForQuitReport: AttendanceRecordStore {
    private var records: [AttendanceRecord]
    private let mutationCalendar: Calendar

    init(records: [AttendanceRecord], mutationCalendar: Calendar = makeSeoulCalendar()) {
        self.records = records
        self.mutationCalendar = mutationCalendar
    }

    func record(on date: Date, calendar: Calendar) -> AttendanceRecord? {
        records.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func records(equalTo date: Date, toGranularity component: Calendar.Component, calendar: Calendar) -> [AttendanceRecord] {
        records.filter { calendar.isDate($0.date, equalTo: date, toGranularity: component) }
    }

    func upsertRecord(_ record: AttendanceRecord) throws {
        if let index = records.firstIndex(where: { mutationCalendar.isDate($0.date, inSameDayAs: record.date) }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    func deleteRecord(on date: Date, calendar: Calendar) throws {
        records.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

private final class SequencedCurrentDateProvider {
    private var dates: [Date]
    private var lastDate: Date

    init(_ dates: [Date]) {
        self.dates = dates
        self.lastDate = dates.last ?? Date(timeIntervalSince1970: 0)
    }

    func next() -> Date {
        if dates.isEmpty == false {
            lastDate = dates.removeFirst()
        }
        return lastDate
    }
}

private struct NoopCurrentSessionScheduler: CurrentSessionScheduling {
    func scheduleRepeating(
        every interval: TimeInterval,
        action: @escaping () -> Void
    ) -> any CurrentSessionCancellable {
        NoopCurrentSessionCancellable()
    }
}

private struct NoopCurrentSessionCancellable: CurrentSessionCancellable {
    func cancel() {}
}

private func makeSeoulCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "ko_KR")
    calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
    return calendar
}
