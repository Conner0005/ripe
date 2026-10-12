import XCTest
@testable import PomodoroCore

final class TimerControlTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func startedEngine() -> TimerEngine {
        var settings = PomodoroSettings()
        settings.workMinutes = 25
        settings.breakMinutes = 5
        settings.repeats = 2
        let engine = TimerEngine()
        engine.start(settings: settings, now: t0)
        return engine
    }

    func testSkipWorkLogsPartialAndStartsBreak() {
        let engine = startedEngine()
        XCTAssertEqual(engine.skip(now: t0 + 600), [
            .workLogged(WorkRecord(start: t0, seconds: 600, completed: false)),
        ])
        XCTAssertEqual(engine.currentPhase, Phase(kind: .rest, cycle: 1, duration: 300))
        XCTAssertEqual(engine.remaining, 300)
        XCTAssertEqual(engine.status, .running)
    }

    func testSkipBreakLogsNothing() {
        let engine = startedEngine()
        engine.tick(now: t0 + 1500)
        XCTAssertEqual(engine.skip(now: t0 + 1600), [])
        XCTAssertEqual(engine.currentPhase, Phase(kind: .work, cycle: 2, duration: 1500))
        XCTAssertEqual(engine.remaining, 1500)
    }

    func testSkipWhilePausedStartsNextPhaseRunning() {
        let engine = startedEngine()
        engine.pause(reason: .user, now: t0 + 10)
        XCTAssertEqual(engine.skip(now: t0 + 50), [
            .workLogged(WorkRecord(start: t0, seconds: 10, completed: false)),
        ])
        XCTAssertEqual(engine.status, .running)
        engine.tick(now: t0 + 60)
        XCTAssertEqual(engine.remaining, 290)
    }

    func testSkipLastPhaseFinishes() {
        let engine = startedEngine()
        engine.tick(now: t0 + 1800)
        let events = engine.skip(now: t0 + 1800)
        XCTAssertEqual(events.last, .finished)
        XCTAssertEqual(engine.status, .idle)
    }

    func testStopLogsPartialWorkAndGoesIdle() {
        let engine = startedEngine()
        XCTAssertEqual(engine.stop(now: t0 + 120), [
            .workLogged(WorkRecord(start: t0, seconds: 120, completed: false)),
        ])
        XCTAssertEqual(engine.status, .idle)
        XCTAssertNil(engine.currentPhase)
        XCTAssertEqual(engine.remaining, 0)
    }

    func testStopImmediatelyLogsNothing() {
        let engine = startedEngine()
        XCTAssertEqual(engine.stop(now: t0), [])
        XCTAssertEqual(engine.status, .idle)
    }

    func testStopWhenIdleDoesNothing() {
        XCTAssertEqual(TimerEngine().stop(now: t0), [])
    }

    func testRewindRestoresTimeButNotPastFullDuration() {
        let engine = startedEngine()
        engine.tick(now: t0 + 100)
        engine.rewind(seconds: 60)
        XCTAssertEqual(engine.remaining, 1460)
        engine.rewind(seconds: 1000)
        XCTAssertEqual(engine.remaining, 1500)
    }

    func testIdleRewindReducesLoggedWork() {
        let engine = startedEngine()
        engine.tick(now: t0 + 600)
        engine.pause(reason: .idle, now: t0 + 600)
        engine.rewind(seconds: 60)
        XCTAssertEqual(engine.stop(now: t0 + 700), [
            .workLogged(WorkRecord(start: t0, seconds: 540, completed: false)),
        ])
    }
}
