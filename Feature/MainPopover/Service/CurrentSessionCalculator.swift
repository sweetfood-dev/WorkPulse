import Foundation

struct CurrentSessionCalculator {
    private let workedDurationCalculator: WorkedDurationCalculator

    init(workedDurationCalculator: WorkedDurationCalculator = WorkedDurationCalculator()) {
        self.workedDurationCalculator = workedDurationCalculator
    }

    func sessionDuration(
        startTime: Date?,
        endTime: Date?,
        now: Date
    ) -> TimeInterval? {
        workedDurationCalculator.workedDuration(
            startTime: startTime,
            endTime: endTime ?? now
        )
    }
}
