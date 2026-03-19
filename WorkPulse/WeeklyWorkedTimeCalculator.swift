import Foundation

struct WeeklyWorkedTimeCalculator {
    let calendar: Calendar
    let weekMatcher: AttendanceWeekMatcher

    init(calendar: Calendar) {
        self.calendar = calendar
        weekMatcher = AttendanceWeekMatcher(calendar: calendar)
    }

    func workedDuration(
        records: [AttendanceRecord],
        referenceDate: Date
    ) -> TimeInterval? {
        let weeklyRecords = weeklyRecords(
            from: records,
            referenceDate: referenceDate
        )

        guard !weeklyRecords.isEmpty else { return nil }

        return weeklyRecords.reduce(into: TimeInterval.zero) { partialResult, record in
            partialResult += record.endTime.timeIntervalSince(record.startTime)
        }
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
