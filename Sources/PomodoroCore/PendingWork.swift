import Foundation

/// A completed work record held back because the user was idle when the phase ended.
/// Auto-pause only acts during work, so without this, walking away near the end would log the idle tail as work.
public struct PendingWork: Equatable {
    public let record: WorkRecord
    public let phaseEnd: Date

    public init(record: WorkRecord, phaseEnd: Date) {
        self.record = record
        self.phaseEnd = phaseEnd
    }

    /// The record to log now, or nil to keep waiting.
    public func resolve(now: Date, idleSeconds: TimeInterval, threshold: TimeInterval) -> WorkRecord? {
        // Back before the threshold: counts in full, like a short idle mid-phase.
        if idleSeconds < AutoPausePolicy.activityWindow { return record }
        guard idleSeconds >= threshold else { return nil }
        let idleInPhase = max(0, idleSeconds - now.timeIntervalSince(phaseEnd))
        let seconds = max(0, record.seconds - Int(idleInPhase.rounded()))
        return WorkRecord(start: record.start, seconds: seconds, completed: record.completed,
                          apps: record.apps.flatMap { AppTally.scale($0, to: seconds) })
    }
}
