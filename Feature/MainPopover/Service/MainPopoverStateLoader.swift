import Foundation

struct LoadedMainPopoverState {
    let viewState: MainPopoverViewState
    let todayRecord: AttendanceRecord?
}

struct MainPopoverStateLoader {
    private let recordStore: any AttendanceRecordStore
    private let viewStateFactory: MainPopoverViewStateFactory
    private let totalsCalculator: AttendanceRecordTotalsCalculator
    private let calendar: Calendar

    init(
        recordStore: any AttendanceRecordStore,
        viewStateFactory: MainPopoverViewStateFactory = MainPopoverViewStateFactory(),
        totalsCalculator: AttendanceRecordTotalsCalculator = AttendanceRecordTotalsCalculator(),
        calendar: Calendar = .current
    ) {
        self.recordStore = recordStore
        self.viewStateFactory = viewStateFactory
        self.totalsCalculator = totalsCalculator
        self.calendar = calendar
    }

    func load(referenceDate: Date) -> LoadedMainPopoverState {
        let records = recordStore.loadRecords()
        let todayRecord = records.last {
            calendar.isDate($0.date, inSameDayAs: referenceDate)
        }
        let weeklyTotalText = format(
            totalsCalculator.weeklyTotal(
                records: records,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
        let monthlyTotalText = format(
            totalsCalculator.monthlyTotal(
                records: records,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )

        return LoadedMainPopoverState(
            viewState: viewStateFactory.make(
                referenceDate: referenceDate,
                todayRecord: todayRecord,
                weeklyTotalText: weeklyTotalText,
                monthlyTotalText: monthlyTotalText
            ),
            todayRecord: todayRecord
        )
    }

    private func format(_ duration: TimeInterval) -> String {
        guard duration > 0 else {
            return MainPopoverViewState.placeholder.weeklyTotalText
        }

        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}
