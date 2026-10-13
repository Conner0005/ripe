import AppKit
import PomodoroCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Timer") {
                Stepper("Work: \(model.settings.workMinutes) min",
                        value: $model.settings.workMinutes, in: PomodoroSettings.workRange)
                Stepper("Break: \(model.settings.breakMinutes) min",
                        value: $model.settings.breakMinutes, in: PomodoroSettings.breakRange)
                Stepper("Repeats: \(model.settings.repeats)",
                        value: $model.settings.repeats, in: PomodoroSettings.repeatsRange)
                if model.status != .idle {
                    Text("Changes apply the next time you start.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Long break") {
                Toggle("Take a long break", isOn: $model.settings.longBreakEnabled)
                Stepper("Long break: \(model.settings.longBreakMinutes) min",
                        value: $model.settings.longBreakMinutes, in: PomodoroSettings.longBreakRange)
                    .disabled(!model.settings.longBreakEnabled)
                Stepper("After every \(model.settings.longBreakEvery) sessions",
                        value: $model.settings.longBreakEvery, in: PomodoroSettings.longBreakEveryRange)
                    .disabled(!model.settings.longBreakEnabled)
                if model.settings.longBreakEnabled && model.settings.repeats <= model.settings.longBreakEvery {
                    Text("No long break will happen: Repeats must be more than \(model.settings.longBreakEvery).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Alerts") {
                Toggle("Play sound", isOn: $model.settings.soundEnabled)
                Picker("Sound", selection: $model.settings.soundName) {
                    ForEach(PomodoroSettings.soundNames, id: \.self) { Text($0).tag($0) }
                }
                .disabled(!model.settings.soundEnabled)
                .onChange(of: model.settings.soundName) { _, name in
                    NSSound(named: NSSound.Name(name))?.play()
                }
                Toggle("Show notifications", isOn: $model.settings.notificationsEnabled)
            }
            Section("Auto-pause") {
                Toggle("Pause work when I'm idle", isOn: $model.settings.autoPauseEnabled)
                Stepper("Idle after \(model.settings.idleThresholdSeconds) s",
                        value: $model.settings.idleThresholdSeconds,
                        in: PomodoroSettings.idleThresholdRange, step: 15)
                    .disabled(!model.settings.autoPauseEnabled)
                Text("Pauses when there's no mouse or keyboard activity and resumes when you're back. Idle time isn't counted as work.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Insights") {
                Toggle("Track which app I'm focusing in", isOn: $model.settings.appTrackingEnabled)
                Text("Only app names and seconds, stored on this Mac. Shown in Statistics, never on the share card.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LoginItem.setEnabled(enabled)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Start/pause with ⌥⌘P from any app", isOn: $model.settings.hotkeyEnabled)
            }
        }
        .formStyle(.grouped)
        // A grouped Form scrolls, so it has no natural height; without one the window opens as a bare title bar.
        .frame(width: 400, height: 680)
    }
}
