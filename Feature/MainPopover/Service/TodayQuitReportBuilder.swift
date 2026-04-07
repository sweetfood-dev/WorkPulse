import Foundation

struct TodayQuitReportBuilder {
    private let workedDurationCalculator: WorkedDurationCalculator
    private let goalDuration: TimeInterval
    private let timeFormatter: DateFormatter

    init(
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        goalDuration: TimeInterval = MainPopoverCurrentSessionProgressPolicy.defaultGoalDuration
    ) {
        var calendar = calendar
        calendar.locale = locale
        calendar.timeZone = timeZone

        self.workedDurationCalculator = WorkedDurationCalculator(calendar: calendar)
        self.goalDuration = goalDuration

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"
        self.timeFormatter = timeFormatter
    }

    func make(todayRecord: AttendanceRecord?, now: Date) -> String {
        guard let todayRecord else {
            return "아직 출근 전이라 퇴근 가능 시간을 계산할 수 없습니다."
        }

        guard let startTime = todayRecord.startTime else {
            return "오늘 출퇴근 기록이 올바르지 않아 퇴근 가능 시간을 계산할 수 없습니다."
        }

        let earliestQuitTime = earliestQuitTime(for: startTime)
        let earliestQuitText = timeFormatter.string(from: earliestQuitTime)

        if let endTime = todayRecord.endTime {
            guard workedDurationCalculator.workedDuration(startTime: startTime, endTime: endTime) != nil else {
                return "오늘 출퇴근 기록이 올바르지 않아 퇴근 가능 시간을 계산할 수 없습니다."
            }

            let endTimeText = timeFormatter.string(from: endTime)
            if endTime >= earliestQuitTime {
                return "오늘은 \(earliestQuitText)부터 퇴근 가능했고, \(endTimeText)에 퇴근했습니다."
            }

            return "오늘은 \(earliestQuitText)부터 퇴근 가능하지만, \(endTimeText)에 퇴근 기록이 있습니다."
        }

        if now >= earliestQuitTime {
            return "오늘은 \(earliestQuitText)부터 퇴근 가능합니다. 현재는 퇴근 가능한 상태입니다."
        }

        return "오늘은 \(earliestQuitText)부터 퇴근 가능합니다."
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
