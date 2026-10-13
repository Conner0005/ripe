import Foundation

/// The numbers on the Instagram Story card. Deliberately has no app names.
public struct ShareCardData: Equatable {
    public let weekSeconds: Int
    public let weekSessions: Int
    public let days: [DayTotal]
    public let bestHoursStart: Int?

    public init(records: [WorkRecord], now: Date, calendar: Calendar = .current) {
        let summary = StatsSummary(records: records, now: now, calendar: calendar)
        let firstDay = summary.last7Days[0].day
        weekSeconds = summary.weekSeconds
        weekSessions = records.filter { $0.completed && calendar.startOfDay(for: $0.start) >= firstDay }.count
        days = summary.last7Days
        bestHoursStart = FocusInsights.bestHours(records: records, calendar: calendar)
    }
}
