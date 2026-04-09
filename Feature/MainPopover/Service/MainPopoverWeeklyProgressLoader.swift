import CoreGraphics
import Foundation

struct MainPopoverWeeklyProgressDayViewState {
    let date: Date
    let dayText: String
    let timeRangeText: String
    let workedText: String
    let quitDeltaText: String
    let annotationText: String?
    let dayCategory: CalendarDayCategory
    let isOvertime: Bool
    let progressFraction: CGFloat
    let isToday: Bool
    let isSelectable: Bool

    init(
        date: Date = Date(timeIntervalSince1970: 0),
        dayText: String,
        timeRangeText: String,
        workedText: String,
        quitDeltaText: String? = nil,
        annotationText: String?,
        dayCategory: CalendarDayCategory,
        isOvertime: Bool = false,
        progressFraction: CGFloat,
        isToday: Bool,
        isSelectable: Bool = true
    ) {
        self.date = date
        self.dayText = dayText
        self.timeRangeText = timeRangeText
        self.workedText = workedText
        self.quitDeltaText = quitDeltaText ?? workedText
        self.annotationText = annotationText
        self.dayCategory = dayCategory
        self.isOvertime = isOvertime
        self.progressFraction = progressFraction
        self.isToday = isToday
        self.isSelectable = isSelectable
    }
}

struct MainPopoverWeeklyProgressViewState {
    let titleText: String
    let weekText: String
    let totalDurationText: String
    let statusText: String
    let quitTimeStatusText: String
    let todayDeltaStatusText: String
    let todayDeltaVisualState: MainPopoverWeeklyProgressDeltaVisualState
    let progressFraction: CGFloat
    let visualState: MainPopoverCurrentSessionVisualState
    let days: [MainPopoverWeeklyProgressDayViewState]

    init(
        titleText: String,
        weekText: String,
        totalDurationText: String,
        statusText: String,
        quitTimeStatusText: String = "",
        todayDeltaStatusText: String = "",
        todayDeltaVisualState: MainPopoverWeeklyProgressDeltaVisualState = .neutral,
        progressFraction: CGFloat,
        visualState: MainPopoverCurrentSessionVisualState,
        days: [MainPopoverWeeklyProgressDayViewState]
    ) {
        self.titleText = titleText
        self.weekText = weekText
        self.totalDurationText = totalDurationText
        self.statusText = statusText
        self.quitTimeStatusText = quitTimeStatusText
        self.todayDeltaStatusText = todayDeltaStatusText
        self.todayDeltaVisualState = todayDeltaVisualState
        self.progressFraction = progressFraction
        self.visualState = visualState
        self.days = days
    }
}

enum MainPopoverWeeklyProgressDeltaVisualState {
    case neutral
    case remaining
    case overtime
}

private enum MainPopoverWeeklyThroughTodayDelta {
    case neutral
    case remaining(TimeInterval)
    case overtime(TimeInterval)
    case unavailable
}

