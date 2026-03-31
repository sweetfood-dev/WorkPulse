import Foundation

protocol AttendanceRecordStore {
    func loadRecords() -> [AttendanceRecord]
}

struct UserDefaultsAttendanceRecordStore: AttendanceRecordStore {
    private let userDefaults: UserDefaults
    private let key: String
    private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "attendance.records"
    ) {
        self.userDefaults = userDefaults
        self.key = key

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
}
