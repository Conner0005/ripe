import Foundation

public struct PomodoroSettings: Codable, Equatable {
    public var workMinutes = 25
    public var breakMinutes = 5
    public var repeats = 4
    public var soundEnabled = true
    public var soundName = "Glass"
    public var notificationsEnabled = true
    public var autoPauseEnabled = false
    public var idleThresholdSeconds = 60
    public var longBreakEnabled = false
    public var longBreakMinutes = 15
    public var longBreakEvery = 4
    public var hotkeyEnabled = true
    public var appTrackingEnabled = true

    public static let workRange = 1...180
    public static let breakRange = 1...60
    public static let repeatsRange = 1...12
    public static let idleThresholdRange = 15...600
    public static let longBreakRange = 1...60
    public static let longBreakEveryRange = 2...12
    public static let soundNames = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    public init() {}

    // Decode key-by-key so data saved by an older version (missing keys) keeps the values it has.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = PomodoroSettings()
        workMinutes = try container.decodeIfPresent(Int.self, forKey: .workMinutes) ?? fallback.workMinutes
        breakMinutes = try container.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? fallback.breakMinutes
        repeats = try container.decodeIfPresent(Int.self, forKey: .repeats) ?? fallback.repeats
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? fallback.soundEnabled
        soundName = try container.decodeIfPresent(String.self, forKey: .soundName) ?? fallback.soundName
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? fallback.notificationsEnabled
        autoPauseEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoPauseEnabled) ?? fallback.autoPauseEnabled
        idleThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .idleThresholdSeconds) ?? fallback.idleThresholdSeconds
        longBreakEnabled = try container.decodeIfPresent(Bool.self, forKey: .longBreakEnabled) ?? fallback.longBreakEnabled
        longBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? fallback.longBreakMinutes
        longBreakEvery = try container.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? fallback.longBreakEvery
        hotkeyEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? fallback.hotkeyEnabled
        appTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .appTrackingEnabled) ?? fallback.appTrackingEnabled
    }

    public func clamped() -> PomodoroSettings {
        var settings = self
        settings.workMinutes = Self.clamp(workMinutes, to: Self.workRange)
        settings.breakMinutes = Self.clamp(breakMinutes, to: Self.breakRange)
        settings.repeats = Self.clamp(repeats, to: Self.repeatsRange)
        settings.idleThresholdSeconds = Self.clamp(idleThresholdSeconds, to: Self.idleThresholdRange)
        settings.longBreakMinutes = Self.clamp(longBreakMinutes, to: Self.longBreakRange)
        settings.longBreakEvery = Self.clamp(longBreakEvery, to: Self.longBreakEveryRange)
        if !Self.soundNames.contains(soundName) {
            settings.soundName = PomodoroSettings().soundName
        }
        return settings
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
