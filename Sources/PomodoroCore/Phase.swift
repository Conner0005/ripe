import Foundation

public enum PhaseKind: String, Codable, Equatable {
    case work, rest
}

public struct Phase: Equatable {
    public let kind: PhaseKind
    public let cycle: Int
    public let duration: TimeInterval

    public init(kind: PhaseKind, cycle: Int, duration: TimeInterval) {
        self.kind = kind
        self.cycle = cycle
        self.duration = duration
    }
}

public enum PhasePlan {
    /// work, rest, work, rest, …, work — `repeats` work phases and no trailing break.
    public static func phases(for settings: PomodoroSettings) -> [Phase] {
        let settings = settings.clamped()
        var phases: [Phase] = []
        for cycle in 1...settings.repeats {
            phases.append(Phase(kind: .work, cycle: cycle, duration: TimeInterval(settings.workMinutes * 60)))
            if cycle < settings.repeats {
                phases.append(Phase(kind: .rest, cycle: cycle, duration: TimeInterval(settings.breakMinutes * 60)))
            }
        }
        return phases
    }
}
