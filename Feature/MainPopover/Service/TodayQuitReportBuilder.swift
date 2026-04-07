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
            return report(
                startTimeText: "기록 없음",
                earliestQuitTimeText: "계산 불가",
                statusText: "출근 전",
                checkoutTimeText: nil
            )
        }

        guard let startTime = todayRecord.startTime else {
            return report(
                startTimeText: "기록 이상",
                earliestQuitTimeText: "계산 불가",
                statusText: "기록 이상",
                checkoutTimeText: nil
            )
        }

        let earliestQuitTime = earliestQuitTime(for: startTime)
        let startTimeText = timeFormatter.string(from: startTime)
        let earliestQuitText = timeFormatter.string(from: earliestQuitTime)

        if let endTime = todayRecord.endTime {
            guard workedDurationCalculator.workedDuration(startTime: startTime, endTime: endTime) != nil else {
                return report(
                    startTimeText: startTimeText,
                    earliestQuitTimeText: "계산 불가",
                    statusText: "기록 이상",
                    checkoutTimeText: nil
                )
            }

            return report(
                startTimeText: startTimeText,
                earliestQuitTimeText: earliestQuitText,
                statusText: endTime >= earliestQuitTime ? "퇴근 완료" : "조기 퇴근 기록",
                checkoutTimeText: timeFormatter.string(from: endTime)
            )
        }

        return report(
            startTimeText: startTimeText,
            earliestQuitTimeText: earliestQuitText,
            statusText: now >= earliestQuitTime ? "퇴근 가능" : "업무 중",
            checkoutTimeText: nil
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

    private func report(
        startTimeText: String,
        earliestQuitTimeText: String,
        statusText: String,
        checkoutTimeText: String?
    ) -> String {
        var lines = [
            "[퇴근 가능 시간 보고]",
            "오늘 출근 시간: \(startTimeText)",
            "오늘 퇴근 가능 시간: \(earliestQuitTimeText)",
            "현재 상태: \(statusText)",
        ]

        if let checkoutTimeText {
            lines.append("오늘 퇴근 시간: \(checkoutTimeText)")
        }

        return lines.joined(separator: "\n")
    }
}
