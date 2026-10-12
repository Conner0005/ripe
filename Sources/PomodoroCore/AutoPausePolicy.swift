import Foundation

public enum AutoPauseAction: Equatable {
    case none
    case pause(rewind: TimeInterval)
    case resume
}

public enum AutoPausePolicy {
    /// Input within this many seconds counts as "the user is back".
    public static let activityWindow: TimeInterval = 2

    public static func decide(
        enabled: Bool,
        status: EngineStatus,
        phaseKind: PhaseKind?,
        idleSeconds: TimeInterval,
        threshold: TimeInterval
    ) -> AutoPauseAction {
        switch status {
        case .running:
            // Rewind the whole idle stretch so time away isn't logged as work.
            return enabled && phaseKind == .work && idleSeconds >= threshold ? .pause(rewind: idleSeconds) : .none
        case .paused(.idle):
            return idleSeconds < activityWindow ? .resume : .none
        default:
            return .none
        }
    }
}
