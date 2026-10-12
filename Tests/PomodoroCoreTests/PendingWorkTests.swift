import XCTest
@testable import PomodoroCore

final class PendingWorkTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    var pending: PendingWork {
        PendingWork(record: WorkRecord(start: t0, seconds: 1500, completed: true), phaseEnd: t0 + 1500)
    }

    func testWaitsWhileIdleUnderThreshold() {
        XCTAssertNil(pending.resolve(now: t0 + 1510, idleSeconds: 50, threshold: 60))
    }

    func testLogsFullRecordWhenUserComesBackBeforeThreshold() {
        XCTAssertEqual(pending.resolve(now: t0 + 1510, idleSeconds: 0.5, threshold: 60),
                       WorkRecord(start: t0, seconds: 1500, completed: true))
    }

    func testTrimsIdleTimeInsideThePhaseOnceThresholdReached() {
        // Idle for 60 s at t0+1520 → went idle at t0+1460, so 40 s of the phase were idle.
        XCTAssertEqual(pending.resolve(now: t0 + 1520, idleSeconds: 60, threshold: 60),
                       WorkRecord(start: t0, seconds: 1460, completed: true))
    }

    func testTrimNeverGoesNegative() {
        XCTAssertEqual(pending.resolve(now: t0 + 1500, idleSeconds: 5000, threshold: 60)?.seconds, 0)
    }
}
