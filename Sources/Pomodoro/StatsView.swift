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
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { model.refreshSummary() } // "today" rolls over at midnight
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
