import AppKit
import PomodoroCore
import SwiftUI

/// The panel shown when clicking the menu bar icon: time left in a progress ring, session dots, and controls.
struct PopoverView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            header
            ring
            sessionDots
            controls
            todayLine
            Divider()
            footer
        }
        .padding(20)
        .frame(width: 280)
        .onAppear { model.refreshSummary() } // keeps "Today" correct after midnight
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Text(phaseTitle)
                .font(.headline)
                .foregroundStyle(tint)
            Spacer()
            Text(sessionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            VStack(spacing: 2) {
                Text(TimeFormat.clock(timeLeft))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
    }

    private var sessionDots: some View {
        HStack(spacing: 6) {
            ForEach(1...max(dotCount, 1), id: \.self) { cycle in
                Circle()
                    .fill(cycle <= completedCycles ? tint : tint.opacity(0.2))
                    .overlay(Circle().stroke(tint, lineWidth: cycle == currentWorkCycle ? 1.5 : 0))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 24) {
            roundButton("forward.end.fill", size: 36, filled: false) { model.skip() }
                .help("Skip phase")
                .disabled(isIdle)
                .opacity(isIdle ? 0.35 : 1)
            roundButton(model.status == .running ? "pause.fill" : "play.fill", size: 56, filled: true) {
                model.togglePause()
            }
            .help(primaryHelp)
            .keyboardShortcut(.space, modifiers: [])
            roundButton("stop.fill", size: 36, filled: false) { model.stop() }
                .help("Stop")
                .disabled(isIdle)
                .opacity(isIdle ? 0.35 : 1)
        }
    }

    private var todayLine: some View {
        HStack {
            Label("Today", systemImage: "flame.fill")
                .foregroundStyle(.secondary)
            Spacer()
            let sessions = model.summary.todaySessions
            Text("\(TimeFormat.duration(model.summary.todaySeconds)) · \(sessions) \(sessions == 1 ? "session" : "sessions")")
                .monospacedDigit()
        }
        .font(.callout)
    }

    private var footer: some View {
        HStack {
            footerButton("Statistics", symbol: "chart.bar.fill") {
                WindowPresenter.shared.show(id: "stats", title: "Statistics") { StatsView(model: model) }
            }
            Spacer()
            footerButton("Settings", symbol: "gearshape.fill") {
                WindowPresenter.shared.show(id: "settings", title: "Settings") { SettingsView(model: model) }
            }
            .keyboardShortcut(",")
            Spacer()
            footerButton("Quit", symbol: "power") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    // MARK: Building blocks

    private func roundButton(_ symbol: String, size: CGFloat, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(filled ? Color.white : Color.primary)
                .frame(width: size, height: size)
                .background(filled ? AnyShapeStyle(tint) : AnyShapeStyle(.quaternary), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func footerButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Derived state

    private var isIdle: Bool { model.status == .idle }

    private var timeLeft: TimeInterval {
        isIdle ? TimeInterval(model.settings.workMinutes * 60) : model.remaining
    }

    private var progress: Double {
        guard let phase = model.phase, phase.duration > 0 else { return 1 }
        return model.remaining / phase.duration
    }

    private var tint: Color {
        if case .paused = model.status { return .gray }
        return model.phase?.kind == .rest
            ? Color(red: 0.25, green: 0.70, blue: 0.45)
            : Color(red: 0.93, green: 0.33, blue: 0.27)
    }

    private var phaseTitle: String {
        guard let phase = model.phase else { return "Ready" }
        return phase.kind == .work ? "Focus" : "Break"
    }

    private var sessionText: String {
        guard let phase = model.phase else {
            return "\(model.settings.repeats) × \(model.settings.workMinutes) min"
        }
        return "Session \(phase.cycle) of \(model.totalCycles)"
    }

    private var subtitle: String {
        switch model.status {
        case .idle: "ready to focus"
        case .running: "remaining"
        case .paused(.user): "paused"
        case .paused(.idle): "paused — you're away"
        case .paused(.sleep): "paused — Mac slept"
        }
    }

    private var primaryHelp: String {
        switch model.status {
        case .idle: "Start (Space)"
        case .running: "Pause (Space)"
        case .paused: "Resume (Space)"
        }
    }

    private var dotCount: Int { isIdle ? model.settings.repeats : model.totalCycles }

    private var completedCycles: Int {
        guard let phase = model.phase else { return 0 }
        return phase.kind == .work ? phase.cycle - 1 : phase.cycle
    }

    private var currentWorkCycle: Int? {
        model.phase?.kind == .work ? model.phase?.cycle : nil
    }
}
