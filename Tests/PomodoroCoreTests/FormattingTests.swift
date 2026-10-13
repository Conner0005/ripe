import XCTest
@testable import PomodoroCore

final class FormattingTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(TimeFormat.clock(1500), "25:00")
        XCTAssertEqual(TimeFormat.clock(1499.2), "25:00") // rounds up: never show 00:00 while time remains
        XCTAssertEqual(TimeFormat.clock(59), "00:59")
        XCTAssertEqual(TimeFormat.clock(0), "00:00")
        XCTAssertEqual(TimeFormat.clock(-3), "00:00")
        XCTAssertEqual(TimeFormat.clock(3600), "1:00:00")
        XCTAssertEqual(TimeFormat.clock(3725), "1:02:05")
    }

    func testDuration() {
        XCTAssertEqual(TimeFormat.duration(0), "0m")
        XCTAssertEqual(TimeFormat.duration(59), "0m")
        XCTAssertEqual(TimeFormat.duration(1500), "25m")
        XCTAssertEqual(TimeFormat.duration(3600), "1h")
        XCTAssertEqual(TimeFormat.duration(5400), "1h 30m")
    }

    func testWorkCompletedMessage() {
        let message = PhaseMessages.completed(
            Phase(kind: .work, cycle: 1, duration: 1500),
            next: Phase(kind: .rest, cycle: 1, duration: 300),
            totalCycles: 4
        )
        XCTAssertEqual(message, PhaseMessage(title: "Work session 1 of 4 done", body: "Time for a 5-minute break."))
    }

    func testBreakCompletedMessage() {
        let message = PhaseMessages.completed(
            Phase(kind: .rest, cycle: 1, duration: 300),
            next: Phase(kind: .work, cycle: 2, duration: 1500),
            totalCycles: 4
        )
        XCTAssertEqual(message, PhaseMessage(title: "Break over", body: "Starting work session 2 of 4 (25 min)."))
    }

    func testFinishedMessage() {
        XCTAssertEqual(
            PhaseMessages.finished(workedSeconds: 6000),
            PhaseMessage(title: "All sessions done", body: "You focused for 1h 40m.")
        )
    }

    func testHourRange() {
        XCTAssertEqual(TimeFormat.hourRange(start: 9), "9–11am")
        XCTAssertEqual(TimeFormat.hourRange(start: 11), "11am–1pm")
        XCTAssertEqual(TimeFormat.hourRange(start: 10), "10am–12pm")
        XCTAssertEqual(TimeFormat.hourRange(start: 12), "12–2pm")
        XCTAssertEqual(TimeFormat.hourRange(start: 22), "10pm–12am")
        XCTAssertEqual(TimeFormat.hourRange(start: 23), "11pm–1am")
        XCTAssertEqual(TimeFormat.hourRange(start: 0), "12–2am")
    }
}
