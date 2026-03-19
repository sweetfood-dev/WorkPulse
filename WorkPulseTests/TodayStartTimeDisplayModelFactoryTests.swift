import Foundation
import Testing
@testable import WorkPulse

struct TodayStartTimeDisplayModelFactoryTests {
    @Test("factory returns placeholder when start time is missing")
    func factoryReturnsPlaceholderWhenStartTimeIsMissing() {
        let factory = makeFactory()

        let model = factory.make(startTime: nil, todayRecord: nil)

        #expect(model == TodayStartTimeDisplayModel(text: "오늘 출근: --", isHidden: false))
    }

    @Test("factory returns hidden state when start time exists but today record is missing")
    func factoryReturnsHiddenStateWhenTodayRecordIsMissing() {
        let factory = makeFactory()

        let model = factory.make(startTime: Date(timeIntervalSince1970: 1), todayRecord: nil)

        #expect(model == TodayStartTimeDisplayModel(text: "", isHidden: true))
    }

    @Test("factory returns formatted text when today record exists")
    func factoryReturnsFormattedTextWhenTodayRecordExists() throws {
        let calendar = testCalendar()
        let factory = makeFactory(calendar: calendar)
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 3))
        )
        let todayRecord = AttendanceTimeRecord(startTime: startTime, endTime: nil)

        let model = factory.make(startTime: startTime, todayRecord: todayRecord)

        #expect(model == TodayStartTimeDisplayModel(text: "오늘 출근: 09:03", isHidden: false))
    }

    private func makeFactory(calendar: Calendar? = nil) -> TodayStartTimeDisplayModelFactory {
        let calendar = calendar ?? testCalendar()

        return TodayStartTimeDisplayModelFactory(
            placeholderText: "오늘 출근: --",
            prefixText: "오늘 출근: ",
            timeFormatter: AttendanceTimeFormatter(calendar: calendar)
        )
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
