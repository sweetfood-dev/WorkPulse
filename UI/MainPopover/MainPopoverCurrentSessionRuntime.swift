import Foundation

@MainActor
final class MainPopoverCurrentSessionRuntime {
    private let currentSessionCalculator: CurrentSessionCalculator
    private let currentTimeProvider: () -> Date
    private let currentSessionScheduler: any CurrentSessionScheduling
    private let placeholderText: String
    private let onChange: (String, TimeInterval?) -> Void
    private var currentSessionRefresh: (any CurrentSessionCancellable)?

    init(
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        currentTimeProvider: @escaping () -> Date,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler(),
        placeholderText: String = MainPopoverCopy.english.currentSessionPlaceholderText,
        onChange: @escaping (String, TimeInterval?) -> Void
    ) {
        self.currentSessionCalculator = currentSessionCalculator
        self.currentTimeProvider = currentTimeProvider
        self.currentSessionScheduler = currentSessionScheduler
        self.placeholderText = placeholderText
        self.onChange = onChange
    }

    deinit {
        currentSessionRefresh?.cancel()
    }

    func apply(startTime: Date?, endTime: Date?) {
        let duration = currentSessionCalculator.sessionDuration(
            startTime: startTime,
            endTime: endTime,
            now: currentTimeProvider()
        )

        onChange(
            duration.map(formatCurrentSessionDuration) ?? placeholderText,
            duration
        )
    }

    func begin(startTime: Date?, endTime: Date?) {
        currentSessionRefresh?.cancel()
        currentSessionRefresh = nil

        apply(startTime: startTime, endTime: endTime)

        guard let startTime, endTime == nil else { return }

        currentSessionRefresh = currentSessionScheduler.scheduleRepeating(
            every: 1
        ) { [weak self] in
            self?.apply(startTime: startTime, endTime: nil)
        }
    }

    func stop() {
        currentSessionRefresh?.cancel()
        currentSessionRefresh = nil
    }
}

private func formatCurrentSessionDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = max(0, Int(duration.rounded(.down)))
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}
