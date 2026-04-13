import Foundation

struct MainPopoverViewStateFactory {
    private let copy: MainPopoverCopy
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    init(
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        copy: MainPopoverCopy = .english
    ) {
        self.copy = copy
        var calendar = calendar
        calendar.locale = locale
        calendar.timeZone = timeZone

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "EEEE, MMM d"
        self.dateFormatter = dateFormatter

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"
        self.timeFormatter = timeFormatter
    }

    func makePlaceholder() -> MainPopoverViewState {
        MainPopoverViewState(
            attendanceState: .notCheckedIn,
            dateText: copy.placeholderDateText,
            checkedInSummaryText: copy.checkedInSummaryPlaceholder,
            currentSessionText: copy.currentSessionPlaceholderText,
            startTimeText: copy.timePlaceholderText,
            endTimeText: copy.timePlaceholderText,
            weeklyTotalText: copy.totalPlaceholderText,
            monthlyTotalText: copy.totalPlaceholderText
        )
    }

    func make(
        referenceDate: Date,
        todayRecord: AttendanceRecord?,
        weeklyTotalText: String? = nil,
        monthlyTotalText: String? = nil
    ) -> MainPopoverViewState {
        MainPopoverViewState(
            attendanceState: attendanceState(for: todayRecord),
            dateText: dateFormatter.string(from: referenceDate),
            checkedInSummaryText: checkedInSummaryText(for: todayRecord),
            currentSessionText: copy.currentSessionPlaceholderText,
            startTimeText: timeText(for: todayRecord?.startTime),
            endTimeText: timeText(for: todayRecord?.endTime),
            weeklyTotalText: weeklyTotalText ?? copy.totalPlaceholderText,
            monthlyTotalText: monthlyTotalText ?? copy.totalPlaceholderText
        )
    }

    private func checkedInSummaryText(for record: AttendanceRecord?) -> String {
        guard let record else {
            return copy.notCheckedInSummaryText
        }

        switch MainPopoverAttendanceState.make(record: record) {
        case .checkedOut:
            guard let endTime = record.endTime else {
                return copy.notCheckedInSummaryText
            }
            return copy.checkedOutSummaryText(for: timeFormatter.string(from: endTime))
        case .checkedIn:
            guard let startTime = record.startTime else {
                return copy.notCheckedInSummaryText
            }
            return copy.checkedInSummaryText(for: timeFormatter.string(from: startTime))
        case .vacation:
            return copy.vacationSummaryText
        case .notCheckedIn:
            return copy.notCheckedInSummaryText
        }
    }

    private func attendanceState(for record: AttendanceRecord?) -> MainPopoverAttendanceState {
        MainPopoverAttendanceState.make(record: record)
    }

    private func timeText(for date: Date?) -> String {
        guard let date else {
            return copy.timePlaceholderText
        }

        return timeFormatter.string(from: date)
    }
}
