import AppKit
import PomodoroCore

enum TomatoState: Hashable {
    case ripening(Int) // Ripeness step
    case rest, paused, idle
}

/// The menu bar tomato, drawn in code (SF Symbols has no tomato) and cached per state.
@MainActor
enum TomatoImage {
    private static var cache: [TomatoState: NSImage] = [:]

    static func image(for state: TomatoState) -> NSImage {
        if let cached = cache[state] { return cached }
        let fruit = fruitColor(for: state)
        let leaf = state == .paused ? NSColor.secondaryLabelColor : NSColor(red: 0.13, green: 0.47, blue: 0.24, alpha: 1)
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            fruit.setFill()
            NSBezierPath(ovalIn: NSRect(x: 1.5, y: 0.5, width: 15, height: 14)).fill()
            leaf.setFill()
            NSBezierPath(ovalIn: NSRect(x: 4, y: 12, width: 5, height: 3)).fill()
            NSBezierPath(ovalIn: NSRect(x: 9, y: 12, width: 5, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 8.25, y: 13, width: 1.5, height: 4.5)).fill()
            return true
        }
        image.isTemplate = false // keep the colour; a template image would be drawn monochrome
        cache[state] = image
        return image
    }

    private static func fruitColor(for state: TomatoState) -> NSColor {
        let rgb: RGB
        switch state {
        case .ripening(let step): rgb = Ripeness.color(step: step)
        case .rest, .idle: rgb = Ripeness.red
        case .paused: return .secondaryLabelColor
        }
        return NSColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}
