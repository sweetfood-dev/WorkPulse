import Foundation

protocol AttendanceRecordStore {
    func loadRecords() -> [AttendanceRecord]
    func upsertRecord(_ record: AttendanceRecord)
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

    func loadRecords() -> [AttendanceRecord] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        return (try? decoder.decode([AttendanceRecord].self, from: data)) ?? []
    }

    func upsertRecord(_ record: AttendanceRecord) {
        var records = loadRecords()

        if let index = records.lastIndex(where: { calendar.isDate($0.date, inSameDayAs: record.date) }) {
            records[index] = record
        } else {
            records.append(record)
        }

        guard let data = try? encoder.encode(records) else { return }
        userDefaults.set(data, forKey: key)
    }
}
