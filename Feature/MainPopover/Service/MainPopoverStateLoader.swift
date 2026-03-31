import Foundation

struct LoadedMainPopoverState {
    let viewState: MainPopoverViewState
    let todayRecord: AttendanceRecord?
}

struct MainPopoverStateLoader {
    private let recordStore: any AttendanceRecordQuerying
    private let viewStateFactory: MainPopoverViewStateFactory
    private let totalsCalculator: AttendanceRecordTotalsCalculator
    private let calendar: Calendar

    init(
        recordStore: any AttendanceRecordQuerying,
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
        let todayRecord = recordStore.record(on: referenceDate, calendar: calendar)
        let weeklyRecords = recordStore.records(
            equalTo: referenceDate,
            toGranularity: .weekOfYear,
            calendar: calendar
        )
        let monthlyRecords = recordStore.records(
            equalTo: referenceDate,
            toGranularity: .month,
            calendar: calendar
        )
        let weeklyTotalText = format(
            totalsCalculator.weeklyTotal(
                records: weeklyRecords,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
        let monthlyTotalText = format(
            totalsCalculator.monthlyTotal(
                records: monthlyRecords,
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
