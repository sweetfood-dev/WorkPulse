import Foundation

struct WorkedTimeDisplayModel: Equatable {
    let statusItemText: String
    let popoverText: String
}

struct WorkedTimeDisplayModelFactory {
    let placeholderTimeText: String
    let popoverPrefixText: String
    let workedTimeCalculator: WorkedTimeCalculator
    let workedDurationFormatter: WorkedDurationFormatter

    func make(
        startTime: Date?,
        endTime: Date?,
        currentDate: Date
    ) -> WorkedTimeDisplayModel {
        guard let workedDuration = workedTimeCalculator.workedDuration(
            startTime: startTime,
            endTime: endTime,
            currentDate: currentDate
        ) else {
            return WorkedTimeDisplayModel(
                statusItemText: placeholderTimeText,
                popoverText: popoverPrefixText + placeholderTimeText
            )
        }

        let timeText = workedDurationFormatter.string(from: workedDuration)

        return WorkedTimeDisplayModel(
            statusItemText: timeText,
            popoverText: popoverPrefixText + timeText
        )
    }
}
