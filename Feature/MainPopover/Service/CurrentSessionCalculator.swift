import Foundation

struct CurrentSessionCalculator {
    func runningDuration(startTime: Date?, now: Date) -> TimeInterval? {
        guard let startTime else { return nil }
        return now.timeIntervalSince(startTime)
    }
}
