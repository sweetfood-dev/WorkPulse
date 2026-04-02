import Foundation

final class KoreanCalendarDayMetadataProvider: CalendarDayMetadataProviding {
    private static let supportedYearRange = 2000...2040

    private enum HolidayKind {
        case newYear
        case independenceDay
        case lunarNewYearEve
        case lunarNewYear
        case lunarNewYearNext
        case buddhasBirthday
        case childrensDay
        case memorialDay
        case liberationDay
        case chuseokEve
        case chuseok
        case chuseokNext
        case nationalFoundationDay
        case hangulDay
        case christmas

        var name: String {
            switch self {
            case .newYear: "신정"
            case .independenceDay: "3·1절"
            case .lunarNewYearEve, .lunarNewYearNext: "설날 연휴"
            case .lunarNewYear: "설날"
            case .buddhasBirthday: "부처님오신날"
            case .childrensDay: "어린이날"
            case .memorialDay: "현충일"
            case .liberationDay: "광복절"
            case .chuseokEve, .chuseokNext: "추석 연휴"
            case .chuseok: "추석"
            case .nationalFoundationDay: "개천절"
            case .hangulDay: "한글날"
            case .christmas: "기독탄신일"
            }
        }
    }

    private enum SubstitutePolicy {
        case sundayOrOtherHoliday
        case weekendOrOtherHoliday
    }

    private struct HolidayRule {
        let kind: HolidayKind
        let policy: SubstitutePolicy?
    }

    private struct HolidayGroup {
        let date: Date
        var names: [String]
        var substitutePolicies: [SubstitutePolicy]

        var displayName: String {
            names.joined(separator: " · ")
        }

        var hasHolidayOverlap: Bool {
            names.count > 1
        }
    }

    private struct HolidayPeriod {
        let groups: [HolidayGroup]

        var endDate: Date {
            groups.last?.date ?? groups[0].date
        }

        var displayName: String {
            groups
                .reduce(into: [String]()) { names, group in
                    for name in group.names where names.contains(name) == false {
                        names.append(name)
                    }
                }
                .joined(separator: " · ")
        }
    }

    private let timeZone: TimeZone
    private let gregorianCalendar: Calendar
    private let lunarCalendar: Calendar
    private let lock = NSLock()
    private var yearCache: [Int: [Date: HolidayMetadata]] = [:]

    init(timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul") ?? .current) {
        self.timeZone = timeZone

        var gregorianCalendar = Calendar(identifier: .gregorian)
        gregorianCalendar.locale = Locale(identifier: "ko_KR")
        gregorianCalendar.timeZone = timeZone
        self.gregorianCalendar = gregorianCalendar

        var lunarCalendar = Calendar(identifier: .chinese)
        lunarCalendar.locale = Locale(identifier: "ko_KR")
        lunarCalendar.timeZone = timeZone
        self.lunarCalendar = lunarCalendar
    }

    func metadata(for date: Date) -> CalendarDayMetadata {
        let normalizedDate = gregorianCalendar.startOfDay(for: date)
        let year = gregorianCalendar.component(.year, from: normalizedDate)

        if let holiday = holidays(for: year)[normalizedDate] {
            let category: CalendarDayCategory = holiday.substituteForName == nil
                ? .holiday
                : .substituteHoliday
            return CalendarDayMetadata(category: category, holiday: holiday)
        }

        if gregorianCalendar.isDateInWeekend(normalizedDate) {
            return CalendarDayMetadata(category: .weekend, holiday: nil)
        }

        return CalendarDayMetadata(category: .weekday, holiday: nil)
    }

    private func holidays(for year: Int) -> [Date: HolidayMetadata] {
        guard Self.supportedYearRange.contains(year) else {
            return [:]
        }

        lock.lock()
        defer { lock.unlock() }

        if let cached = yearCache[year] {
            return cached
        }

        let computed = buildHolidays(for: year)
        yearCache[year] = computed
        return computed
    }

