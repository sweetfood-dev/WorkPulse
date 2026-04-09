import Foundation

struct TodayQuitReportBuilder {
    private let quitTimeInsightCalculator: QuitTimeInsightCalculator
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

        self.quitTimeInsightCalculator = QuitTimeInsightCalculator(
            calendar: calendar,
            goalDuration: goalDuration
        )

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"
        self.timeFormatter = timeFormatter
    }

    func make(todayRecord: AttendanceRecord?, now: Date) -> String {
        switch quitTimeInsightCalculator.make(record: todayRecord) {
        case .noRecord:
            return report(
                startTimeText: "기록 없음",
                earliestQuitTimeText: "계산 불가",
                statusText: "출근 전",
                checkoutTimeText: nil
            )
        case let .invalidRecord(startTime):
            return report(
                startTimeText: startTime.map { timeFormatter.string(from: $0) } ?? "기록 이상",
                earliestQuitTimeText: "계산 불가",
                statusText: "기록 이상",
                checkoutTimeText: nil
            )
        case let .available(startTime, earliestQuitTime, checkoutTime):
            let startTimeText = timeFormatter.string(from: startTime)
            let earliestQuitText = timeFormatter.string(from: earliestQuitTime)

            if let checkoutTime {
                return report(
                    startTimeText: startTimeText,
                    earliestQuitTimeText: earliestQuitText,
                    statusText: checkoutTime >= earliestQuitTime ? "퇴근 완료" : "조기 퇴근 기록",
                    checkoutTimeText: timeFormatter.string(from: checkoutTime)
                )
            }

            return report(
                startTimeText: startTimeText,
                earliestQuitTimeText: earliestQuitText,
                statusText: now >= earliestQuitTime ? "퇴근 가능" : "업무 중",
                checkoutTimeText: nil
            )
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
