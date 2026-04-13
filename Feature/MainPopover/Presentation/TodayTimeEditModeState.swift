import Foundation

struct TodayTimeEditModeState {
    private(set) var savedStartTime: Date?
    private(set) var savedEndTime: Date?
    private(set) var savedIsVacation = false
    private(set) var draftStartTime: Date?
    private(set) var draftEndTime: Date?
    private(set) var draftIsVacation = false
    private(set) var editingField: TodayTimeField?

    var isEditingStartTime: Bool {
        editingField == .startTime
    }

    var isEditingEndTime: Bool {
        editingField == .endTime
    }

    var hasValidDraftTimes: Bool {
        if draftIsVacation {
            return true
        }

        guard let draftStartTime else {
            return draftEndTime == nil
        }

        guard let draftEndTime else {
            return true
        }

        return draftEndTime >= draftStartTime
    }

    var isVacationSelected: Bool {
        draftIsVacation
    }

    mutating func loadSavedTimes(startTime: Date?, endTime: Date?, isVacation: Bool = false) {
        savedStartTime = startTime
        savedEndTime = endTime
        savedIsVacation = isVacation

        guard editingField == nil else { return }

        draftStartTime = startTime
        draftEndTime = endTime
        draftIsVacation = isVacation
    }

    mutating func beginEditing(_ field: TodayTimeField) {
        guard savedIsVacation == false else { return }
        editingField = field
        draftStartTime = savedStartTime
        draftEndTime = savedEndTime
        draftIsVacation = savedIsVacation
    }

    mutating func updateDraftStartTime(_ startTime: Date) {
        draftStartTime = startTime
    }

    mutating func updateDraftEndTime(_ endTime: Date) {
        draftEndTime = endTime
    }

    mutating func apply() -> (startTime: Date?, endTime: Date?)? {
        guard editingField != nil else { return nil }

        if draftIsVacation {
            savedStartTime = nil
            savedEndTime = nil
        } else {
            savedStartTime = draftStartTime
            savedEndTime = draftEndTime
        }
        savedIsVacation = draftIsVacation
        editingField = nil

        return (savedStartTime, savedEndTime)
    }

    mutating func deleteEndTime() -> (startTime: Date?, endTime: Date?)? {
        guard editingField == .endTime else { return nil }

        savedEndTime = nil
        draftEndTime = nil
        editingField = nil
        savedIsVacation = false
        draftIsVacation = false

        return (savedStartTime, nil)
    }

    mutating func setVacation(_ isVacation: Bool) -> (startTime: Date?, endTime: Date?) {
        savedIsVacation = isVacation
        draftIsVacation = isVacation
        editingField = nil

        if isVacation {
            savedStartTime = nil
            savedEndTime = nil
            draftStartTime = nil
            draftEndTime = nil
        }

        return (savedStartTime, savedEndTime)
    }

    mutating func cancel() {
        draftStartTime = savedStartTime
        draftEndTime = savedEndTime
        draftIsVacation = savedIsVacation
        editingField = nil
    }
}
