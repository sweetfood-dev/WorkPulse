import Foundation

struct WeeklyWorkedTimeCalculator {
    let calendar: Calendar
    let weekMatcher: AttendanceWeekMatcher
    let durationAggregator: AttendanceRecordDurationAggregator

    init(calendar: Calendar) {
        self.calendar = calendar
        weekMatcher = AttendanceWeekMatcher(calendar: calendar)
        durationAggregator = AttendanceRecordDurationAggregator(calendar: calendar)
    }

    func workedDuration(
        records: [AttendanceRecord],
        referenceDate: Date
    ) -> TimeInterval? {
        durationAggregator.workedDuration(records: weeklyRecords(
            from: records,
            referenceDate: referenceDate
        ))
    }

    private func weeklyRecords(
        from records: [AttendanceRecord],
        referenceDate: Date
    ) -> [AttendanceRecord] {
        var weeklyRecords: [AttendanceRecord] = []

        for record in records where weekMatcher.contains(record.startTime, inSameWeekAs: referenceDate) {
            if let existingIndex = weeklyRecords.lastIndex(where: {
                calendar.isDate($0.startTime, inSameDayAs: record.startTime)
            }) {
                weeklyRecords[existingIndex] = record
            } else {
                weeklyRecords.append(record)
            }
        }

        return weeklyRecords
    }
}
