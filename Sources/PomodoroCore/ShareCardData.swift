import Foundation

/// The numbers on the Instagram Story card. Apps are the Statistics top apps minus the ones the user hid.
public struct ShareCardData: Equatable {
    public let weekSeconds: Int
    public let weekSessions: Int
    public let days: [DayTotal]
    public let bestHoursStart: Int?
    public let apps: [AppTime]

    public init(records: [WorkRecord], now: Date, hiddenApps: Set<String> = [], calendar: Calendar = .current) {
        let summary = StatsSummary(records: records, now: now, calendar: calendar)
        let firstDay = summary.last7Days[0].day
        weekSeconds = summary.weekSeconds
        weekSessions = records.filter { $0.completed && calendar.startOfDay(for: $0.start) >= firstDay }.count
        days = summary.last7Days
        bestHoursStart = FocusInsights.bestHours(records: records, calendar: calendar)
        // Filter after taking the top 5 so the card only ever shows apps the user could see and untick.
        apps = FocusInsights.topApps(records: records, now: now, calendar: calendar).filter { !hiddenApps.contains($0.name) }
    }
}
