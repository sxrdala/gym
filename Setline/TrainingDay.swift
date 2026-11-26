import Foundation

enum TrainingDay {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    // Local noon represents a civil day, including across daylight-saving changes.
    static let days: [Date] = {
        let calendar = Self.calendar
        let first = calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 12))!
        return (0..<30).map { calendar.date(byAdding: .day, value: $0, to: first)! }
    }()

    static func key(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func selection(_ saved: String?, today: Date = .now) -> Date {
        if let selected = days.first(where: { key($0) == saved }) { return selected }
        return days.first { key($0) >= key(today) } ?? days[days.count - 1]
    }
}
