import Foundation
import Testing
@testable import WorkPulse

struct WeeklyTargetConfigurationTests {
    @Test("standard configuration keeps the forty-hour weekly target")
    func standardConfigurationKeepsTheFortyHourWeeklyTarget() {
        #expect(WeeklyTargetConfiguration.standard.duration == 40 * 60 * 60)
    }
}
