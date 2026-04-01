import Foundation

struct TodayTimeEditModeState {
    private(set) var savedStartTime: Date?
    private(set) var savedEndTime: Date?
    private(set) var draftStartTime: Date?
    private(set) var draftEndTime: Date?
    private(set) var editingField: TodayTimeField?

    var isEditingStartTime: Bool {
        editingField == .startTime
    }

    var isEditingEndTime: Bool {
        editingField == .endTime
    }

    var hasValidDraftTimes: Bool {
        guard let draftStartTime, let draftEndTime else {
            return true
        }

        return draftEndTime >= draftStartTime
    }

    mutating func loadSavedTimes(startTime: Date?, endTime: Date?) {
        savedStartTime = startTime
        savedEndTime = endTime

        guard editingField == nil else { return }

        draftStartTime = startTime
        draftEndTime = endTime
    }

    mutating func beginEditing(_ field: TodayTimeField) {
        editingField = field
        draftStartTime = savedStartTime
        draftEndTime = savedEndTime
    }

    mutating func updateDraftStartTime(_ startTime: Date) {
        draftStartTime = startTime
    }

    mutating func updateDraftEndTime(_ endTime: Date) {
        draftEndTime = endTime
    }

    mutating func apply() -> (startTime: Date?, endTime: Date?)? {
        guard editingField != nil else { return nil }

        savedStartTime = draftStartTime
        savedEndTime = draftEndTime
        editingField = nil

        return (savedStartTime, savedEndTime)
    }

    mutating func cancel() {
        draftStartTime = savedStartTime
        draftEndTime = savedEndTime
        editingField = nil
    }
}
