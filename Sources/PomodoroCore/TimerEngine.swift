import Foundation

public enum PauseReason: Equatable {
    case user, idle, sleep
}

public enum EngineStatus: Equatable {
    case idle, running, paused(PauseReason)
}

public enum EngineEvent: Equatable {
    case workLogged(WorkRecord)
    case phaseCompleted(Phase, next: Phase?)
    case finished
}

public final class TimerEngine {
    public private(set) var status: EngineStatus = .idle
    public private(set) var phases: [Phase] = []
    public private(set) var remaining: TimeInterval = 0
    private var index = 0
    private var phaseStartedAt = Date.distantPast
    private var lastTick: Date?

    public init() {}

    public var currentPhase: Phase? { status == .idle ? nil : phases[index] }
    public var totalCycles: Int { phases.last?.cycle ?? 0 }

    public func start(settings: PomodoroSettings, now: Date) {
        phases = PhasePlan.phases(for: settings)
        index = 0
        remaining = phases[0].duration
        phaseStartedAt = now
        lastTick = now
        status = .running
    }

    /// Advances by wall-clock time since the last tick. A large gap runs through as many phases as it covers.
    @discardableResult
    public func tick(now: Date) -> [EngineEvent] {
        guard status == .running, let last = lastTick else { return [] }
        var delta = max(0, now.timeIntervalSince(last))
        lastTick = now
        var events: [EngineEvent] = []
        while status == .running {
            let step = min(delta, remaining)
            remaining -= step
            delta -= step
            guard remaining <= 0 else { break }
            events += endCurrentPhase(at: now.addingTimeInterval(-delta), completed: true)
        }
        return events
    }

    /// Counts time up to `now`, then pauses. Does nothing if already paused, so the first reason wins.
    @discardableResult
    public func pause(reason: PauseReason, now: Date) -> [EngineEvent] {
        let events = tick(now: now)
        if status == .running {
            status = .paused(reason)
            lastTick = nil
        }
        return events
    }

    public func resume(now: Date) {
        guard case .paused = status else { return }
        status = .running
        lastTick = now
    }

    /// Ends the current phase early. Partial work is logged; the next phase starts running.
    @discardableResult
    public func skip(now: Date) -> [EngineEvent] {
        var events = tick(now: now)
        guard status != .idle else { return events }
        events += endCurrentPhase(at: now, completed: false)
        if status != .idle {
            status = .running
            lastTick = now
        }
        return events
    }

    @discardableResult
    public func stop(now: Date) -> [EngineEvent] {
        var events = tick(now: now)
        guard status != .idle else { return events }
        if let record = partialWorkRecord() {
            events.append(.workLogged(record))
        }
        status = .idle
        remaining = 0
        lastTick = nil
        return events
    }

    /// Gives back time that shouldn't have counted (e.g. idle time), never beyond the phase length.
    public func rewind(seconds: TimeInterval) {
        guard let phase = currentPhase else { return }
        remaining = min(phase.duration, remaining + max(0, seconds))
    }

    private func partialWorkRecord() -> WorkRecord? {
        guard let phase = currentPhase, phase.kind == .work else { return nil }
        let worked = Int((phase.duration - remaining).rounded())
        return worked >= 1 ? WorkRecord(start: phaseStartedAt, seconds: worked, completed: false) : nil
    }

    private func endCurrentPhase(at date: Date, completed: Bool) -> [EngineEvent] {
        let phase = phases[index]
        var events: [EngineEvent] = []
        if completed {
            if phase.kind == .work {
                events.append(.workLogged(WorkRecord(start: phaseStartedAt, seconds: Int(phase.duration), completed: true)))
            }
        } else if let record = partialWorkRecord() {
            events.append(.workLogged(record))
        }
        index += 1
        let next = index < phases.count ? phases[index] : nil
        if completed {
            events.append(.phaseCompleted(phase, next: next))
        }
        if let next {
            remaining = next.duration
            phaseStartedAt = date
        } else {
            status = .idle
            remaining = 0
            lastTick = nil
            events.append(.finished)
        }
        return events
    }
}
