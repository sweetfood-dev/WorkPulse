import Foundation

enum MonthlyHistoryDayCellActivity: Equatable {
    case outsideMonth
    case empty
    case worked
    case active
}

struct MonthlyHistoryDayCellViewState: Equatable {
    let dayText: String
    let statusText: String
    let annotationText: String?
    let activity: MonthlyHistoryDayCellActivity
    let dayCategory: CalendarDayCategory
    let isDimmed: Bool
}

struct MonthlyHistoryViewState {
    let referenceDate: Date
    let titleText: String
    let monthText: String
    let weekdayTexts: [String]
    let totalLabelText: String
    let totalDurationText: String
    let cells: [MonthlyHistoryDayCellViewState]
}

struct MonthlyHistoryLoader {
    private let recordStore: any AttendanceRecordQuerying
    private let totalsCalculator: AttendanceRecordTotalsCalculator
    private let workedDurationCalculator: WorkedDurationCalculator
    private let calendar: Calendar
    private let calendarDayMetadataProvider: any CalendarDayMetadataProviding
    private let currentDateProvider: () -> Date
    private let copy: MainPopoverCopy
    private let monthFormatter: DateFormatter

    init(
        recordStore: any AttendanceRecordQuerying,
        totalsCalculator: AttendanceRecordTotalsCalculator = AttendanceRecordTotalsCalculator(),
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        calendarDayMetadataProvider: (any CalendarDayMetadataProviding)? = nil,
        currentDateProvider: @escaping () -> Date,
        copy: MainPopoverCopy = .english
    ) {
        self.recordStore = recordStore
        self.totalsCalculator = totalsCalculator
        self.workedDurationCalculator = WorkedDurationCalculator(calendar: calendar)
        self.calendar = calendar
        self.calendarDayMetadataProvider = calendarDayMetadataProvider
            ?? KoreanCalendarDayMetadataProvider(timeZone: timeZone)
        self.currentDateProvider = currentDateProvider
        self.copy = copy

        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.locale = locale
        monthFormatter.timeZone = timeZone
        monthFormatter.dateFormat = "MMMM yyyy"
        self.monthFormatter = monthFormatter
    }

    func load(referenceDate: Date) -> MonthlyHistoryViewState {
        let records = recordStore.records(
            equalTo: referenceDate,
            toGranularity: .month,
            calendar: calendar
        )
        let totalDuration = totalsCalculator.monthlyTotal(
            records: records,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let currentDate = currentDateProvider()
        let monthStart = monthStart(for: referenceDate)

        return MonthlyHistoryViewState(
            referenceDate: monthStart,
            titleText: copy.monthlyHistoryTitle,
            monthText: monthFormatter.string(from: monthStart),
            weekdayTexts: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
            totalLabelText: copy.monthlyHistoryTotalTitle,
            totalDurationText: formatTotalDuration(totalDuration),
            cells: makeDayCells(
                monthStart: monthStart,
                records: records,
                currentDate: currentDate
            )
        )
    }

    private func makeDayCells(
        monthStart: Date,
        records: [AttendanceRecord],
        currentDate: Date
    ) -> [MonthlyHistoryDayCellViewState] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let currentDayStart = calendar.startOfDay(for: currentDate)
        let recordsByDay = Dictionary(
            records.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, newest in newest }
        )
        let leadingPlaceholderCount = calendar.component(.weekday, from: monthStart) - 1
        var cells = Array(
            repeating: MonthlyHistoryDayCellViewState(
                dayText: "",
                statusText: "",
                annotationText: nil,
                activity: .outsideMonth,
                dayCategory: .weekday,
                isDimmed: false
            ),
            count: leadingPlaceholderCount
        )

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else {
                continue
            }

            let record = recordsByDay[calendar.startOfDay(for: date)]
            let isFuture = calendar.startOfDay(for: date) > currentDayStart
            let isToday = calendar.isDate(date, inSameDayAs: currentDate)
            let workedDuration = workedDuration(for: record, date: date, currentDate: currentDate)
            let metadata = calendarDayMetadataProvider.metadata(for: date)

            let activity: MonthlyHistoryDayCellActivity
            let cellStatusText: String

            if isToday, record?.startTime != nil, record?.endTime == nil {
                activity = .active
                cellStatusText = copy.monthlyHistoryActiveText
            } else if let workedDuration, workedDuration > 0 {
                activity = .worked
                cellStatusText = formatWorkedDuration(workedDuration)
            } else {
                activity = .empty
                cellStatusText = statusText(for: metadata)
            }

            cells.append(
                MonthlyHistoryDayCellViewState(
                    dayText: "\(day)",
                    statusText: cellStatusText,
                    annotationText: metadata.holiday?.annotationText,
                    activity: activity,
                    dayCategory: metadata.category,
                    isDimmed: isFuture
                )
            )
        }

        while cells.count.isMultiple(of: 7) == false {
            cells.append(
                MonthlyHistoryDayCellViewState(
                    dayText: "",
                    statusText: "",
                    annotationText: nil,
                    activity: .outsideMonth,
                    dayCategory: .weekday,
                    isDimmed: false
                )
            )
        }

        return cells
    }

    private func monthStart(for date: Date) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? calendar.startOfDay(for: date)
    }

    private func formatWorkedDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(Int(duration) / 60, 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(String(format: "%02dm", minutes))"
    }

    private func formatTotalDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else {
            return "0h 00m"
        }

        return formatWorkedDuration(duration)
    }

    private func statusText(for metadata: CalendarDayMetadata) -> String {
        switch metadata.category {
        case .weekday:
            return "—"
        case .weekend:
            return copy.monthlyHistoryOffText
        case .holiday, .substituteHoliday:
            return copy.monthlyHistoryHolidayText
        }
    }

    private func workedDuration(
        for record: AttendanceRecord?,
        date: Date,
        currentDate: Date
    ) -> TimeInterval? {
        guard let record, let startTime = record.startTime else {
            return nil
        }

        let effectiveEndTime: Date?
        if let endTime = record.endTime {
            effectiveEndTime = endTime
        } else if calendar.isDate(date, inSameDayAs: currentDate) {
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
