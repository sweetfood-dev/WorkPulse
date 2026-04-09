import Foundation

struct MainPopoverCopy {
    let placeholderDateText: String
    let notCheckedInSummaryText: String
    let checkedInSummaryPrefix: String
    let checkedOutSummaryPrefix: String
    let currentSessionPlaceholderText: String
    let timePlaceholderText: String
    let totalPlaceholderText: String
    let currentSessionReadyTitle: String
    let currentSessionTitle: String
    let currentSessionWarningTitle: String
    let workedTodayTitle: String
    let workedTodayWarningTitle: String
    let currentSessionLeadingCaption: String
    let startTimeTitle: String
    let endTimeTitle: String
    let deleteActionTitle: String
    let backActionTitle: String
    let reportActionTitle: String
    let weeklyTitle: String
    let monthlyTitle: String
    let weeklyLabelPrefix: String
    let weeklyProgressTitle: String
    let weeklyProgressSegmentTitle: String
    let weeklyQuitTimeSegmentTitle: String
    let weeklyTodayGoalMetText: String
    let weeklyTodayStatusUnavailableText: String
    let monthlyHistoryTitle: String
    let monthlyHistoryTotalTitle: String
    let monthlyHistoryEmptyText: String
    let monthlyHistoryInProgressText: String
    let monthlyHistoryOffText: String
    let monthlyHistoryHolidayText: String
    let monthlyHistoryActiveText: String
    let currentSessionGoalLabelPrefix: String

    static let english = MainPopoverCopy(
        placeholderDateText: "Today",
        notCheckedInSummaryText: "Not checked in yet",
        checkedInSummaryPrefix: "Checked in at",
        checkedOutSummaryPrefix: "Checked out at",
        currentSessionPlaceholderText: "--:--:--",
        timePlaceholderText: "--:--",
        totalPlaceholderText: "--",
        currentSessionReadyTitle: "READY TO CHECK IN",
        currentSessionTitle: "CURRENT SESSION",
        currentSessionWarningTitle: "🔥 CURRENT SESSION",
        workedTodayTitle: "WORKED TODAY",
        workedTodayWarningTitle: "🔥 WORKED TODAY",
        currentSessionLeadingCaption: "0H",
        startTimeTitle: "Start Time",
        endTimeTitle: "End Time",
        deleteActionTitle: "Delete",
        backActionTitle: "Back",
        reportActionTitle: "Report",
        weeklyTitle: "This Week",
        monthlyTitle: "This Month",
        weeklyLabelPrefix: "Week",
        weeklyProgressTitle: "Weekly Progress",
        weeklyProgressSegmentTitle: "Progress",
        weeklyQuitTimeSegmentTitle: "Quit Time",
        weeklyTodayGoalMetText: "Today: Goal met",
        weeklyTodayStatusUnavailableText: "Today: Unavailable",
        monthlyHistoryTitle: "MONTHLY HISTORY",
        monthlyHistoryTotalTitle: "Monthly Total",
        monthlyHistoryEmptyText: "No attendance records yet",
        monthlyHistoryInProgressText: "In progress",
        monthlyHistoryOffText: "Off",
        monthlyHistoryHolidayText: "Holiday",
        monthlyHistoryActiveText: "Active",
        currentSessionGoalLabelPrefix: "Goal:"
    )

    var checkedInSummaryPlaceholder: String {
        notCheckedInSummaryText
    }

    func currentSessionTrailingCaption(goalDuration: TimeInterval) -> String {
        let goalHours = Int(goalDuration / 3_600)
        return "\(currentSessionGoalLabelPrefix) \(goalHours)h"
    }

    func checkedInSummaryText(for timeText: String) -> String {
        "\(checkedInSummaryPrefix) \(timeText)"
    }

    func checkedOutSummaryText(for timeText: String) -> String {
        "\(checkedOutSummaryPrefix) \(timeText)"
    }

    func summaryTotalText(totalDurationText: String) -> String {
        "Total: \(totalDurationText)"
    }

    func weeklyLabelText(weekOfYear: Int) -> String {
        "\(weeklyLabelPrefix) \(weekOfYear)"
    }

    func weeklyRemainingStatusText(durationText: String, goalHours: Int) -> String {
        "\(durationText) remaining to \(goalHours)h"
    }

    func weeklyOvertimeStatusText(durationText: String) -> String {
        "\(durationText) Overtime"
    }

    func weeklyTodayRemainingStatusText(durationText: String, goalHours: Int) -> String {
        "Today: \(durationText) remaining to \(goalHours)h"
    }

    func weeklyTodayOvertimeStatusText(durationText: String) -> String {
        "Today: \(durationText) Overtime"
    }

    var weeklyQuitTimeUnavailableText: String {
        "Quit time unavailable"
    }

    var weeklyNoCheckInStatusText: String {
        "No check-in record"
    }

    func weeklyQuitTimeStatusText(timeText: String) -> String {
        "Quit at \(timeText)"
    }

    func weeklyCanQuitStatusText(timeText: String) -> String {
        "Can leave since \(timeText)"
    }

    func weeklyCheckedOutStatusText(timeText: String) -> String {
        "Checked out \(timeText)"
    }

    func weeklyEarlyCheckedOutStatusText(timeText: String) -> String {
        "Left early at \(timeText)"
    }
}
