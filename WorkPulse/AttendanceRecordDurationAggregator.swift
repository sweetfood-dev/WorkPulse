import Foundation

struct AttendanceRecordDurationAggregator {
    let calendar: Calendar

    func workedDuration(records: [AttendanceRecord]) -> TimeInterval? {
        let latestRecordsByDay = records.reduce(into: [Date: AttendanceRecord]()) { partialResult, record in
            partialResult[calendar.startOfDay(for: record.startTime)] = record
        }

        guard !latestRecordsByDay.isEmpty else { return nil }

        return latestRecordsByDay.values.reduce(into: TimeInterval.zero) { partialResult, record in
            partialResult += record.endTime.timeIntervalSince(record.startTime)
        }
    }
}
