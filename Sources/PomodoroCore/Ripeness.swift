import Foundation

public struct RGB: Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// How ripe the menu bar tomato looks: green at the start of a focus session, red at the end.
public enum Ripeness {
    /// Quantised so the menu bar image changes ~24 times a session rather than every second.
    public static let steps = 24
    public static let green = RGB(red: 0.30, green: 0.72, blue: 0.40)
    public static let orange = RGB(red: 0.98, green: 0.60, blue: 0.20)
    public static let red = RGB(red: 0.90, green: 0.25, blue: 0.22)

    public static func step(progress: Double) -> Int {
        guard progress.isFinite else { return 0 }
        let clamped = min(max(progress, 0), 1)
        return min(Int(clamped * Double(steps)), steps - 1)
    }

    public static func color(step: Int) -> RGB {
        color(fraction: Double(min(max(step, 0), steps - 1)) / Double(steps - 1))
    }

    public static func color(fraction: Double) -> RGB {
        let t = min(max(fraction, 0), 1)
        return t <= 0.5 ? mix(green, orange, t * 2) : mix(orange, red, (t - 0.5) * 2)
    }

    private static func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        if t == 0 { return a }
        if t == 1 { return b }
        return RGB(red: a.red + (b.red - a.red) * t,
                   green: a.green + (b.green - a.green) * t,
                   blue: a.blue + (b.blue - a.blue) * t)
    }
}
