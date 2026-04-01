import Foundation

struct MainPopoverDisplayIntent {
    let viewState: MainPopoverViewState
    let startTime: Date?
    let endTime: Date?
}

struct MainPopoverViewState {
    let dateText: String
    let checkedInSummaryText: String
    let currentSessionText: String
    let startTimeText: String
    let endTimeText: String
    let weeklyTotalText: String
    let monthlyTotalText: String
}
