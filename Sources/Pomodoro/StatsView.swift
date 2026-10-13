import Charts
import PomodoroCore
import SwiftUI

struct StatsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let summary = model.summary
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                tile("Today", TimeFormat.duration(summary.todaySeconds), "\(summary.todaySessions) sessions")
                tile("Last 7 days", TimeFormat.duration(summary.weekSeconds), " ")
                tile("All time", TimeFormat.duration(summary.allTimeSeconds), "\(summary.allTimeSessions) sessions")
            }
            Chart(summary.last7Days) { day in
                BarMark(
                    x: .value("Day", day.day, unit: .day),
                    y: .value("Minutes", day.seconds / 60)
                )
            }
            .chartYAxisLabel("Minutes")
            .frame(height: 180)
            Divider()
            insights
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { model.refreshSummary() } // "today" rolls over at midnight
    }

    private var insights: some View {
        let records = model.records
        let top = FocusInsights.topApps(records: records, now: Date())
        let best = FocusInsights.bestHours(records: records)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Best focus hours", systemImage: "sun.max.fill")
                Spacer()
                Text(best.map(TimeFormat.hourRange) ?? "after \(FocusInsights.minimumSessions) sessions")
                    .foregroundStyle(best == nil ? .secondary : .primary)
            }
            Text("Top apps this week").font(.headline)
            if top.isEmpty {
                Text("No app data yet").foregroundStyle(.secondary)
            } else {
                ForEach(top) { app in appRow(app, max: top[0].seconds) }
            }
        }
    }

    private func appRow(_ app: AppTime, max: Int) -> some View {
        HStack(spacing: 8) {
            Text(app.name).frame(width: 120, alignment: .leading).lineLimit(1)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.93, green: 0.33, blue: 0.27))
                    .frame(width: geo.size.width * CGFloat(app.seconds) / CGFloat(Swift.max(max, 1)))
            }
            .frame(height: 8)
            Text(TimeFormat.duration(app.seconds)).monospacedDigit().frame(width: 60, alignment: .trailing)
        }
        .font(.callout)
    }

    private func tile(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
