import AppKit
import SwiftUI

@MainActor
final class WindowPresenter {
    static let shared = WindowPresenter()
    private var windows: [String: NSWindow] = [:]

    /// Opens (or re-focuses) a window. A menu-bar-only app has to activate itself or the window opens behind others.
    func show<Content: View>(id: String, title: String, content: () -> Content) {
        let window = windows[id] ?? makeWindow(title: title, content: content())
        windows[id] = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow<Content: View>(title: String, content: Content) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