    private func buildHolidays(for year: Int) -> [Date: HolidayMetadata] {
        var groupsByDate: [Date: HolidayGroup] = [:]

        func appendHoliday(on date: Date?, rule: HolidayRule) {
            guard let date else { return }

            let normalizedDate = gregorianCalendar.startOfDay(for: date)
            if var group = groupsByDate[normalizedDate] {
                if group.names.contains(rule.kind.name) == false {
                    group.names.append(rule.kind.name)
                }
                if let policy = rule.policy {
                    group.substitutePolicies.append(policy)
                }
                groupsByDate[normalizedDate] = group
            } else {
                groupsByDate[normalizedDate] = HolidayGroup(
                    date: normalizedDate,
                    names: [rule.kind.name],
                    substitutePolicies: rule.policy.map { [$0] } ?? []
                )
            }
        }

        let seollalDate = makeLunarDate(gregorianYear: year, lunarMonth: 1, lunarDay: 1)
        let chuseokDate = makeLunarDate(gregorianYear: year, lunarMonth: 8, lunarDay: 15)

        appendHoliday(on: makeGregorianDate(year: year, month: 1, day: 1), rule: HolidayRule(kind: .newYear, policy: nil))
        appendHoliday(on: makeGregorianDate(year: year, month: 3, day: 1), rule: HolidayRule(kind: .independenceDay, policy: substitutePolicy(for: .independenceDay, year: year)))
        appendHoliday(on: seollalDate.flatMap { gregorianCalendar.date(byAdding: .day, value: -1, to: $0) }, rule: HolidayRule(kind: .lunarNewYearEve, policy: substitutePolicy(for: .lunarNewYearEve, year: year)))
        appendHoliday(on: seollalDate, rule: HolidayRule(kind: .lunarNewYear, policy: substitutePolicy(for: .lunarNewYear, year: year)))
        appendHoliday(on: seollalDate.flatMap { gregorianCalendar.date(byAdding: .day, value: 1, to: $0) }, rule: HolidayRule(kind: .lunarNewYearNext, policy: substitutePolicy(for: .lunarNewYearNext, year: year)))
        appendHoliday(on: buddhasBirthdayDate(for: year), rule: HolidayRule(kind: .buddhasBirthday, policy: substitutePolicy(for: .buddhasBirthday, year: year)))
        appendHoliday(on: makeGregorianDate(year: year, month: 5, day: 5), rule: HolidayRule(kind: .childrensDay, policy: substitutePolicy(for: .childrensDay, year: year)))
        appendHoliday(on: makeGregorianDate(year: year, month: 6, day: 6), rule: HolidayRule(kind: .memorialDay, policy: nil))
        appendHoliday(on: makeGregorianDate(year: year, month: 8, day: 15), rule: HolidayRule(kind: .liberationDay, policy: substitutePolicy(for: .liberationDay, year: year)))
        appendHoliday(on: chuseokDate.flatMap { gregorianCalendar.date(byAdding: .day, value: -1, to: $0) }, rule: HolidayRule(kind: .chuseokEve, policy: substitutePolicy(for: .chuseokEve, year: year)))
        appendHoliday(on: chuseokDate, rule: HolidayRule(kind: .chuseok, policy: substitutePolicy(for: .chuseok, year: year)))
        appendHoliday(on: chuseokDate.flatMap { gregorianCalendar.date(byAdding: .day, value: 1, to: $0) }, rule: HolidayRule(kind: .chuseokNext, policy: substitutePolicy(for: .chuseokNext, year: year)))
        appendHoliday(on: makeGregorianDate(year: year, month: 10, day: 3), rule: HolidayRule(kind: .nationalFoundationDay, policy: substitutePolicy(for: .nationalFoundationDay, year: year)))
        appendHoliday(on: makeGregorianDate(year: year, month: 10, day: 9), rule: HolidayRule(kind: .hangulDay, policy: substitutePolicy(for: .hangulDay, year: year)))
        appendHoliday(on: makeGregorianDate(year: year, month: 12, day: 25), rule: HolidayRule(kind: .christmas, policy: substitutePolicy(for: .christmas, year: year)))

        var holidaysByDate = groupsByDate.reduce(into: [Date: HolidayMetadata]()) { partialResult, entry in
            partialResult[entry.key] = HolidayMetadata(
                name: entry.value.displayName,
                substituteForName: nil
            )
        }
        for period in holidayPeriods(from: groupsByDate.values.sorted(by: { $0.date < $1.date })) {
            guard qualifiesForSubstitute(period) else {
                continue
            }

            let substituteDate = nextSubstituteDate(
                after: period.endDate,
                blockedDates: Set(holidaysByDate.keys)
            )
            holidaysByDate[substituteDate] = HolidayMetadata(
                name: "대체공휴일",
                substituteForName: period.displayName
            )
        }

        return holidaysByDate
    }

