import Foundation

struct WorkedDurationCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // Current policy: deduct the overlap with the fixed lunch window (12:00~13:00).
    func workedDuration(
        startTime: Date?,
        endTime: Date?
    ) -> TimeInterval? {
        guard let startTime, let endTime else { return nil }

        let rawDuration = endTime.timeIntervalSince(startTime)
        guard rawDuration >= 0 else { return nil }

        let lunchBreakDuration = lunchBreakOverlap(
            startTime: startTime,
            endTime: endTime
        )

        return max(0, rawDuration - lunchBreakDuration)
    }

    private func lunchBreakOverlap(startTime: Date, endTime: Date) -> TimeInterval {
        var overlap: TimeInterval = 0
        var currentDay = calendar.startOfDay(for: startTime)

        while currentDay <= endTime {
            let lunchInterval = lunchBreakInterval(for: currentDay)
            let overlapStart = max(startTime, lunchInterval.start)
            let overlapEnd = min(endTime, lunchInterval.end)
            overlap += max(0, overlapEnd.timeIntervalSince(overlapStart))

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else {
                break
            }

            currentDay = nextDay
        }

        return overlap
    }

    private func lunchBreakInterval(for date: Date) -> DateInterval {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let lunchStart = calendar.date(
            bySettingHour: 12,
            minute: 0,
            second: 0,
            of: calendar.date(from: components) ?? date
        ) ?? date
        let lunchEnd = calendar.date(
            bySettingHour: 13,
            minute: 0,
            second: 0,
            of: lunchStart
        ) ?? lunchStart.addingTimeInterval(60 * 60)
        return DateInterval(start: lunchStart, end: lunchEnd)
    }
}
