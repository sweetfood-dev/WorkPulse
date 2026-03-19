import Foundation

struct WeeklyTargetConfiguration {
    let duration: TimeInterval

    static let standard = WeeklyTargetConfiguration(duration: 40 * 60 * 60)
}
