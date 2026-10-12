import AppKit
import PomodoroCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: PomodoroSettings {
        didSet { settingsStore.save(settings) }
    }
    @Published private(set) var status: EngineStatus = .idle
    @Published private(set) var phase: Phase?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var totalCycles = 0
    @Published private(set) var summary: StatsSummary

    private let engine = TimerEngine()
    private let settingsStore: SettingsStore
    private let statsStore: StatsStore
    private let notifier = Notifier()
    private var ticker: Timer?
    private var activity: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var sequenceWorkedSeconds = 0

    init() {
        let settingsStore = SettingsStore()
        let statsURL = (try? StatsStore.defaultURL())
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("pomodoro-stats.json")
        let statsStore = StatsStore(fileURL: statsURL)
        self.settingsStore = settingsStore
        self.statsStore = statsStore
        self.settings = settingsStore.load()
        self.summary = StatsSummary(records: statsStore.records, now: Date())

        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pause(reason: .sleep) }
        }
        notifier.requestAuthorization()
    }

    func togglePause() {
        switch status {
        case .idle: start()
        case .running: pause(reason: .user)
        case .paused:
            engine.resume(now: Date())
            sync()
        }
    }

    func skip() {
        handle(engine.skip(now: Date()))
        sync()
    }

    func stop() {
        handle(engine.stop(now: Date()))
        stopTicker()
        sync()
    }

    func refreshSummary() {
        summary = StatsSummary(records: statsStore.records, now: Date())
    }

    private func start() {
        sequenceWorkedSeconds = 0
        engine.start(settings: settings, now: Date())
        startTicker()
        refreshSummary()
        sync()
    }

    private func pause(reason: PauseReason) {
        handle(engine.pause(reason: reason, now: Date()))
        sync()
    }

    // Keeps running while paused so an idle pause can auto-resume.
    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common) // .common keeps ticking while the menu is open
        ticker = timer
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Pomodoro timer running"
        )
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }

    private func tick() {
        let now = Date()
        handle(engine.tick(now: now))
        let action = AutoPausePolicy.decide(
            enabled: settings.autoPauseEnabled,
            status: engine.status,
            phaseKind: engine.currentPhase?.kind,
            idleSeconds: IdleDetector.secondsSinceLastInput(),
            threshold: TimeInterval(settings.idleThresholdSeconds)
        )
        switch action {
        case .pause(let rewind):
            handle(engine.pause(reason: .idle, now: now))
            engine.rewind(seconds: rewind)
        case .resume:
            engine.resume(now: now)
        case .none:
            break
        }
        sync()
    }

    private func handle(_ events: [EngineEvent]) {
        for event in events {
            switch event {
            case .workLogged(let record):
                sequenceWorkedSeconds += record.seconds
                do {
                    try statsStore.append(record)
                } catch {
                    NSLog("Pomodoro: failed to save stats: \(error)")
                }
                refreshSummary()
            case .phaseCompleted(let phase, let next):
                // The last phase is announced by .finished instead.
                if let next {
                    notifier.announce(
                        PhaseMessages.completed(phase, next: next, totalCycles: engine.totalCycles),
                        settings: settings
                    )
                }
            case .finished:
                notifier.announce(PhaseMessages.finished(workedSeconds: sequenceWorkedSeconds), settings: settings)
                stopTicker()
            }
        }
    }

    private func sync() {
        status = engine.status
        phase = engine.currentPhase
        remaining = engine.remaining
        totalCycles = engine.totalCycles
    }
}
