import Foundation
import Testing
@testable import WorkPulse

struct WorkedDurationFormatterTests {
    @Test("formatter renders zero-padded hour and minute")
    func formatterRendersZeroPaddedHourAndMinute() {
        let formatter = WorkedDurationFormatter()

        #expect(formatter.string(from: 2 * 3600 + 5 * 60) == "02:05")
    }

    @Test("formatter drops leftover seconds")
    func formatterDropsLeftoverSeconds() {
        let formatter = WorkedDurationFormatter()

        #expect(formatter.string(from: 2 * 3600 + 30 * 60 + 59) == "02:30")
    }
}
