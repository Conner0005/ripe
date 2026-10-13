import Foundation

public struct AppTime: Equatable, Identifiable {
    public let name: String
    public let seconds: Int
    public var id: String { name }

    public init(name: String, seconds: Int) {
        self.name = name
        self.seconds = seconds
    }
}

public enum FocusInsights {
    public static let minimumSessions = 5

    /// Start hour of the two-hour window in which the most completed sessions started; nil until there are enough.
    public static func bestHours(records: [WorkRecord], calendar: Calendar = .current) -> Int? {
        let completed = records.filter(\.completed)
        guard completed.count >= minimumSessions else { return nil }
        var counts = [Int](repeating: 0, count: 24)
        for record in completed { counts[calendar.component(.hour, from: record.start)] += 1 }
        var best = 0
        var bestScore = -1
        for hour in 0..<24 {
            let score = counts[hour] + counts[(hour + 1) % 24]
            if score > bestScore {
                best = hour
                bestScore = score
            }
        }
        return best
    }

    /// Apps with the most focus time over the last 7 days (today and the 6 days before).
    public static func topApps(records: [WorkRecord], now: Date, limit: Int = 5, calendar: Calendar = .current) -> [AppTime] {
        let firstDay = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        var totals: [String: Int] = [:]
        for record in records where calendar.startOfDay(for: record.start) >= firstDay {
            for (name, seconds) in record.apps ?? [:] { totals[name, default: 0] += seconds }
        }
        return totals
            .map { AppTime(name: $0.key, seconds: $0.value) }
            .sorted { $0.seconds != $1.seconds ? $0.seconds > $1.seconds : $0.name < $1.name }
            .prefix(limit)
            .map { $0 }
    }
}
