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
            now: now
        )

        #expect(report == "오늘은 17:10부터 퇴근 가능합니다.")
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
            now: endTime
        )

        #expect(report == "오늘은 17:10부터 퇴근 가능했고, 17:30에 퇴근했습니다.")
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
            now: now
        )

        #expect(report == "오늘 출퇴근 기록이 올바르지 않아 퇴근 가능 시간을 계산할 수 없습니다.")
    }
}

@Suite("QuitReportCopy")
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

        #expect(clipboard.lastCopiedString == "오늘은 17:10부터 퇴근 가능합니다.")
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

    init(records: [AttendanceRecord]) {
        self.records = records
    }

    func record(on date: Date, calendar: Calendar) -> AttendanceRecord? {
        records.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func records(equalTo date: Date, toGranularity component: Calendar.Component, calendar: Calendar) -> [AttendanceRecord] {
        records.filter { calendar.isDate($0.date, equalTo: date, toGranularity: component) }
    }

    func upsertRecord(_ record: AttendanceRecord) throws {
        if let index = records.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: record.date) }) {
            records[index] = record
        } else {
            records.append(record)
        }
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
