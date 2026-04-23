import Foundation

struct MainPopoverCopy {
    let placeholderDateText: String
    let notCheckedInSummaryText: String
    let checkedInSummaryPrefix: String
    let checkedOutSummaryPrefix: String
    let vacationSummaryText: String
    let currentSessionPlaceholderText: String
    let timePlaceholderText: String
    let totalPlaceholderText: String
    let currentSessionReadyTitle: String
    let currentSessionTitle: String
    let currentSessionWarningTitle: String
    let workedTodayTitle: String
    let workedTodayWarningTitle: String
    let currentSessionVacationTitle: String
    let currentSessionLeadingCaption: String
    let startTimeTitle: String
    let endTimeTitle: String
    let vacationToggleTitle: String
    let deleteActionTitle: String
    let backActionTitle: String
    let reportActionTitle: String
    let weeklyTitle: String
    let monthlyTitle: String
    let weeklyLabelPrefix: String
    let weeklyProgressTitle: String
    let weeklyProgressSegmentTitle: String
    let weeklyQuitTimeSegmentTitle: String
    let weeklyGoalMetStatusText: String
    let weeklyTodayGoalMetText: String
    let weeklyTodayStatusUnavailableText: String
    let monthlyHistoryTitle: String
    let monthlyHistoryTotalTitle: String
    let monthlyHistoryEmptyText: String
    let monthlyHistoryInProgressText: String
    let monthlyHistoryOffText: String
    let monthlyHistoryHolidayText: String
    let monthlyHistoryActiveText: String
    let monthlyHistoryVacationText: String
    let weeklyVacationText: String
    let currentSessionGoalLabelPrefix: String

    static let korean = MainPopoverCopy(
        placeholderDateText: "오늘",
        notCheckedInSummaryText: "출근 전",
        checkedInSummaryPrefix: "출근",
        checkedOutSummaryPrefix: "퇴근",
        vacationSummaryText: "휴가",
        currentSessionPlaceholderText: "--:--:--",
        timePlaceholderText: "--:--",
        totalPlaceholderText: "--",
        currentSessionReadyTitle: "출근 전",
        currentSessionTitle: "현재 근무",
        currentSessionWarningTitle: "🔥 현재 근무",
        workedTodayTitle: "오늘 근무",
        workedTodayWarningTitle: "🔥 오늘 근무",
        currentSessionVacationTitle: "휴가",
        currentSessionLeadingCaption: "0시간",
        startTimeTitle: "출근 시간",
        endTimeTitle: "퇴근 시간",
        vacationToggleTitle: "휴가",
        deleteActionTitle: "삭제",
        backActionTitle: "뒤로",
        reportActionTitle: "보고",
        weeklyTitle: "이번 주",
        monthlyTitle: "이번 달",
        weeklyLabelPrefix: "주차",
        weeklyProgressTitle: "주간 근무 현황",
        weeklyProgressSegmentTitle: "진행",
        weeklyQuitTimeSegmentTitle: "퇴근",
        weeklyGoalMetStatusText: "목표 달성",
        weeklyTodayGoalMetText: "오늘 기준 목표 달성",
        weeklyTodayStatusUnavailableText: "오늘 기준 계산 불가",
        monthlyHistoryTitle: "월간 근무 기록",
        monthlyHistoryTotalTitle: "월 누적",
        monthlyHistoryEmptyText: "기록 없음",
        monthlyHistoryInProgressText: "진행 중",
        monthlyHistoryOffText: "휴무",
        monthlyHistoryHolidayText: "공휴일",
        monthlyHistoryActiveText: "근무 중",
        monthlyHistoryVacationText: "휴가",
        weeklyVacationText: "휴가",
        currentSessionGoalLabelPrefix: "목표"
    )

    static let english = korean

    var checkedInSummaryPlaceholder: String {
        notCheckedInSummaryText
    }

    func currentSessionTrailingCaption(goalDuration: TimeInterval) -> String {
        let goalHours = Int(goalDuration / 3_600)
        if currentSessionGoalLabelPrefix == "목표" {
            return "\(currentSessionGoalLabelPrefix) \(goalHours)시간"
        }

        return "\(currentSessionGoalLabelPrefix) \(goalHours)h"
    }

    func checkedInSummaryText(for timeText: String) -> String {
        "\(checkedInSummaryPrefix) \(timeText)"
    }

    func checkedOutSummaryText(for timeText: String) -> String {
        "\(checkedOutSummaryPrefix) \(timeText)"
    }

    func summaryTotalText(totalDurationText: String) -> String {
        "총 \(totalDurationText)"
    }

    func weeklyLabelText(weekOfYear: Int) -> String {
        if weeklyLabelPrefix == "주차" {
            return "\(weekOfYear)\(weeklyLabelPrefix)"
        }

        return "\(weeklyLabelPrefix) \(weekOfYear)"
    }

    func weeklyRemainingStatusText(durationText: String, goalHours: Int) -> String {
        "\(goalHours)시간 목표까지 \(durationText) 남음"
    }

    func weeklyOvertimeStatusText(durationText: String) -> String {
        "\(durationText) 초과"
    }

    func weeklyTodayRemainingStatusText(durationText: String) -> String {
        "오늘 기준 \(durationText) 부족"
    }

    func weeklyTodayOvertimeStatusText(durationText: String) -> String {
        "오늘 기준 \(durationText) 초과"
    }

    var weeklyQuitTimeUnavailableText: String {
        "퇴근 가능 시간 계산 불가"
    }

    var weeklyNoCheckInStatusText: String {
        "출근 기록 없음"
    }

    func weeklyQuitTimeStatusText(timeText: String) -> String {
        "\(timeText) 퇴근 가능"
    }

    func weeklyCanQuitStatusText(timeText: String) -> String {
        "\(timeText)부터 퇴근 가능"
    }

    func weeklyCheckedOutStatusText(timeText: String) -> String {
        "\(timeText) 퇴근 완료"
    }

    func weeklyEarlyCheckedOutStatusText(timeText: String) -> String {
        "\(timeText) 조기 퇴근"
    }
}
