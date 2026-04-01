import Foundation

struct MainPopoverViewState {
    let dateText: String
    let checkedInSummaryText: String
    let currentSessionText: String
    let startTimeText: String
    let endTimeText: String
    let weeklyTotalText: String
    let monthlyTotalText: String

    static var placeholder: MainPopoverViewState {
        placeholder(copy: .english)
    }

    static func placeholder(copy: MainPopoverCopy) -> MainPopoverViewState {
        MainPopoverViewState(
            dateText: copy.placeholderDateText,
            checkedInSummaryText: copy.checkedInSummaryPlaceholder,
            currentSessionText: copy.currentSessionPlaceholderText,
            startTimeText: copy.timePlaceholderText,
            endTimeText: copy.timePlaceholderText,
            weeklyTotalText: copy.totalPlaceholderText,
            monthlyTotalText: copy.totalPlaceholderText
        )
    }
}
