import XCTest
@testable import PomodoroCore

final class AppTallyTests: XCTestCase {
    func testAddCountsSecondsPerApp() {
        var tally = AppTally()
        tally.add("Xcode")
        tally.add("Xcode")
        tally.add("Safari")
        tally.add(nil)
        XCTAssertEqual(tally.seconds, ["Xcode": 2, "Safari": 1, "Other": 1])
    }

    func testScaledSumsExactlyToTarget() {
        var tally = AppTally()
        tally.add("Xcode", seconds: 2)
        tally.add("Safari", seconds: 1)
        let scaled = tally.scaled(to: 100)
        XCTAssertEqual(scaled?.values.reduce(0, +), 100)
        XCTAssertEqual(scaled, ["Xcode": 67, "Safari": 33])
    }

    func testScaleTieBreaksByName() {
        // 1 s split between two equal apps: the remainder goes to the alphabetically first.
        XCTAssertEqual(AppTally.scale(["Zed": 5, "Arc": 5], to: 1), ["Arc": 1])
    }

    func testScaleToZeroOrEmptyIsNil() {
        XCTAssertNil(AppTally.scale(["Xcode": 10], to: 0))
        XCTAssertNil(AppTally.scale([:], to: 100))
        XCTAssertNil(AppTally().scaled(to: 100))
    }
}
