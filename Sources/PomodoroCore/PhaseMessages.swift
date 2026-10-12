import Foundation

public struct PhaseMessage: Equatable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public enum PhaseMessages {
    public static func completed(_ phase: Phase, next: Phase, totalCycles: Int) -> PhaseMessage {
        let nextMinutes = Int(next.duration / 60)
        switch phase.kind {
        case .work:
            return PhaseMessage(
                title: "Work session \(phase.cycle) of \(totalCycles) done",
                body: "Time for a \(nextMinutes)-minute break."
            )
        case .rest:
            return PhaseMessage(
                title: "Break over",
                body: "Starting work session \(next.cycle) of \(totalCycles) (\(nextMinutes) min)."
            )
        }
    }

    public static func finished(workedSeconds: Int) -> PhaseMessage {
        PhaseMessage(title: "All sessions done", body: "You focused for \(TimeFormat.duration(workedSeconds)).")
    }
}
