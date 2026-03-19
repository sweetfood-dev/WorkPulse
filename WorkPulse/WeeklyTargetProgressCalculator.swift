import Foundation

struct WeeklyTargetProgress: Equatable {
    enum Status: Equatable {
        case remaining(TimeInterval)
        case met
        case overtime(TimeInterval)
    }

    let totalWorkedDuration: TimeInterval
    let status: Status
}

struct WeeklyTargetProgressCalculator {
    let targetDuration: TimeInterval

    func progress(totalWorkedDuration: TimeInterval?) -> WeeklyTargetProgress? {
        guard let totalWorkedDuration else {
            return nil
        }

        if totalWorkedDuration == targetDuration {
            return WeeklyTargetProgress(
                totalWorkedDuration: totalWorkedDuration,
                status: .met
            )
        }

        if totalWorkedDuration > targetDuration {
            return WeeklyTargetProgress(
                totalWorkedDuration: totalWorkedDuration,
                status: .overtime(totalWorkedDuration - targetDuration)
            )
        }

        return WeeklyTargetProgress(
            totalWorkedDuration: totalWorkedDuration,
            status: .remaining(targetDuration - totalWorkedDuration)
        )
    }
}
