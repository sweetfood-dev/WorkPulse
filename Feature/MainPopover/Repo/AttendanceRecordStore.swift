import Foundation

protocol AttendanceRecordQuerying {
    func record(on date: Date, calendar: Calendar) -> AttendanceRecord?
    func records(equalTo date: Date, toGranularity granularity: Calendar.Component, calendar: Calendar) -> [AttendanceRecord]
}

protocol AttendanceRecordWriting {
    func upsertRecord(_ record: AttendanceRecord)
}

protocol AttendanceRecordStore: AttendanceRecordQuerying, AttendanceRecordWriting {}

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
