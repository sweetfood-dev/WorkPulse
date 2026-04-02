import CoreGraphics
import Foundation

struct MainPopoverWeeklyProgressDayViewState {
    let dayText: String
    let timeRangeText: String
    let workedText: String
    let annotationText: String?
    let dayCategory: CalendarDayCategory
    let progressFraction: CGFloat
    let isToday: Bool
}

struct MainPopoverWeeklyProgressViewState {
    let titleText: String
    let weekText: String
    let totalDurationText: String
    let statusText: String
    let progressFraction: CGFloat
    let visualState: MainPopoverCurrentSessionVisualState
    let days: [MainPopoverWeeklyProgressDayViewState]
}

struct MainPopoverWeeklyProgressLoader {
    private let recordStore: any AttendanceRecordQuerying
    private let workedDurationCalculator: WorkedDurationCalculator
    private let calendar: Calendar
    private let calendarDayMetadataProvider: any CalendarDayMetadataProviding
    private let currentDateProvider: () -> Date
    private let copy: MainPopoverCopy
    private let goalDuration: TimeInterval
    private let dayFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    init(
        recordStore: any AttendanceRecordQuerying,
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        calendarDayMetadataProvider: (any CalendarDayMetadataProviding)? = nil,
        currentDateProvider: @escaping () -> Date,
        copy: MainPopoverCopy = .english
    ) {
        self.recordStore = recordStore
        self.workedDurationCalculator = WorkedDurationCalculator(calendar: calendar)
        self.calendar = calendar
        self.calendarDayMetadataProvider = calendarDayMetadataProvider
            ?? KoreanCalendarDayMetadataProvider(timeZone: timeZone)
        self.currentDateProvider = currentDateProvider
        self.copy = copy
        self.goalDuration = 40 * 60 * 60

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.locale = locale
        dayFormatter.timeZone = timeZone
        dayFormatter.dateFormat = "EEE d"
        self.dayFormatter = dayFormatter

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"
        self.timeFormatter = timeFormatter
    }

    func load(referenceDate: Date) -> MainPopoverWeeklyProgressViewState {
        let weekDates = makeWeekDates(for: referenceDate)
        let currentDate = currentDateProvider()
        let dayStatesWithDuration = weekDates.map { date in
            let record = recordStore.record(on: date, calendar: calendar)
            let metadata = calendarDayMetadataProvider.metadata(for: date)
            let duration = workedDuration(
                for: record,
                referenceDate: date,
                currentDate: currentDate
            )

            return (
                MainPopoverWeeklyProgressDayViewState(
                    dayText: dayFormatter.string(from: date),
                    timeRangeText: makeTimeRangeText(record: record),
                    workedText: formatWorkedDuration(duration),
                    annotationText: metadata.holiday?.annotationText,
                    dayCategory: metadata.category,
                    progressFraction: dailyProgressFraction(for: duration),
                    isToday: calendar.isDate(date, inSameDayAs: referenceDate)
                ),
                duration
            )
        }
        let totalDuration = dayStatesWithDuration
            .compactMap { entry -> TimeInterval? in
                entry.1
            }
            .reduce(0, +)
        let progressFraction = progressFraction(for: totalDuration)
        let weekOfYear = calendar.component(.weekOfYear, from: referenceDate)
        let visualState: MainPopoverCurrentSessionVisualState = totalDuration > goalDuration
            ? .warning
            : .normal

        return MainPopoverWeeklyProgressViewState(
            titleText: copy.weeklyProgressTitle,
            weekText: copy.weeklyLabelText(weekOfYear: weekOfYear),
            totalDurationText: formatTotalDuration(totalDuration),
            statusText: statusText(for: totalDuration, visualState: visualState),
            progressFraction: progressFraction,
            visualState: visualState,
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

    private func makeTimeRangeText(record: AttendanceRecord?) -> String {
        "\(formatTime(record?.startTime)) - \(formatTime(record?.endTime))"
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date else { return copy.timePlaceholderText }
        return timeFormatter.string(from: date)
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

    private func statusText(
        for totalDuration: TimeInterval,
        visualState: MainPopoverCurrentSessionVisualState
    ) -> String {
        switch visualState {
        case .normal:
            let remainingDuration = max(0, goalDuration - totalDuration)
            return copy.weeklyRemainingStatusText(
                durationText: formatStatusDuration(remainingDuration),
                goalHours: Int(goalDuration / 3_600)
            )
        case .warning:
            return copy.weeklyOvertimeStatusText(
                durationText: formatStatusDuration(totalDuration - goalDuration)
            )
        }
    }

    private func formatStatusDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(String(format: "%02d", minutes))m"
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

    private func formatTotalDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private func dailyProgressFraction(for duration: TimeInterval?) -> CGFloat {
        guard let duration, duration > 0 else { return 0 }
        let fraction = CGFloat(duration / MainPopoverCurrentSessionProgressPolicy.defaultGoalDuration)
        return min(1, max(0, fraction))
    }

    private func progressFraction(for duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 0 }
        return min(1, max(0, CGFloat(duration / goalDuration)))
    }
}
