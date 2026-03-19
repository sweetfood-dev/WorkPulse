import Foundation

struct TodayStartTimeDisplayModel: Equatable {
    let text: String
    let isHidden: Bool
}

struct TodayStartTimeDisplayModelFactory {
    let placeholderText: String
    let prefixText: String
    let timeFormatter: AttendanceTimeFormatter

    func make(
        startTime: Date?,
        todayRecord: AttendanceTimeRecord?
    ) -> TodayStartTimeDisplayModel {
        guard startTime != nil else {
            return TodayStartTimeDisplayModel(text: placeholderText, isHidden: false)
        }

        guard let todayRecord else {
            return TodayStartTimeDisplayModel(text: "", isHidden: true)
        }

        return TodayStartTimeDisplayModel(
            text: prefixText + timeFormatter.string(from: todayRecord.startTime),
            isHidden: false
        )
    }
}
