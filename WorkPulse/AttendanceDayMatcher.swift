import Foundation

struct AttendanceDayMatcher {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func isInSameDay(_ date: Date, as referenceDate: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: referenceDate)
    }
}
