import Foundation

struct MainPopoverCopy {
    let currentSessionTitle: String
    let currentSessionLeadingCaption: String
    let startTimeTitle: String
    let endTimeTitle: String
    let weeklyTitle: String
    let monthlyTitle: String
    let currentSessionGoalLabelPrefix: String

    static let english = MainPopoverCopy(
        currentSessionTitle: "CURRENT SESSION",
        currentSessionLeadingCaption: "0H",
        startTimeTitle: "Start Time",
        endTimeTitle: "End Time",
        weeklyTitle: "This Week",
        monthlyTitle: "This Month",
        currentSessionGoalLabelPrefix: "Goal:"
    )

    func currentSessionTrailingCaption(goalDuration: TimeInterval) -> String {
        let goalHours = Int(goalDuration / 3_600)
        return "\(currentSessionGoalLabelPrefix) \(goalHours)h"
    }
}
