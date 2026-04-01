import Foundation

struct AttendanceRecord: Codable, Equatable {
    let date: Date
    let startTime: Date?
    let endTime: Date?
}

enum TodayTimeField: Equatable {
    case startTime
    case endTime
}

struct TodayTimeEditModeState {
    private(set) var savedStartTime: Date?
    private(set) var savedEndTime: Date?
    private(set) var draftStartTime: Date?
    private(set) var draftEndTime: Date?
    private(set) var editingField: TodayTimeField?

    var isEditingStartTime: Bool {
        editingField == .startTime
    }

    var isEditingEndTime: Bool {
        editingField == .endTime
    }

    var hasValidDraftTimes: Bool {
        guard let draftStartTime, let draftEndTime else {
            return true
        }

        return draftEndTime >= draftStartTime
    }

    mutating func loadSavedTimes(startTime: Date?, endTime: Date?) {
        savedStartTime = startTime
        savedEndTime = endTime

        guard editingField == nil else { return }

        draftStartTime = startTime
        draftEndTime = endTime
    }

    mutating func beginEditing(_ field: TodayTimeField) {
        editingField = field
        draftStartTime = savedStartTime
        draftEndTime = savedEndTime
    }

    mutating func updateDraftStartTime(_ startTime: Date) {
        draftStartTime = startTime
    }

    mutating func updateDraftEndTime(_ endTime: Date) {
        draftEndTime = endTime
    }

    mutating func apply() -> (startTime: Date?, endTime: Date?)? {
        guard editingField != nil else { return nil }

        savedStartTime = draftStartTime
        savedEndTime = draftEndTime
        editingField = nil

        return (savedStartTime, savedEndTime)
    }

    mutating func cancel() {
        draftStartTime = savedStartTime
        draftEndTime = savedEndTime
        editingField = nil
    }
}

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

    func make(
        referenceDate: Date,
        todayRecord: AttendanceRecord?,
        weeklyTotalText: String? = nil,
        monthlyTotalText: String? = nil
    ) -> MainPopoverViewState {
        MainPopoverViewState(
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
        guard let startTime = record?.startTime else {
            return copy.checkedInSummaryPlaceholder
        }

        return copy.checkedInSummaryText(for: timeFormatter.string(from: startTime))
    }

    private func timeText(for date: Date?) -> String {
        guard let date else {
            return copy.timePlaceholderText
        }

        return timeFormatter.string(from: date)
    }
}
