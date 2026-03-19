import Foundation
import Testing
@testable import WorkPulse

struct WeeklyTargetProgressSemanticStyleResolverTests {
    private let resolver = WeeklyTargetProgressSemanticStyleResolver()

    @Test("resolver maps remaining status to caution style")
    func resolverMapsRemainingStatusToCautionStyle() {
        let progress = WeeklyTargetProgress(
            totalWorkedDuration: 31.5 * 60 * 60,
            status: .remaining(8.5 * 60 * 60)
        )

        #expect(resolver.style(for: progress) == .caution)
    }

    @Test("resolver maps met status to success style")
    func resolverMapsMetStatusToSuccessStyle() {
        let progress = WeeklyTargetProgress(
            totalWorkedDuration: WeeklyTargetConfiguration.standard.duration,
            status: .met
        )

        #expect(resolver.style(for: progress) == .success)
    }

    @Test("resolver maps overtime status to danger style")
    func resolverMapsOvertimeStatusToDangerStyle() {
        let progress = WeeklyTargetProgress(
            totalWorkedDuration: 44.25 * 60 * 60,
            status: .overtime(4.25 * 60 * 60)
        )

        #expect(resolver.style(for: progress) == .danger)
    }
}
