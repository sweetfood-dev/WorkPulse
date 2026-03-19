import Foundation

struct WorkedDurationFormatter {
    func string(from duration: TimeInterval) -> String {
        let workedSeconds = Int(duration)
        let hours = workedSeconds / 3600
        let minutes = workedSeconds % 3600 / 60

        return String(format: "%02d:%02d", hours, minutes)
    }

    func stringIncludingSeconds(from duration: TimeInterval) -> String {
        let workedSeconds = Int(duration)
        let hours = workedSeconds / 3600
        let minutes = workedSeconds % 3600 / 60
        let seconds = workedSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func koreanSummaryString(from duration: TimeInterval) -> String {
        let workedSeconds = Int(duration)
        let hours = workedSeconds / 3600
        let minutes = workedSeconds % 3600 / 60

        if minutes == 0 {
            return "\(hours)시간"
        }

        return "\(hours)시간 \(minutes)분"
    }
}
