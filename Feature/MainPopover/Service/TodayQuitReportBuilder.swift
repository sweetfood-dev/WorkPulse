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

    func make(
        todayRecord: AttendanceRecord?,
        now: Date,
        throughTodayStatusText: String? = nil
    ) -> String {
        switch quitTimeInsightCalculator.make(record: todayRecord) {
        case .noRecord:
            return report(
                startTimeText: "기록 없음",
                earliestQuitTimeText: "계산 불가",
                statusText: "출근 전",
                checkoutTimeText: nil,
                throughTodayStatusText: throughTodayStatusText
            )
        case .vacation:
            return report(
                startTimeText: "휴가",
                earliestQuitTimeText: "해당 없음",
                statusText: "휴가",
                checkoutTimeText: nil,
                throughTodayStatusText: throughTodayStatusText
            )
        case let .invalidRecord(startTime):
            return report(
                startTimeText: startTime.map { timeFormatter.string(from: $0) } ?? "기록 이상",
                earliestQuitTimeText: "계산 불가",
                statusText: "기록 이상",
                checkoutTimeText: nil,
                throughTodayStatusText: throughTodayStatusText
            )
        case let .available(startTime, earliestQuitTime, checkoutTime):
            let startTimeText = timeFormatter.string(from: startTime)
            let earliestQuitText = timeFormatter.string(from: earliestQuitTime)

            if let checkoutTime {
                return report(
                    startTimeText: startTimeText,
                    earliestQuitTimeText: earliestQuitText,
                    statusText: checkoutTime >= earliestQuitTime ? "퇴근 완료" : "조기 퇴근 기록",
                    checkoutTimeText: timeFormatter.string(from: checkoutTime),
                    throughTodayStatusText: throughTodayStatusText
                )
            }

            return report(
                startTimeText: startTimeText,
                earliestQuitTimeText: earliestQuitText,
                statusText: now >= earliestQuitTime ? "퇴근 가능" : "업무 중",
                checkoutTimeText: nil,
                throughTodayStatusText: throughTodayStatusText
            )
        }
    }

    private func report(
        startTimeText: String,
        earliestQuitTimeText: String,
        statusText: String,
        checkoutTimeText: String?,
        throughTodayStatusText: String?
    ) -> String {
        var lines = [
            "[퇴근 가능 시간 보고]",
            "오늘 출근 시간: \(startTimeText)",
            "오늘 퇴근 가능 시간: \(earliestQuitTimeText)",
            "현재 상태: \(statusText)",
        ]

        if let throughTodayStatusLine = throughTodayStatusLine(from: throughTodayStatusText) {
            lines.append(throughTodayStatusLine)
        }

        if let checkoutTimeText {
            lines.append("오늘 퇴근 시간: \(checkoutTimeText)")
        }

        return lines.joined(separator: "\n")
    }

    private func throughTodayStatusLine(from statusText: String?) -> String? {
        guard let statusText, statusText.isEmpty == false else { return nil }

        let normalized = statusText
            .replacingOccurrences(of: "Through today: ", with: "")
            .replacingOccurrences(of: " Overtime", with: " 초과")
            .replacingOccurrences(of: " remaining", with: " 부족")
            .replacingOccurrences(of: "On track", with: "정상")
            .replacingOccurrences(of: "Unavailable", with: "계산 불가")

        return "오늘까지 누적 상태: \(normalized)"
    }
}
