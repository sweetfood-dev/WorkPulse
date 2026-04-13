import Foundation
import SwiftData

protocol AttendanceRecordQuerying {
    func record(on date: Date, calendar: Calendar) -> AttendanceRecord?
    func records(equalTo date: Date, toGranularity granularity: Calendar.Component, calendar: Calendar) -> [AttendanceRecord]
}

protocol AttendanceRecordWriting {
    func upsertRecord(_ record: AttendanceRecord) throws
    func deleteRecord(on date: Date, calendar: Calendar) throws
}

protocol AttendanceRecordStore: AttendanceRecordQuerying, AttendanceRecordWriting {}

struct MirroredAttendanceRecordStore: AttendanceRecordStore {
    private let primary: any AttendanceRecordStore
    private let fallback: any AttendanceRecordStore

    init(
        primary: any AttendanceRecordStore,
        fallback: any AttendanceRecordStore
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func record(on date: Date, calendar: Calendar) -> AttendanceRecord? {
        primary.record(on: date, calendar: calendar)
            ?? fallback.record(on: date, calendar: calendar)
    }

    func records(equalTo date: Date, toGranularity granularity: Calendar.Component, calendar: Calendar) -> [AttendanceRecord] {
        let primaryRecords = primary.records(
            equalTo: date,
            toGranularity: granularity,
            calendar: calendar
        )

        return primaryRecords.isEmpty
            ? fallback.records(equalTo: date, toGranularity: granularity, calendar: calendar)
            : primaryRecords
    }

    func upsertRecord(_ record: AttendanceRecord) throws {
        try primary.upsertRecord(record)
        try fallback.upsertRecord(record)
    }

    func deleteRecord(on date: Date, calendar: Calendar) throws {
        try primary.deleteRecord(on: date, calendar: calendar)
        try fallback.deleteRecord(on: date, calendar: calendar)
    }
}

@Model
final class AttendanceRecordEntity {
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var isVacation: Bool

    init(date: Date, startTime: Date?, endTime: Date?, isVacation: Bool = false) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.isVacation = isVacation
    }

    convenience init(record: AttendanceRecord) {
        self.init(
            date: record.date,
            startTime: record.startTime,
            endTime: record.endTime,
            isVacation: record.isVacation
        )
    }

    var attendanceRecord: AttendanceRecord {
        AttendanceRecord(
            date: date,
            startTime: startTime,
            endTime: endTime,
            isVacation: isVacation
        )
    }
}

final class SwiftDataAttendanceRecordStore: AttendanceRecordStore {
    private let modelContext: ModelContext
    private let calendar: Calendar

    init(
        modelContainer: ModelContainer,
        calendar: Calendar = .current,
        legacyRecords: [AttendanceRecord] = []
    ) throws {
        self.modelContext = ModelContext(modelContainer)
        self.calendar = calendar
        try migrateIfNeeded(from: legacyRecords)
    }

    convenience init(
        calendar: Calendar = .current,
        legacyRecords: [AttendanceRecord] = []
    ) throws {
        try self.init(
            modelContainer: ModelContainer(for: AttendanceRecordEntity.self),
            calendar: calendar,
            legacyRecords: legacyRecords
        )
    }

    func record(on date: Date, calendar: Calendar) -> AttendanceRecord? {
        loadRecords().last {
            calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    func records(equalTo date: Date, toGranularity granularity: Calendar.Component, calendar: Calendar) -> [AttendanceRecord] {
        loadRecords().filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: granularity)
        }
    }

    func upsertRecord(_ record: AttendanceRecord) throws {
        let entities = loadAllEntities()

        if let entity = entities.last(where: { calendar.isDate($0.date, inSameDayAs: record.date) }) {
            entity.date = record.date
            entity.startTime = record.startTime
            entity.endTime = record.endTime
            entity.isVacation = record.isVacation
        } else {
            modelContext.insert(AttendanceRecordEntity(record: record))
        }

        try saveContext()
    }

    func deleteRecord(on date: Date, calendar: Calendar) throws {
        let matchingEntities = loadAllEntities().filter { calendar.isDate($0.date, inSameDayAs: date) }
        guard matchingEntities.isEmpty == false else {
            return
        }

        matchingEntities.forEach(modelContext.delete)
        try saveContext()
    }

    func loadRecords() -> [AttendanceRecord] {
        loadAllEntities().map(\.attendanceRecord)
    }

    private func migrateIfNeeded(from legacyRecords: [AttendanceRecord]) throws {
        guard loadAllEntities().isEmpty, legacyRecords.isEmpty == false else {
            return
        }

        legacyRecords.forEach {
            modelContext.insert(AttendanceRecordEntity(record: $0))
        }

        try saveContext()
    }

    private func loadAllEntities() -> [AttendanceRecordEntity] {
        do {
            let descriptor = FetchDescriptor<AttendanceRecordEntity>(
                sortBy: [SortDescriptor(\.date)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            assertionFailure("Failed to fetch attendance records: \(error)")
            return []
        }
    }

    private func saveContext() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }
}

struct UserDefaultsAttendanceRecordStore: AttendanceRecordStore {
    private let userDefaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let calendar: Calendar

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "attendance.records",
        calendar: Calendar = .current
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.calendar = calendar

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.decoder = decoder
    }

    func record(on date: Date, calendar: Calendar) -> AttendanceRecord? {
        loadAllRecords().last {
            calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    func records(equalTo date: Date, toGranularity granularity: Calendar.Component, calendar: Calendar) -> [AttendanceRecord] {
        loadAllRecords().filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: granularity)
        }
    }

    func upsertRecord(_ record: AttendanceRecord) throws {
        var records = loadAllRecords()

        if let index = records.lastIndex(where: { calendar.isDate($0.date, inSameDayAs: record.date) }) {
            records[index] = record
        } else {
            records.append(record)
        }

        let data = try encoder.encode(records)
        userDefaults.set(data, forKey: key)
    }

    func deleteRecord(on date: Date, calendar: Calendar) throws {
        let records = loadAllRecords().filter {
            calendar.isDate($0.date, inSameDayAs: date) == false
        }

        let data = try encoder.encode(records)
        userDefaults.set(data, forKey: key)
    }

    func loadRecords() -> [AttendanceRecord] {
        loadAllRecords()
    }

    private func loadAllRecords() -> [AttendanceRecord] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        return (try? decoder.decode([AttendanceRecord].self, from: data)) ?? []
    }
}
