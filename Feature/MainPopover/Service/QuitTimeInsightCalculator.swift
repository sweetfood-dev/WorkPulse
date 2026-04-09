import Foundation

enum QuitTimeInsight {
    case noRecord
    case invalidRecord
    case available(startTime: Date, earliestQuitTime: Date, checkoutTime: Date?)
}

struct QuitTimeInsightCalculator {
    private let workedDurationCalculator: WorkedDurationCalculator
    private let goalDuration: TimeInterval

    init(
        calendar: Calendar = .current,
        goalDuration: TimeInterval = MainPopoverCurrentSessionProgressPolicy.defaultGoalDuration
    ) {
        self.workedDurationCalculator = WorkedDurationCalculator(calendar: calendar)
        self.goalDuration = goalDuration
    }

    func make(record: AttendanceRecord?) -> QuitTimeInsight {
        guard let record else { return .noRecord }
        guard let startTime = record.startTime else { return .invalidRecord }

        let earliestQuitTime = earliestQuitTime(for: startTime)

        if let checkoutTime = record.endTime {
            guard workedDurationCalculator.workedDuration(startTime: startTime, endTime: checkoutTime) != nil else {
                return .invalidRecord
            }

            return .available(
                startTime: startTime,
                earliestQuitTime: earliestQuitTime,
                checkoutTime: checkoutTime
            )
        }

        return .available(
            startTime: startTime,
            earliestQuitTime: earliestQuitTime,
            checkoutTime: nil
        )
    }

    private func earliestQuitTime(for startTime: Date) -> Date {
        var candidate = startTime.addingTimeInterval(goalDuration)

        while true {
            let workedDuration = workedDurationCalculator.workedDuration(
                startTime: startTime,
                endTime: candidate
            ) ?? 0

            if workedDuration >= goalDuration {
                return candidate
            }

            candidate = candidate.addingTimeInterval(goalDuration - workedDuration)
        }
    }
}
