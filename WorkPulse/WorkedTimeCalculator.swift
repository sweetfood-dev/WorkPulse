import Foundation

struct WorkedTimeCalculator {
    func workedDuration(
        startTime: Date?,
        endTime: Date?,
        currentDate: Date
    ) -> TimeInterval? {
        guard let startTime else { return nil }

        let effectiveEndTime = endTime ?? currentDate
        return effectiveEndTime.timeIntervalSince(startTime)
    }
}
