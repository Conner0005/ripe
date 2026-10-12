import XCTest
@testable import PomodoroCore

final class LongBreakTests: XCTestCase {
    func settings(repeats: Int, every: Int, enabled: Bool = true) -> PomodoroSettings {
        var settings = PomodoroSettings()
        settings.repeats = repeats
        settings.longBreakEnabled = enabled
        settings.longBreakEvery = every
        settings.longBreakMinutes = 15
        return settings
    }

    func restDurations(_ settings: PomodoroSettings) -> [TimeInterval] {
        PhasePlan.phases(for: settings).filter { $0.kind == .rest }.map(\.duration)
    }

    func testLongBreakAfterEveryNthSession() {
        XCTAssertEqual(restDurations(settings(repeats: 5, every: 2)), [300, 900, 300, 900])
    }

    func testDisabledUsesShortBreaksOnly() {
        XCTAssertEqual(restDurations(settings(repeats: 5, every: 2, enabled: false)), [300, 300, 300, 300])
    }

    func testNoTrailingLongBreak() {
        XCTAssertEqual(restDurations(settings(repeats: 4, every: 4)), [300, 300, 300])
    }

    func testDefaultsAndClamping() {
        let defaults = PomodoroSettings()
        XCTAssertFalse(defaults.longBreakEnabled)
        XCTAssertEqual(defaults.longBreakMinutes, 15)
        XCTAssertEqual(defaults.longBreakEvery, 4)
        var settings = PomodoroSettings()
        settings.longBreakEvery = 1
        settings.longBreakMinutes = 500
        XCTAssertEqual(settings.clamped().longBreakEvery, 2)
        XCTAssertEqual(settings.clamped().longBreakMinutes, 60)
    }

    func testOldSavedSettingsGetLongBreakDefaults() throws {
        let old = Data(#"{"workMinutes":30,"breakMinutes":5,"repeats":4}"#.utf8)
        let settings = try JSONDecoder().decode(PomodoroSettings.self, from: old)
        XCTAssertEqual(settings.workMinutes, 30)
        XCTAssertFalse(settings.longBreakEnabled)
        XCTAssertEqual(settings.longBreakEvery, 4)
    }

    func testHotkeyEnabledByDefaultAndDecodedFromOldData() throws {
        XCTAssertTrue(PomodoroSettings().hotkeyEnabled)
        let old = try JSONDecoder().decode(PomodoroSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(old.hotkeyEnabled)
    }
}
