import AppKit
import PomodoroCore
import UserNotifications

final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    // UNUserNotificationCenter crashes in a process without a bundle identifier (e.g. `swift run`).
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func requestAuthorization() {
        guard let center else { return }
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func announce(_ message: PhaseMessage, settings: PomodoroSettings) {
        if settings.soundEnabled {
            NSSound(named: NSSound.Name(settings.soundName))?.play()
        }
        guard settings.notificationsEnabled, let center else { return }
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // Show banners even though the app counts as "active".
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
