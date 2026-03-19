import Foundation

struct MonthlyWorkedTimeCalculator {
    let calendar: Calendar
    let monthMatcher: AttendanceMonthMatcher
    let durationAggregator: AttendanceRecordDurationAggregator

    init(calendar: Calendar) {
        self.calendar = calendar
        monthMatcher = AttendanceMonthMatcher(calendar: calendar)
        durationAggregator = AttendanceRecordDurationAggregator(calendar: calendar)
    }

    func workedDuration(
        records: [AttendanceRecord],
        referenceDate: Date
    ) -> TimeInterval? {
        let monthlyRecords = records.filter {
            monthMatcher.contains($0.startTime, inSameMonthAs: referenceDate)
        }

        return durationAggregator.workedDuration(records: monthlyRecords)
    }
}
