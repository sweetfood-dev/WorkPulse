import Foundation

struct AttendanceRecord: Codable, Equatable {
    let date: Date
    let startTime: Date?
    let endTime: Date?
    let isVacation: Bool

    init(
        date: Date,
        startTime: Date?,
        endTime: Date?,
        isVacation: Bool = false
    ) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.isVacation = isVacation
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case startTime
        case endTime
        case isVacation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        isVacation = try container.decodeIfPresent(Bool.self, forKey: .isVacation) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(isVacation, forKey: .isVacation)
    }
}
