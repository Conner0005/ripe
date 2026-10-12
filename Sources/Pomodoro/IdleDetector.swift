import CoreGraphics
import Foundation

enum IdleDetector {
    /// Seconds since the last mouse or keyboard event. Needs no Accessibility permission.
    /// For mouse-only detection use `eventType: .mouseMoved` instead.
    static func secondsSinceLastInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}
