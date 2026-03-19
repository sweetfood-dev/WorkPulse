import Foundation
import Testing
@testable import WorkPulse

struct WorkedTimeDisplayModelFactoryTests {
    @Test("factory returns placeholder texts when no start time exists")
    func factoryReturnsPlaceholderTextsWhenStartTimeIsMissing() {
        let factory = makeFactory()

        let model = factory.make(
            startTime: nil,
            endTime: nil,
            currentDate: Date(timeIntervalSince1970: 0)
        )

        #expect(
            model == WorkedTimeDisplayModel(
                statusItemText: "--:--",
                popoverText: "현재 근무: --:--"
            )
        )
    }

    @Test("factory returns matching status item and popover texts for ongoing work")
    func factoryReturnsMatchingTextsForOngoingWork() throws {
        let calendar = testCalendar()
        let factory = makeFactory()
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 30))
        )
        let currentDate = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 12, minute: 0))
        )

        let model = factory.make(
            startTime: startTime,
            endTime: nil,
            currentDate: currentDate
        )

        #expect(
            model == WorkedTimeDisplayModel(
                statusItemText: "02:30",
                popoverText: "현재 근무: 02:30"
            )
        )
    }

    @Test("factory returns matching status item and popover texts for recorded work")
    func factoryReturnsMatchingTextsForRecordedWork() throws {
        let calendar = testCalendar()
        let factory = makeFactory()
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 9, minute: 30))
        )
        let endTime = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 4, day: 2, hour: 18, minute: 15))
        )

        let model = factory.make(
            startTime: startTime,
            endTime: endTime,
            currentDate: Date(timeIntervalSince1970: 0)
        )

        #expect(
            model == WorkedTimeDisplayModel(
                statusItemText: "08:45",
                popoverText: "현재 근무: 08:45"
            )
        )
    }

    private func makeFactory() -> WorkedTimeDisplayModelFactory {
        WorkedTimeDisplayModelFactory(
            placeholderTimeText: "--:--",
            popoverPrefixText: "현재 근무: ",
            workedTimeCalculator: WorkedTimeCalculator(),
            workedDurationFormatter: WorkedDurationFormatter()
        )
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
