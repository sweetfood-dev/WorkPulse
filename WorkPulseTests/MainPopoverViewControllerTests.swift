import AppKit
import Testing
@testable import WorkPulse

@Suite("MainPopoverViewController")
struct MainPopoverViewControllerTests {
    @Test
    @MainActor
    func loadsReadOnlyDashboardPlaceholderState() {
        let controller = MainPopoverViewController()

        controller.loadViewIfNeeded()

        #expect(controller.dateLabel.stringValue == "Today")
        #expect(controller.checkedInSummaryLabel.stringValue == "Checked in at --:--")
        #expect(controller.currentSessionTitleLabel.stringValue == "Current Session")
        #expect(controller.currentSessionValueLabel.stringValue == "--:--:--")
        #expect(controller.startTimeTitleLabel.stringValue == "Start Time")
        #expect(controller.startTimeValueLabel.stringValue == "--:--")
        #expect(controller.endTimeTitleLabel.stringValue == "End Time")
        #expect(controller.endTimeValueLabel.stringValue == "--:--")
        #expect(controller.weeklyTitleLabel.stringValue == "This Week")
        #expect(controller.weeklyValueLabel.stringValue == "--")
        #expect(controller.monthlyTitleLabel.stringValue == "This Month")
        #expect(controller.monthlyValueLabel.stringValue == "--")
    }

    @Test
    @MainActor
    func applyingReadOnlyDashboardStateUpdatesDisplayedValues() {
        let controller = MainPopoverViewController()
        let state = MainPopoverViewState(
            dateText: "Thursday, Mar 31",
            checkedInSummaryText: "Checked in at 09:00",
            currentSessionText: "02:15:30",
            startTimeText: "09:00",
            endTimeText: "--:--",
            weeklyTotalText: "08:30",
            monthlyTotalText: "42:10"
        )

        controller.loadViewIfNeeded()
        controller.apply(state: state)

        #expect(controller.dateLabel.stringValue == "Thursday, Mar 31")
        #expect(controller.checkedInSummaryLabel.stringValue == "Checked in at 09:00")
        #expect(controller.currentSessionValueLabel.stringValue == "02:15:30")
        #expect(controller.startTimeValueLabel.stringValue == "09:00")
        #expect(controller.endTimeValueLabel.stringValue == "--:--")
        #expect(controller.weeklyValueLabel.stringValue == "08:30")
        #expect(controller.monthlyValueLabel.stringValue == "42:10")
    }

    @Test
    @MainActor
    func refreshingCurrentSessionUsesStartTimeAndClockProvider() throws {
        let startTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T09:00:00+09:00")
        )
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-03-31T11:45:30+09:00")
        )
        let controller = MainPopoverViewController(
            currentTimeProvider: { now }
        )

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: startTime)

        #expect(controller.currentSessionValueLabel.stringValue == "02:45:30")
    }

    @Test
    @MainActor
    func refreshingCurrentSessionKeepsPlaceholderWhenStartTimeIsMissing() {
        let controller = MainPopoverViewController(
            currentTimeProvider: { Date(timeIntervalSince1970: 0) }
        )

        controller.loadViewIfNeeded()
        controller.applyCurrentSession(startTime: nil)

        #expect(controller.currentSessionValueLabel.stringValue == "--:--:--")
    }
}