struct MainPopoverWeeklyProgressLoader {
    private let recordStore: any AttendanceRecordQuerying
    private let workedDurationCalculator: WorkedDurationCalculator
    private let calendar: Calendar
    private let calendarDayMetadataProvider: any CalendarDayMetadataProviding
    private let currentDateProvider: () -> Date
    private let copy: MainPopoverCopy
    private let goalDuration: TimeInterval
    private let quitTimeInsightCalculator: QuitTimeInsightCalculator
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
        self.quitTimeInsightCalculator = QuitTimeInsightCalculator(calendar: calendar)

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
        load(referenceDate: referenceDate, currentDate: currentDateProvider())
    }

    func load(referenceDate: Date, currentDate: Date) -> MainPopoverWeeklyProgressViewState {
        let weekDates = makeWeekDates(for: referenceDate)
        let currentDayStart = calendar.startOfDay(for: currentDate)
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
                    date: date,
                    dayText: dayFormatter.string(from: date),
                    timeRangeText: makeTimeRangeText(record: record),
                    workedText: formatWorkedDuration(duration),
                    quitDeltaText: quitDeltaText(for: duration),
                    annotationText: metadata.holiday?.annotationText,
                    dayCategory: metadata.category,
                    isOvertime: isOvertime(duration),
                    progressFraction: dailyProgressFraction(for: duration),
                    isToday: calendar.isDate(date, inSameDayAs: referenceDate),
                    isSelectable: calendar.startOfDay(for: date) <= currentDayStart
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
        let selectedRecord = recordStore.record(on: referenceDate, calendar: calendar)
        return MainPopoverWeeklyProgressViewState(
            titleText: copy.weeklyProgressTitle,
            weekText: copy.weeklyLabelText(weekOfYear: weekOfYear),
            totalDurationText: formatTotalDuration(totalDuration),
            statusText: statusText(for: totalDuration, visualState: visualState),
            quitTimeStatusText: quitTimeStatusText(
                for: selectedRecord,
                referenceDate: referenceDate,
                currentDate: currentDate
            ),
            todayDeltaStatusText: todayDeltaStatusText(
                for: weekDates,
                currentDate: currentDate
            ),
            todayDeltaVisualState: todayDeltaVisualState(
                for: weekDates,
                currentDate: currentDate
            ),
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

    private func quitDeltaText(for duration: TimeInterval?) -> String {
        guard let duration else {
            return copy.totalPlaceholderText
        }

        let minuteDelta = Int(duration / 60) - Int(MainPopoverCurrentSessionProgressPolicy.defaultGoalDuration / 60)
        if minuteDelta == 0 {
            return "00:00"
        }

        let sign = minuteDelta > 0 ? "+" : "-"
        let absoluteMinutes = abs(minuteDelta)
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }

    private func formatTotalDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private func dailyProgressFraction(for duration: TimeInterval?) -> CGFloat {
        guard let duration, duration > 0 else { return 0 }
        if duration >= MainPopoverCurrentSessionProgressPolicy.defaultGoalDuration {
            return 1
        }
        let fraction = CGFloat(duration / MainPopoverCurrentSessionProgressPolicy.defaultGoalDuration)
        return min(1, max(0, fraction))
    }

    private func progressFraction(for duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 0 }
        if duration >= goalDuration {
            return 1
        }
        return max(0, CGFloat(duration / goalDuration))
    }

    private func isOvertime(_ duration: TimeInterval?) -> Bool {
        guard let duration else { return false }
        return duration >= MainPopoverCurrentSessionProgressPolicy.defaultGoalDuration
    }

    private func quitTimeStatusText(
        for record: AttendanceRecord?,
        referenceDate: Date,
        currentDate: Date
    ) -> String {
        switch quitTimeInsightCalculator.make(record: record) {
        case .noRecord:
            return copy.weeklyNoCheckInStatusText
        case .invalidRecord:
            return copy.weeklyQuitTimeUnavailableText
        case let .available(_, earliestQuitTime, checkoutTime):
            if let checkoutTime {
                let checkoutText = formatTime(checkoutTime)
                return checkoutTime >= earliestQuitTime
                    ? copy.weeklyCheckedOutStatusText(timeText: checkoutText)
                    : copy.weeklyEarlyCheckedOutStatusText(timeText: checkoutText)
            }

            let earliestQuitText = formatTime(earliestQuitTime)
            if calendar.isDate(referenceDate, inSameDayAs: currentDate), currentDate >= earliestQuitTime {
                return copy.weeklyCanQuitStatusText(timeText: earliestQuitText)
            }

            return copy.weeklyQuitTimeStatusText(timeText: earliestQuitText)
        }
    }

    private func todayDeltaStatusText(
        for weekDates: [Date],
        currentDate: Date
    ) -> String {
        switch throughTodayDelta(for: weekDates, currentDate: currentDate) {
        case nil:
            return ""
        case .neutral?:
            return copy.weeklyTodayGoalMetText
        case let .remaining(duration)?:
            return copy.weeklyTodayRemainingStatusText(
                durationText: formatStatusDuration(duration)
            )
        case let .overtime(duration)?:
            return copy.weeklyTodayOvertimeStatusText(
                durationText: formatStatusDuration(duration)
            )
        case .unavailable?:
            return copy.weeklyTodayStatusUnavailableText
        }
    }

    private func todayDeltaVisualState(
        for weekDates: [Date],
        currentDate: Date
    ) -> MainPopoverWeeklyProgressDeltaVisualState {
        switch throughTodayDelta(for: weekDates, currentDate: currentDate) {
        case .remaining?:
            return .remaining
        case .overtime?:
            return .overtime
        case .neutral?, .unavailable?, nil:
            return .neutral
        }
    }

    private func throughTodayDelta(
        for weekDates: [Date],
        currentDate: Date
    ) -> MainPopoverWeeklyThroughTodayDelta? {
        guard let todayDate = weekDates.first(where: { calendar.isDate($0, inSameDayAs: currentDate) }) else {
            return nil
        }

        let currentDayStart = calendar.startOfDay(for: currentDate)
        let priorDates = weekDates.filter { calendar.startOfDay(for: $0) < currentDayStart }
        var delta: TimeInterval = 0

        for date in priorDates {
            let dailyGoalDuration = goalDuration(for: date)
            delta -= dailyGoalDuration

            guard let record = recordStore.record(on: date, calendar: calendar) else {
                continue
            }

            guard let duration = workedDuration(
                for: record,
                referenceDate: date,
                currentDate: currentDate
            ) else {
                return .unavailable
            }

            delta += duration
        }

        guard let todayRecord = recordStore.record(on: todayDate, calendar: calendar) else {
            return deltaState(for: delta)
        }

        guard let todayDuration = workedDuration(
            for: todayRecord,
            referenceDate: todayDate,
            currentDate: currentDate
        ) else {
            return .unavailable
        }

        let todayGoalDuration = goalDuration(for: todayDate)
        if todayRecord.endTime != nil {
            delta += todayDuration - todayGoalDuration
        } else if todayGoalDuration == 0 {
            delta += todayDuration
        } else if todayDuration > todayGoalDuration {
            delta += todayDuration - todayGoalDuration
        }

        return deltaState(for: delta)
    }

    private func goalDuration(for date: Date) -> TimeInterval {
        calendarDayMetadataProvider.metadata(for: date).category == .weekday
            ? MainPopoverCurrentSessionProgressPolicy.defaultGoalDuration
            : 0
    }

    private func deltaState(for delta: TimeInterval) -> MainPopoverWeeklyThroughTodayDelta {
        if delta > 0 {
            return .overtime(delta)
        }
        if delta < 0 {
            return .remaining(abs(delta))
        }
        return .neutral
    }
}
