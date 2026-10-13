import Foundation

public enum TimeFormat {
    /// "25:00", "00:59", "1:02:05". Rounds up so the display never reads 00:00 while time remains.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }

    /// "0m", "25m", "1h", "1h 30m".
    public static func duration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = seconds % 3600 / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    /// A two-hour window starting at `start` (0–23): "9–11am", "11am–1pm", "11pm–1am".
    public static func hourRange(start: Int) -> String {
        let end = (start + 2) % 24
        let startSuffix = start < 12 ? "am" : "pm"
        let endSuffix = end < 12 ? "am" : "pm"
        let first = startSuffix == endSuffix ? "\(hour12(start))" : "\(hour12(start))\(startSuffix)"
        return "\(first)–\(hour12(end))\(endSuffix)"
    }

    private static func hour12(_ hour: Int) -> Int {
        hour % 12 == 0 ? 12 : hour % 12
    }
}
