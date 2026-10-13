import Foundation

public struct WorkRecord: Codable, Equatable {
    public let start: Date
    public let seconds: Int
    public let completed: Bool
    /// Seconds per front app, summing to `seconds`. Nil for older records or when tracking is off.
    public let apps: [String: Int]?

    public init(start: Date, seconds: Int, completed: Bool, apps: [String: Int]? = nil) {
        self.start = start
        self.seconds = seconds
        self.completed = completed
        self.apps = apps
    }
}
