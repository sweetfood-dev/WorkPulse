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
    let weeklyTitle: String
    let monthlyTitle: String
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
        weeklyTitle: "This Week",
        monthlyTitle: "This Month",
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
}
