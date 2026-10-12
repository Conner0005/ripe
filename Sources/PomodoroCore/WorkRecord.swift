import Foundation

public struct WorkRecord: Codable, Equatable {
    public let start: Date
    public let seconds: Int
    public let completed: Bool

    public init(start: Date, seconds: Int, completed: Bool) {
        self.start = start
        self.seconds = seconds
        self.completed = completed
    }
}
