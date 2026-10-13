import Foundation

/// Seconds of focus per front app during one work phase.
public struct AppTally: Equatable {
    public static let otherName = "Other"
    public private(set) var seconds: [String: Int] = [:]

    public init() {}

    public mutating func add(_ app: String?, seconds: Int = 1) {
        self.seconds[app ?? Self.otherName, default: 0] += seconds
    }

    public func scaled(to total: Int) -> [String: Int]? {
        Self.scale(seconds, to: total)
    }

    /// Proportionally rescales so the values sum exactly to `total` (largest-remainder rounding, ties by name).
    /// Logged work is trimmed by auto-pause and idle handling, so the breakdown must follow it. Nil when nothing to store.
    public static func scale(_ apps: [String: Int], to total: Int) -> [String: Int]? {
        let sum = apps.values.reduce(0, +)
        guard total > 0, sum > 0 else { return nil }
        var result: [String: Int] = [:]
        var remainders: [(name: String, remainder: Int)] = []
        for (name, value) in apps {
            let exact = value * total
            result[name] = exact / sum
            remainders.append((name, exact % sum))
        }
        let leftover = total - result.values.reduce(0, +)
        let order = remainders.sorted { $0.remainder != $1.remainder ? $0.remainder > $1.remainder : $0.name < $1.name }
        for entry in order.prefix(leftover) { result[entry.name, default: 0] += 1 }
        let nonZero = result.filter { $0.value > 0 }
        return nonZero.isEmpty ? nil : nonZero
    }
}
