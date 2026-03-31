import Foundation

struct AttendanceRecordTotalsCalculator {
    func weeklyTotal(
        records: [AttendanceRecord],
        referenceDate: Date,
        calendar: Calendar
    ) -> TimeInterval {
        total(
            records: records,
            referenceDate: referenceDate,
            calendar: calendar,
            granularity: .weekOfYear
        )
    }

    func monthlyTotal(
        records: [AttendanceRecord],
        referenceDate: Date,
        calendar: Calendar
    ) -> TimeInterval {
        total(
            records: records,
            referenceDate: referenceDate,
            calendar: calendar,
            granularity: .month
        )
    }

    private func total(
        records: [AttendanceRecord],
        referenceDate: Date,
        calendar: Calendar,
        granularity: Calendar.Component
    ) -> TimeInterval {
        records.reduce(0) { partialResult, record in
            guard calendar.isDate(record.date, equalTo: referenceDate, toGranularity: granularity) else {
                return partialResult
            }

            guard let startTime = record.startTime, let endTime = record.endTime else {
                return partialResult
            }

            let duration = endTime.timeIntervalSince(startTime)
            guard duration >= 0 else {
                return partialResult
            }

            return partialResult + duration
        }
    }
}
