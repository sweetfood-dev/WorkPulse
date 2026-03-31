import Foundation

struct AttendanceRecord {
    let date: Date
    let startTime: Date?
    let endTime: Date?
}

struct MainPopoverViewStateFactory {
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    init(
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) {
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

    func make(
        referenceDate: Date,
        todayRecord: AttendanceRecord?,
        weeklyTotalText: String = MainPopoverViewState.placeholder.weeklyTotalText,
        monthlyTotalText: String = MainPopoverViewState.placeholder.monthlyTotalText
    ) -> MainPopoverViewState {
        MainPopoverViewState(
            dateText: dateFormatter.string(from: referenceDate),
            checkedInSummaryText: checkedInSummaryText(for: todayRecord),
            currentSessionText: MainPopoverViewState.placeholder.currentSessionText,
            startTimeText: timeText(for: todayRecord?.startTime),
            endTimeText: timeText(for: todayRecord?.endTime),
            weeklyTotalText: weeklyTotalText,
            monthlyTotalText: monthlyTotalText
        )
    }

    private func checkedInSummaryText(for record: AttendanceRecord?) -> String {
        guard let startTime = record?.startTime else {
            return MainPopoverViewState.placeholder.checkedInSummaryText
        }

        return "Checked in at \(timeFormatter.string(from: startTime))"
    }

    private func timeText(for date: Date?) -> String {
        guard let date else {
            return MainPopoverViewState.placeholder.startTimeText
        }

        return timeFormatter.string(from: date)
    }
}
