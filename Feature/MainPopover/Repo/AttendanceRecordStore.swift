import Foundation
import SwiftData

protocol AttendanceRecordQuerying {
    func record(on date: Date, calendar: Calendar) -> AttendanceRecord?
    func records(equalTo date: Date, toGranularity granularity: Calendar.Component, calendar: Calendar) -> [AttendanceRecord]
}

protocol AttendanceRecordWriting {
    func upsertRecord(_ record: AttendanceRecord)
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

    func upsertRecord(_ record: AttendanceRecord) {
        primary.upsertRecord(record)
        fallback.upsertRecord(record)
    }
}

@Model
final class AttendanceRecordEntity {
    var date: Date
    var startTime: Date?
    var endTime: Date?

    init(date: Date, startTime: Date?, endTime: Date?) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
    }

    convenience init(record: AttendanceRecord) {
        self.init(
            date: record.date,
            startTime: record.startTime,
            endTime: record.endTime
        )
    }

    var attendanceRecord: AttendanceRecord {
        AttendanceRecord(
            date: date,
            startTime: startTime,
            endTime: endTime
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
    ) {
        self.modelContext = ModelContext(modelContainer)
        self.calendar = calendar
        migrateIfNeeded(from: legacyRecords)
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

    func upsertRecord(_ record: AttendanceRecord) {
        let entities = loadAllEntities()

        if let entity = entities.last(where: { calendar.isDate($0.date, inSameDayAs: record.date) }) {
            entity.date = record.date
            entity.startTime = record.startTime
            entity.endTime = record.endTime
        } else {
            modelContext.insert(AttendanceRecordEntity(record: record))
        }

        saveContext()
    }

    func loadRecords() -> [AttendanceRecord] {
        loadAllEntities().map(\.attendanceRecord)
    }

    private func migrateIfNeeded(from legacyRecords: [AttendanceRecord]) {
        guard loadAllEntities().isEmpty, legacyRecords.isEmpty == false else {
            return
        }

        legacyRecords.forEach {
            modelContext.insert(AttendanceRecordEntity(record: $0))
        }

        saveContext()
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

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save attendance records: \(error)")
        }
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

    func upsertRecord(_ record: AttendanceRecord) {
        var records = loadAllRecords()

        if let index = records.lastIndex(where: { calendar.isDate($0.date, inSameDayAs: record.date) }) {
            records[index] = record
        } else {
            records.append(record)
        }

        guard let data = try? encoder.encode(records) else { return }
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
