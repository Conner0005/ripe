import XCTest
@testable import PomodoroCore

final class RipenessTests: XCTestCase {
    func testStepBoundaries() {
        XCTAssertEqual(Ripeness.step(progress: 0), 0)
        XCTAssertEqual(Ripeness.step(progress: 0.5), 12)
        XCTAssertEqual(Ripeness.step(progress: 0.999), 23)
        XCTAssertEqual(Ripeness.step(progress: 1), 23)
    }

    func testStepClampsOutOfRange() {
        XCTAssertEqual(Ripeness.step(progress: -0.5), 0)
        XCTAssertEqual(Ripeness.step(progress: 3), 23)
        XCTAssertEqual(Ripeness.step(progress: .nan), 0)
    }

    func testColourEndpointsAndMidpoint() {
        XCTAssertEqual(Ripeness.color(step: 0), Ripeness.green)
        XCTAssertEqual(Ripeness.color(step: 23), Ripeness.red)
        XCTAssertEqual(Ripeness.color(fraction: 0.5), Ripeness.orange)
        XCTAssertEqual(Ripeness.green, RGB(red: 0.30, green: 0.72, blue: 0.40))
        XCTAssertEqual(Ripeness.orange, RGB(red: 0.98, green: 0.60, blue: 0.20))
        XCTAssertEqual(Ripeness.red, RGB(red: 0.90, green: 0.25, blue: 0.22))
    }

    func testColourBetweenGreenAndOrange() {
        let quarter = Ripeness.color(fraction: 0.25)
        XCTAssertEqual(quarter.red, 0.64, accuracy: 0.0001)
        XCTAssertEqual(quarter.green, 0.66, accuracy: 0.0001)
        XCTAssertEqual(quarter.blue, 0.30, accuracy: 0.0001)
    }
}
