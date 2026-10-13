import XCTest
@testable import PomodoroCore

final class SettingsStoreTests: XCTestCase {
    private let suite = "SettingsStoreTests"
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    func testLoadReturnsDefaultsWhenEmpty() {
        let settings = SettingsStore(defaults: defaults).load()
        XCTAssertEqual(settings, PomodoroSettings())
        XCTAssertEqual(settings.workMinutes, 25)
        XCTAssertEqual(settings.breakMinutes, 5)
        XCTAssertEqual(settings.repeats, 4)
        XCTAssertFalse(settings.autoPauseEnabled)
    }

    func testSaveThenLoadRoundTrips() {
        var settings = PomodoroSettings()
        settings.workMinutes = 50
        settings.autoPauseEnabled = true
        settings.soundName = "Ping"
        SettingsStore(defaults: defaults).save(settings)
        XCTAssertEqual(SettingsStore(defaults: defaults).load(), settings)
    }

    func testCorruptDataFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: SettingsStore.key)
        XCTAssertEqual(SettingsStore(defaults: defaults).load(), PomodoroSettings())
    }

    func testMissingKeysUseDefaults() {
        defaults.set(Data(#"{"workMinutes":40}"#.utf8), forKey: SettingsStore.key)
        let settings = SettingsStore(defaults: defaults).load()
        XCTAssertEqual(settings.workMinutes, 40)
        XCTAssertEqual(settings.breakMinutes, 5)
        XCTAssertTrue(settings.notificationsEnabled)
    }

    func testClampsOutOfRangeValues() {
        var settings = PomodoroSettings()
        settings.workMinutes = 0
        settings.repeats = 99
        settings.idleThresholdSeconds = 1
        settings.soundName = "NoSuchSound"
        let clamped = settings.clamped()
        XCTAssertEqual(clamped.workMinutes, 1)
        XCTAssertEqual(clamped.repeats, 12)
        XCTAssertEqual(clamped.idleThresholdSeconds, 15)
        XCTAssertEqual(clamped.soundName, "Glass")
    }

    func testAppTrackingDefaultsOnWhenMissing() {
        defaults.set(Data(#"{"workMinutes":40}"#.utf8), forKey: SettingsStore.key)
        XCTAssertTrue(SettingsStore(defaults: defaults).load().appTrackingEnabled)
    }
}
