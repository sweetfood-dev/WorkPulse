import CoreGraphics
import Foundation

struct MainPopoverWeeklyProgressDayViewState {
    let dayText: String
    let workedText: String
    let progressFraction: CGFloat
    let isToday: Bool
}

struct MainPopoverWeeklyProgressViewState {
    let titleText: String
    let subtitleText: String
    let totalText: String
    let days: [MainPopoverWeeklyProgressDayViewState]
}

struct MainPopoverWeeklyProgressLoader {
    private let recordStore: any AttendanceRecordQuerying
    private let workedDurationCalculator: WorkedDurationCalculator
    private let calendar: Calendar
    private let currentDateProvider: () -> Date
    private let copy: MainPopoverCopy
    private let dayFormatter: DateFormatter
    private let rangeFormatter: DateFormatter

    init(
        recordStore: any AttendanceRecordQuerying,
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        currentDateProvider: @escaping () -> Date,
        copy: MainPopoverCopy = .english
    ) {
        self.recordStore = recordStore
        self.workedDurationCalculator = WorkedDurationCalculator(calendar: calendar)
        self.calendar = calendar
        self.currentDateProvider = currentDateProvider
        self.copy = copy

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.locale = locale
        dayFormatter.timeZone = timeZone
        dayFormatter.dateFormat = "EEE d"
        self.dayFormatter = dayFormatter

        let rangeFormatter = DateFormatter()
        rangeFormatter.calendar = calendar
        rangeFormatter.locale = locale
        rangeFormatter.timeZone = timeZone
        rangeFormatter.dateFormat = "MMM d"
        self.rangeFormatter = rangeFormatter
    }

    func load(referenceDate: Date) -> MainPopoverWeeklyProgressViewState {
        let weekDates = makeWeekDates(for: referenceDate)
        let currentDate = currentDateProvider()
        let dayStatesWithDuration = weekDates.map { date in
            let record = recordStore.record(on: date, calendar: calendar)
            let duration = workedDuration(
                for: record,
                referenceDate: date,
                currentDate: currentDate
            )

            return (
                MainPopoverWeeklyProgressDayViewState(
                    dayText: dayFormatter.string(from: date),
                    workedText: formatDuration(duration),
                    progressFraction: progressFraction(for: duration),
                    isToday: calendar.isDate(date, inSameDayAs: referenceDate)
                ),
                duration
            )
        }
        let totalDuration = dayStatesWithDuration
            .compactMap(\.1)
            .reduce(0, +)

        return MainPopoverWeeklyProgressViewState(
            titleText: copy.weeklyProgressTitle,
            subtitleText: weekSubtitle(for: weekDates),
            totalText: copy.summaryTotalText(totalDurationText: formatDuration(totalDuration)),
            days: dayStatesWithDuration.map(\.0)
        )
    }

    private func makeWeekDates(for referenceDate: Date) -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return [referenceDate]
        }

        let weekStart = calendar.startOfDay(for: weekInterval.start)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private func weekSubtitle(for dates: [Date]) -> String {
        guard let firstDate = dates.first, let lastDate = dates.last else {
            return ""
        }

        return "\(rangeFormatter.string(from: firstDate)) - \(rangeFormatter.string(from: lastDate))"
    }

    private func workedDuration(
        for record: AttendanceRecord?,
        referenceDate: Date,
        currentDate: Date
    ) -> TimeInterval? {
        guard let record else { return nil }
        let effectiveEndTime: Date?

        if let endTime = record.endTime {
            effectiveEndTime = endTime
        } else if record.startTime != nil, calendar.isDate(referenceDate, inSameDayAs: currentDate) {
            effectiveEndTime = currentDate
        } else {
            effectiveEndTime = nil
        }

        return workedDurationCalculator.workedDuration(
            startTime: record.startTime,
            endTime: effectiveEndTime
        )
    }

    private func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration, duration > 0 else {
            return copy.totalPlaceholderText
        }

        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private func progressFraction(for duration: TimeInterval?) -> CGFloat {
        guard let duration, duration > 0 else { return 0 }

        let fraction = CGFloat(duration / MainPopoverCurrentSessionProgressPolicy.defaultGoalDuration)
        return min(1, max(0, fraction))
    }
}
