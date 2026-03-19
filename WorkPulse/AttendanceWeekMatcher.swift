import Foundation

struct AttendanceWeekMatcher {
    let calendar: Calendar

    func contains(_ date: Date, inSameWeekAs referenceDate: Date) -> Bool {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return false
        }

        return weekInterval.contains(date)
    }
}
