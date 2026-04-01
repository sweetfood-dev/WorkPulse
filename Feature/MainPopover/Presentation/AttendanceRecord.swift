import Foundation

struct AttendanceRecord: Codable, Equatable {
    let date: Date
    let startTime: Date?
    let endTime: Date?
}
