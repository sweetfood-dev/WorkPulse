import Foundation

struct AttendanceMonthMatcher {
    let calendar: Calendar

    func contains(_ date: Date, inSameMonthAs referenceDate: Date) -> Bool {
        guard let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) else {
            return false
        }

        return monthInterval.contains(date)
    }
}
