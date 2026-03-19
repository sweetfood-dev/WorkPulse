import Foundation

enum WeeklyTargetProgressSemanticStyle: Equatable {
    case caution
    case success
    case danger
}

struct WeeklyTargetProgressSemanticStyleResolver {
    func style(for progress: WeeklyTargetProgress) -> WeeklyTargetProgressSemanticStyle {
        switch progress.status {
        case .remaining:
            return .caution
        case .met:
            return .success
        case .overtime:
            return .danger
        }
    }
}
