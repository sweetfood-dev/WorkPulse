import Foundation

enum CalendarDayCategory: Equatable {
    case weekday
    case weekend
    case holiday
    case substituteHoliday
}

struct HolidayMetadata: Equatable {
    let name: String
    let substituteForName: String?

    var annotationText: String {
        guard let substituteForName else {
            return name
        }

        return "\(substituteForName) 대체공휴일"
    }
}

struct CalendarDayMetadata: Equatable {
    let category: CalendarDayCategory
    let holiday: HolidayMetadata?
}

protocol CalendarDayMetadataProviding {
    func metadata(for date: Date) -> CalendarDayMetadata
}
