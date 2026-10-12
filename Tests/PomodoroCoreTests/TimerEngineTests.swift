import XCTest
@testable import PomodoroCore

final class TimerEngineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let work1 = Phase(kind: .work, cycle: 1, duration: 1500)
    let rest1 = Phase(kind: .rest, cycle: 1, duration: 300)
    let work2 = Phase(kind: .work, cycle: 2, duration: 1500)

    func settings(work: Int = 25, rest: Int = 5, repeats: Int = 2) -> PomodoroSettings {
        var settings = PomodoroSettings()
        settings.workMinutes = work
        settings.breakMinutes = rest
        settings.repeats = repeats
        return settings
    }

    func startedEngine(repeats: Int = 2) -> TimerEngine {
        let engine = TimerEngine()
        engine.start(settings: settings(repeats: repeats), now: t0)
        return engine
    }

    func testPhasePlanAlternatesAndOmitsTrailingBreak() {
        let phases = PhasePlan.phases(for: settings(repeats: 3))
        XCTAssertEqual(phases.map(\.kind), [.work, .rest, .work, .rest, .work])
        XCTAssertEqual(phases.map(\.cycle), [1, 1, 2, 2, 3])
        XCTAssertEqual(phases[0].duration, 1500)
        XCTAssertEqual(phases[1].duration, 300)
    }

    func testStartBeginsFirstWorkPhase() {
        let engine = startedEngine()
        XCTAssertEqual(engine.status, .running)
        XCTAssertEqual(engine.currentPhase, work1)
        XCTAssertEqual(engine.remaining, 1500)
        XCTAssertEqual(engine.totalCycles, 2)
    }

    func testTickCountsDown() {
        let engine = startedEngine()
        XCTAssertEqual(engine.tick(now: t0 + 10), [])
        XCTAssertEqual(engine.remaining, 1490)
    }

    func testTickIgnoredWhenIdle() {
        let engine = TimerEngine()
        XCTAssertEqual(engine.tick(now: t0), [])
        XCTAssertEqual(engine.status, .idle)
        XCTAssertNil(engine.currentPhase)
    }

    func testCompletingWorkLogsAndAdvancesToBreak() {
        let engine = startedEngine()
        XCTAssertEqual(engine.tick(now: t0 + 1500), [
            .workLogged(WorkRecord(start: t0, seconds: 1500, completed: true)),
            .phaseCompleted(work1, next: rest1),
        ])
        XCTAssertEqual(engine.currentPhase, rest1)
        XCTAssertEqual(engine.remaining, 300)
    }

    func testOvershootCarriesIntoNextPhase() {
        let engine = startedEngine()
        engine.tick(now: t0 + 1510)
        XCTAssertEqual(engine.currentPhase, rest1)
        XCTAssertEqual(engine.remaining, 290)
    }

    func testFinishingLastPhaseEmitsFinishedAndGoesIdle() {
        let engine = startedEngine(repeats: 1)
        XCTAssertEqual(engine.tick(now: t0 + 1500), [
            .workLogged(WorkRecord(start: t0, seconds: 1500, completed: true)),
            .phaseCompleted(work1, next: nil),
            .finished,
        ])
        XCTAssertEqual(engine.status, .idle)
        XCTAssertNil(engine.currentPhase)
        XCTAssertEqual(engine.remaining, 0)
    }

    func testHugeGapRunsThroughWholeSequenceOnce() {
        let engine = startedEngine(repeats: 2)
        XCTAssertEqual(engine.tick(now: t0 + 100_000), [
            .workLogged(WorkRecord(start: t0, seconds: 1500, completed: true)),
            .phaseCompleted(work1, next: rest1),
            .phaseCompleted(rest1, next: work2),
            .workLogged(WorkRecord(start: t0 + 1800, seconds: 1500, completed: true)),
            .phaseCompleted(work2, next: nil),
            .finished,
        ])
        XCTAssertEqual(engine.status, .idle)
        XCTAssertEqual(engine.tick(now: t0 + 200_000), [])
    }

    func testPauseAccountsElapsedTimeBeforePausing() {
        let engine = startedEngine()
        engine.pause(reason: .user, now: t0 + 30)
        XCTAssertEqual(engine.status, .paused(.user))
        XCTAssertEqual(engine.remaining, 1470)
    }

    func testPauseFreezesRemainingUntilResume() {
        let engine = startedEngine()
        engine.pause(reason: .user, now: t0 + 10)
        XCTAssertEqual(engine.tick(now: t0 + 100), [])
        XCTAssertEqual(engine.remaining, 1490)
        engine.resume(now: t0 + 100)
        engine.tick(now: t0 + 105)
        XCTAssertEqual(engine.remaining, 1485)
    }

    func testPauseKeepsOriginalReason() {
        let engine = startedEngine()
        engine.pause(reason: .user, now: t0 + 10)
        engine.pause(reason: .idle, now: t0 + 20)
        XCTAssertEqual(engine.status, .paused(.user))
    }
}