    private func holidayPeriods(from groups: [HolidayGroup]) -> [HolidayPeriod] {
        guard let firstGroup = groups.first else {
            return []
        }

        var periods: [HolidayPeriod] = []
        var currentGroups = [firstGroup]

        for group in groups.dropFirst() {
            let previousDate = currentGroups.last!.date
            let isConsecutiveDay = gregorianCalendar.isDate(
                group.date,
                inSameDayAs: gregorianCalendar.date(byAdding: .day, value: 1, to: previousDate) ?? previousDate
            )

            if isConsecutiveDay {
                currentGroups.append(group)
                continue
            }

            periods.append(HolidayPeriod(groups: currentGroups))
            currentGroups = [group]
        }

        periods.append(HolidayPeriod(groups: currentGroups))
        return periods
    }

    private func qualifiesForSubstitute(_ group: HolidayGroup) -> Bool {
        let weekday = gregorianCalendar.component(.weekday, from: group.date)
        let isSaturday = weekday == 7
        let isSunday = weekday == 1
        let overlapsOtherHoliday = group.hasHolidayOverlap

        for policy in group.substitutePolicies {
            switch policy {
            case .sundayOrOtherHoliday:
                if isSunday || overlapsOtherHoliday {
                    return true
                }
            case .weekendOrOtherHoliday:
                if isSaturday || isSunday || overlapsOtherHoliday {
                    return true
                }
            }
        }

        return false
    }

    private func qualifiesForSubstitute(_ period: HolidayPeriod) -> Bool {
        period.groups.contains(where: qualifiesForSubstitute)
    }

    private func nextSubstituteDate(after date: Date, blockedDates: Set<Date>) -> Date {
        var candidate = date

        while let next = gregorianCalendar.date(byAdding: .day, value: 1, to: candidate) {
            candidate = gregorianCalendar.startOfDay(for: next)
            let weekday = gregorianCalendar.component(.weekday, from: candidate)
            let isSunday = weekday == 1
            let isSaturday = weekday == 7

            if isSunday || isSaturday || blockedDates.contains(candidate) {
                continue
            }

            return candidate
        }

        return gregorianCalendar.startOfDay(for: date)
    }

    private func substitutePolicy(for holidayKind: HolidayKind, year: Int) -> SubstitutePolicy? {
        switch holidayKind {
        case .lunarNewYearEve, .lunarNewYear, .lunarNewYearNext, .chuseokEve, .chuseok, .chuseokNext:
            return year >= 2014 ? .sundayOrOtherHoliday : nil
        case .childrensDay:
            return year >= 2014 ? .weekendOrOtherHoliday : nil
        case .independenceDay, .liberationDay, .nationalFoundationDay, .hangulDay:
            if year >= 2022 {
                return .weekendOrOtherHoliday
            }

            if year == 2021, holidayKind != .independenceDay {
                return .weekendOrOtherHoliday
            }

            return nil
        case .buddhasBirthday:
            return year >= 2023 ? .weekendOrOtherHoliday : nil
        case .christmas:
            if year == 2021 || year >= 2023 {
                return .weekendOrOtherHoliday
            }
            return nil
        case .newYear, .memorialDay:
            return nil
        }
    }

    private func makeGregorianDate(year: Int, month: Int, day: Int) -> Date? {
        gregorianCalendar.date(
            from: DateComponents(
                timeZone: timeZone,
                year: year,
                month: month,
                day: day
            )
        ).map { gregorianCalendar.startOfDay(for: $0) }
    }

    private func makeLunarDate(gregorianYear: Int, lunarMonth: Int, lunarDay: Int) -> Date? {
        guard
            let midYearDate = makeGregorianDate(year: gregorianYear, month: 7, day: 1)
        else {
            return nil
        }

        let chineseYear = lunarCalendar.component(.year, from: midYearDate)
        var components = DateComponents(
            timeZone: timeZone,
            year: chineseYear,
            month: lunarMonth,
            day: lunarDay
        )
        components.isLeapMonth = false
        return lunarCalendar.date(from: components).map { gregorianCalendar.startOfDay(for: $0) }
    }

    private func buddhasBirthdayDate(for year: Int) -> Date? {
        if year == 2023 {
            // Foundation's chinese calendar maps Korean lunar 4/8 to the prior day in 2023.
            return makeGregorianDate(year: 2023, month: 5, day: 27)
        }

        return makeLunarDate(gregorianYear: year, lunarMonth: 4, lunarDay: 8)
    }
}
