import Foundation

@MainActor
final class MainPopoverCurrentSessionBinder {
    private let copy: MainPopoverCopy
    private let progressPolicy: MainPopoverCurrentSessionProgressPolicy
    private var attendanceState: MainPopoverAttendanceState
    private var currentSessionText: String
    private var currentSessionDuration: TimeInterval?
    private lazy var runtime = MainPopoverCurrentSessionRuntime(
        currentSessionCalculator: currentSessionCalculator,
        currentTimeProvider: currentTimeProvider,
        currentSessionScheduler: currentSessionScheduler,
        placeholderText: copy.currentSessionPlaceholderText,
        onChange: { [weak self] text, duration in
            self?.handleRuntimeUpdate(text: text, duration: duration)
        }
    )

    private let currentSessionCalculator: CurrentSessionCalculator
    private let currentTimeProvider: () -> Date
    private let currentSessionScheduler: any CurrentSessionScheduling

    var onDidChange: (() -> Void)?

    init(
        initialText: String,
        copy: MainPopoverCopy = .english,
        progressPolicy: MainPopoverCurrentSessionProgressPolicy = MainPopoverCurrentSessionProgressPolicy(),
        currentSessionCalculator: CurrentSessionCalculator = CurrentSessionCalculator(),
        currentTimeProvider: @escaping () -> Date,
        currentSessionScheduler: any CurrentSessionScheduling = TimerCurrentSessionScheduler()
    ) {
        self.copy = copy
        self.progressPolicy = progressPolicy
        self.attendanceState = .notCheckedIn
        self.currentSessionText = initialText
        self.currentSessionDuration = nil
        self.currentSessionCalculator = currentSessionCalculator
        self.currentTimeProvider = currentTimeProvider
        self.currentSessionScheduler = currentSessionScheduler
    }

    func load(viewState: MainPopoverViewState) {
        attendanceState = viewState.attendanceState
        currentSessionText = viewState.currentSessionText
        currentSessionDuration = nil
    }

    func apply(startTime: Date?, endTime: Date?) {
        attendanceState = attendanceState(startTime: startTime, endTime: endTime)
        runtime.apply(startTime: startTime, endTime: endTime)
    }

    func begin(startTime: Date?, endTime: Date?) {
        attendanceState = attendanceState(startTime: startTime, endTime: endTime)
        runtime.begin(startTime: startTime, endTime: endTime)
    }

    func stop() {
        runtime.stop()
    }

    func makeRenderModel() -> MainPopoverCurrentSessionRenderModel {
        let isWarningState = progressPolicy.isOverGoal(currentSessionDuration)
        return MainPopoverCurrentSessionRenderModel(
            titleText: titleText(isWarningState: isWarningState),
            valueText: currentSessionText,
            leadingCaptionText: copy.currentSessionLeadingCaption,
            trailingCaptionText: copy.currentSessionTrailingCaption(
                goalDuration: progressPolicy.goalDuration
            ),
            progressFraction: progressPolicy.fraction(for: currentSessionDuration),
            visualState: isWarningState ? .warning : .normal
        )
    }

    private func handleRuntimeUpdate(text: String, duration: TimeInterval?) {
        currentSessionText = text
        currentSessionDuration = duration
        onDidChange?()
    }

    private func titleText(isWarningState: Bool) -> String {
        switch attendanceState {
        case .notCheckedIn:
            return copy.currentSessionReadyTitle
        case .checkedIn:
            return isWarningState ? copy.currentSessionWarningTitle : copy.currentSessionTitle
        case .checkedOut:
            return isWarningState ? copy.workedTodayWarningTitle : copy.workedTodayTitle
        }
    }

    private func attendanceState(startTime: Date?, endTime: Date?) -> MainPopoverAttendanceState {
        if endTime != nil {
            return .checkedOut
        }
        if startTime != nil {
            return .checkedIn
        }
        return .notCheckedIn
    }
}
