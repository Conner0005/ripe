import Foundation

public struct DayTotal: Equatable, Identifiable {
    public let day: Date
    public let seconds: Int
    public var id: Date { day }
}

public struct StatsSummary: Equatable {
    public let todaySeconds: Int
    public let todaySessions: Int
    public let weekSeconds: Int
    public let allTimeSeconds: Int
    public let allTimeSessions: Int
    /// Oldest first, ending today; always 7 entries.
    public let last7Days: [DayTotal]

    /// A record counts toward the day its work started.
    public init(records: [WorkRecord], now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        var secondsByDay: [Date: Int] = [:]
        for record in records {
            secondsByDay[calendar.startOfDay(for: record.start), default: 0] += record.seconds
        }
        last7Days = (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return DayTotal(day: day, seconds: secondsByDay[day] ?? 0)
        }
        todaySeconds = secondsByDay[today] ?? 0
        todaySessions = records.filter { $0.completed && calendar.isDate($0.start, inSameDayAs: now) }.count
        weekSeconds = last7Days.reduce(0) { $0 + $1.seconds }
        allTimeSeconds = records.reduce(0) { $0 + $1.seconds }
        allTimeSessions = records.filter(\.completed).count
    }
}
