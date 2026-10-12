import AppKit
import PomodoroCore
import SwiftUI

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(statusLine)
        Divider()
        Button(primaryTitle) { model.togglePause() }
        if model.status != .idle {
            Button("Skip Phase") { model.skip() }
            Button("Stop") { model.stop() }
        }
        Divider()
        Text("Today: \(TimeFormat.duration(model.summary.todaySeconds)) · \(model.summary.todaySessions) sessions")
        Button("Statistics…") {
            WindowPresenter.shared.show(id: "stats", title: "Statistics") { StatsView(model: model) }
        }
        Button("Settings…") {
            WindowPresenter.shared.show(id: "settings", title: "Settings") { SettingsView(model: model) }
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Pomodoro") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var primaryTitle: String {
        switch model.status {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        }
    }

    private var statusLine: String {
        guard let phase = model.phase else {
            return "Ready — \(model.settings.workMinutes) min × \(model.settings.repeats)"
        }
        let name = phase.kind == .work ? "Work" : "Break"
        let base = "\(name) \(phase.cycle)/\(model.totalCycles) — \(TimeFormat.clock(model.remaining))"
        switch model.status {
        case .paused(.user): return base + " (paused)"
        case .paused(.idle): return base + " (paused — idle)"
        case .paused(.sleep): return base + " (paused — sleep)"
        default: return base
        }
    }
}
