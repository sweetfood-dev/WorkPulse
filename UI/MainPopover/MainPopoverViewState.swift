import Foundation

enum MainPopoverDetailSurface: Equatable {
    case weekly
    case monthly
}

enum MainPopoverAttendanceState: Equatable {
    case notCheckedIn
    case checkedIn
    case checkedOut

    static func make(startTime: Date?, endTime: Date?) -> Self {
        guard let startTime else {
            return .notCheckedIn
        }

        guard let endTime else {
            return .checkedIn
        }

        return endTime >= startTime ? .checkedOut : .checkedIn
    }
}

struct MainPopoverDetailDayEditingState {
    let referenceDate: Date
    let dateText: String
    let startTimeText: String
    let endTimeText: String
    let startTime: Date?
    let endTime: Date?
    let fallbackStartTime: Date
    let fallbackEndTime: Date
}

struct MainPopoverDisplayIntent {
    let viewState: MainPopoverViewState
    let startTime: Date?
    let endTime: Date?
    let allowsLiveCurrentSessionUpdates: Bool
}

struct MainPopoverViewState {
    let attendanceState: MainPopoverAttendanceState
    let dateText: String
    let checkedInSummaryText: String
    let currentSessionText: String
    let startTimeText: String
    let endTimeText: String
    let weeklyTotalText: String
    let monthlyTotalText: String
}
