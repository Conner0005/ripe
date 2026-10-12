import XCTest
@testable import PomodoroCore

final class AutoPausePolicyTests: XCTestCase {
    func decide(enabled: Bool = true, status: EngineStatus, kind: PhaseKind? = .work, idle: TimeInterval) -> AutoPauseAction {
        AutoPausePolicy.decide(enabled: enabled, status: status, phaseKind: kind, idleSeconds: idle, threshold: 60)
    }

    func testPausesRunningWorkWhenIdlePastThreshold() {
        XCTAssertEqual(decide(status: .running, idle: 61), .pause(rewind: 61))
    }

    func testDoesNothingUnderThreshold() {
        XCTAssertEqual(decide(status: .running, idle: 59), AutoPauseAction.none)
    }

    func testDoesNothingWhenDisabled() {
        XCTAssertEqual(decide(enabled: false, status: .running, idle: 600), AutoPauseAction.none)
    }

    func testNeverPausesDuringBreak() {
        XCTAssertEqual(decide(status: .running, kind: .rest, idle: 600), AutoPauseAction.none)
    }

    func testResumesIdlePauseOnActivity() {
        XCTAssertEqual(decide(status: .paused(.idle), idle: 0.5), .resume)
    }

    func testResumesIdlePauseEvenIfFeatureTurnedOffMeanwhile() {
        XCTAssertEqual(decide(enabled: false, status: .paused(.idle), idle: 0.5), .resume)
    }

    func testStaysPausedWhileStillIdle() {
        XCTAssertEqual(decide(status: .paused(.idle), idle: 120), AutoPauseAction.none)
    }

    func testNeverResumesUserOrSleepPause() {
        XCTAssertEqual(decide(status: .paused(.user), idle: 0), AutoPauseAction.none)
        XCTAssertEqual(decide(status: .paused(.sleep), idle: 0), AutoPauseAction.none)
    }

    func testDoesNothingWhenIdle() {
        XCTAssertEqual(decide(status: .idle, kind: nil, idle: 600), AutoPauseAction.none)
    }
}
