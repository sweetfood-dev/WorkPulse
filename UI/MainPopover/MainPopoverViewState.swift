import Foundation

enum MainPopoverDetailSurface: Equatable {
    case weekly
    case monthly
}

enum MainPopoverAttendanceState: Equatable {
    case notCheckedIn
    case checkedIn
    case checkedOut
    case vacation

    static func make(record: AttendanceRecord?) -> Self {
        guard let record else {
            return .notCheckedIn
        }

        return make(
            startTime: record.startTime,
            endTime: record.endTime,
            isVacation: record.isVacation
        )
    }

    static func make(startTime: Date?, endTime: Date?, isVacation: Bool = false) -> Self {
        if isVacation {
            return .vacation
        }

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
    let isVacation: Bool
    let allowsTimeEditing: Bool
    let fallbackStartTime: Date
    let fallbackEndTime: Date

    init(
        referenceDate: Date,
        dateText: String,
        startTimeText: String,
        endTimeText: String,
        startTime: Date?,
        endTime: Date?,
        isVacation: Bool = false,
        allowsTimeEditing: Bool = true,
        fallbackStartTime: Date,
        fallbackEndTime: Date
    ) {
        self.referenceDate = referenceDate
        self.dateText = dateText
        self.startTimeText = startTimeText
        self.endTimeText = endTimeText
        self.startTime = startTime
        self.endTime = endTime
        self.isVacation = isVacation
        self.allowsTimeEditing = allowsTimeEditing
        self.fallbackStartTime = fallbackStartTime
        self.fallbackEndTime = fallbackEndTime
    }
}

struct MainPopoverDisplayIntent {
    let viewState: MainPopoverViewState
    let startTime: Date?
    let endTime: Date?
    let isVacation: Bool
    let allowsLiveCurrentSessionUpdates: Bool

    init(
        viewState: MainPopoverViewState,
        startTime: Date?,
        endTime: Date?,
        isVacation: Bool = false,
        allowsLiveCurrentSessionUpdates: Bool
    ) {
        self.viewState = viewState
        self.startTime = startTime
        self.endTime = endTime
        self.isVacation = isVacation
        self.allowsLiveCurrentSessionUpdates = allowsLiveCurrentSessionUpdates
    }
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
