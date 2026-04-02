import Foundation

struct MainPopoverCopy {
    let placeholderDateText: String
    let checkedInSummaryPrefix: String
    let currentSessionPlaceholderText: String
    let timePlaceholderText: String
    let totalPlaceholderText: String
    let currentSessionTitle: String
    let currentSessionWarningTitle: String
    let currentSessionLeadingCaption: String
    let startTimeTitle: String
    let endTimeTitle: String
    let deleteActionTitle: String
    let backActionTitle: String
    let weeklyTitle: String
    let monthlyTitle: String
    let weeklyLabelPrefix: String
    let weeklyProgressTitle: String
    let monthlyHistoryTitle: String
    let monthlyHistoryEmptyText: String
    let monthlyHistoryInProgressText: String
    let currentSessionGoalLabelPrefix: String

    static let english = MainPopoverCopy(
        placeholderDateText: "Today",
        checkedInSummaryPrefix: "Checked in at",
        currentSessionPlaceholderText: "--:--:--",
        timePlaceholderText: "--:--",
        totalPlaceholderText: "--",
        currentSessionTitle: "CURRENT SESSION",
        currentSessionWarningTitle: "🔥 CURRENT SESSION",
        currentSessionLeadingCaption: "0H",
        startTimeTitle: "Start Time",
        endTimeTitle: "End Time",
        deleteActionTitle: "Delete",
        backActionTitle: "Back",
        weeklyTitle: "This Week",
        monthlyTitle: "This Month",
        weeklyLabelPrefix: "Week",
        weeklyProgressTitle: "Weekly Progress",
        monthlyHistoryTitle: "MONTHLY HISTORY",
        monthlyHistoryEmptyText: "No attendance records yet",
        monthlyHistoryInProgressText: "In progress",
        currentSessionGoalLabelPrefix: "Goal:"
    )

    var checkedInSummaryPlaceholder: String {
        checkedInSummaryText(for: timePlaceholderText)
    }

    func currentSessionTrailingCaption(goalDuration: TimeInterval) -> String {
        let goalHours = Int(goalDuration / 3_600)
        return "\(currentSessionGoalLabelPrefix) \(goalHours)h"
    }

    func checkedInSummaryText(for timeText: String) -> String {
        "\(checkedInSummaryPrefix) \(timeText)"
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
}
