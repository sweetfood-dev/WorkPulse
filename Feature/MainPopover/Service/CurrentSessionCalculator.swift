import Foundation

struct CurrentSessionCalculator {
    func sessionDuration(
        startTime: Date?,
        endTime: Date?,
        now: Date
    ) -> TimeInterval? {
        guard let startTime else { return nil }
        if let endTime {
            return endTime.timeIntervalSince(startTime)
        }

        return now.timeIntervalSince(startTime)
    }
}
