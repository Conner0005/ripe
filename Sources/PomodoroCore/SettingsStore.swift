import Foundation

public final class SettingsStore {
    public static let key = "settings.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> PomodoroSettings {
        guard let data = defaults.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(PomodoroSettings.self, from: data)
        else { return PomodoroSettings() }
        return settings.clamped()
    }

    public func save(_ settings: PomodoroSettings) {
        guard let data = try? JSONEncoder().encode(settings.clamped()) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
