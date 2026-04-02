import Foundation

struct MonthlyHistoryItemViewState {
    let dateText: String
    let timeRangeText: String
    let workedDurationText: String
    let isInProgress: Bool
}

struct MonthlyHistoryViewState {
    let titleText: String
    let subtitleText: String
    let totalText: String
    let emptyText: String
    let items: [MonthlyHistoryItemViewState]
}

struct MonthlyHistoryLoader {
    private let recordStore: any AttendanceRecordQuerying
    private let totalsCalculator: AttendanceRecordTotalsCalculator
    private let workedDurationCalculator: WorkedDurationCalculator
    private let calendar: Calendar
    private let currentDateProvider: () -> Date
    private let copy: MainPopoverCopy
    private let monthFormatter: DateFormatter
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    init(
        recordStore: any AttendanceRecordQuerying,
        totalsCalculator: AttendanceRecordTotalsCalculator = AttendanceRecordTotalsCalculator(),
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        currentDateProvider: @escaping () -> Date,
        copy: MainPopoverCopy = .english
    ) {
        self.recordStore = recordStore
        self.totalsCalculator = totalsCalculator
        self.workedDurationCalculator = WorkedDurationCalculator(calendar: calendar)
        self.calendar = calendar
        self.currentDateProvider = currentDateProvider
        self.copy = copy

        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.locale = locale
        monthFormatter.timeZone = timeZone
        monthFormatter.dateFormat = "MMMM yyyy"
        self.monthFormatter = monthFormatter

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "EEE, MMM d"
        self.dateFormatter = dateFormatter

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"
        self.timeFormatter = timeFormatter
    }

    func load(referenceDate: Date) -> MonthlyHistoryViewState {
        let records = recordStore.records(
            equalTo: referenceDate,
            toGranularity: .month,
            calendar: calendar
        ).sorted { $0.date > $1.date }
        let totalDuration = totalsCalculator.monthlyTotal(
            records: records,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let currentDate = currentDateProvider()

        return MonthlyHistoryViewState(
            titleText: copy.monthlyHistoryTitle,
            subtitleText: monthFormatter.string(from: referenceDate),
            totalText: copy.summaryTotalText(totalDurationText: formatWorkedDuration(totalDuration)),
            emptyText: copy.monthlyHistoryEmptyText,
            items: records.map { record in
                makeItemState(record: record, currentDate: currentDate)
            }
        )
    }

    private func makeItemState(
        record: AttendanceRecord,
        currentDate: Date
    ) -> MonthlyHistoryItemViewState {
        let isInProgress =
            record.startTime != nil &&
            record.endTime == nil &&
            calendar.isDate(record.date, inSameDayAs: currentDate)
        let duration = workedDuration(
            startTime: record.startTime,
            endTime: record.endTime,
            recordDate: record.date,
            currentDate: currentDate
        )

        return MonthlyHistoryItemViewState(
            dateText: dateFormatter.string(from: record.date),
            timeRangeText: makeTimeRangeText(startTime: record.startTime, endTime: record.endTime),
            workedDurationText: isInProgress ? copy.monthlyHistoryInProgressText : formatWorkedDuration(duration),
            isInProgress: isInProgress
        )
    }

    private func makeTimeRangeText(startTime: Date?, endTime: Date?) -> String {
        "\(formatTime(startTime)) - \(formatTime(endTime))"
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date else {
            return copy.timePlaceholderText
        }

        return timeFormatter.string(from: date)
    }

    private func formatWorkedDuration(_ duration: TimeInterval?) -> String {
        guard let duration, duration > 0 else {
            return copy.totalPlaceholderText
        }

        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private func workedDuration(
        startTime: Date?,
        endTime: Date?,
        recordDate: Date,
        currentDate: Date
    ) -> TimeInterval? {
        let effectiveEndTime: Date?

        if let endTime {
            effectiveEndTime = endTime
        } else if startTime != nil, calendar.isDate(recordDate, inSameDayAs: currentDate) {
            effectiveEndTime = currentDate
        } else {
            effectiveEndTime = nil
        }

        return workedDurationCalculator.workedDuration(
            startTime: startTime,
            endTime: effectiveEndTime
        )
    }
}
