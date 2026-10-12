import AppKit
import PomodoroCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

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
        }
        .formStyle(.grouped)
        .frame(width: 380)
    }
}
