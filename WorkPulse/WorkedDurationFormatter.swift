import Foundation

struct WorkedDurationFormatter {
    func string(from duration: TimeInterval) -> String {
        let workedSeconds = Int(duration)
        let hours = workedSeconds / 3600
        let minutes = workedSeconds % 3600 / 60

        return String(format: "%02d:%02d", hours, minutes)
    }
}
