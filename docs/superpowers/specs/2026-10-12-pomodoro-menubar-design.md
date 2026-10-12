# Pomodoro Menu Bar App — Design

**Date:** 2026-10-12
**Status:** Draft for review

## Goal

A native macOS menu bar Pomodoro timer: configurable work/break/repeat cycle, live countdown in the menu bar, sound + notification alerts, work statistics, and an optional auto-pause when the user is idle.

## Requirements (from the user)

1. Set durations for **work**, **break**, and number of **repeats**.
2. Settings for **sound** and **notifications**.
3. Remaining time is shown **in the macOS menu bar**.
4. **Statistics** on work done.
5. A **toggle for mouse control**: auto-pause the timer when there's no activity.

## Decisions (assumptions — override any of these at review)

| Topic | Decision | Why |
|---|---|---|
| Stack | Swift 5 language mode, SwiftUI `MenuBarExtra`, Swift Charts, SwiftPM package (no Xcode project) | Xcode 16.1 / macOS 14.5 installed; SwiftPM keeps the repo plain-text and testable with `swift test` |
| Min OS | macOS 14.0 | Matches the installed OS; gives `MenuBarExtra`, Charts, `MainActor.assumeIsolated` |
| App packaging | `scripts/bundle.sh` wraps the release binary into `build/Pomodoro.app` (`LSUIElement`, ad-hoc signed) | Notifications require a bundle identifier; `LSUIElement` hides the Dock icon |
| Cycle shape | `work, break, work, break, …, work` — `repeats` work sessions, no trailing break | Classic Pomodoro; a long break is listed as a future idea |
| Idle detection | Any input (mouse **or keyboard**) counts as activity, via `CGEventSource.secondsSinceLastEventType` — no Accessibility permission needed | Mouse-only would pause you while you type without touching the mouse. One-line change to mouse-only if preferred |
| Auto-pause scope | Only during **work** phases; resumes automatically on activity; idle time is subtracted from logged work | Breaks are meant to be away-from-keyboard; stats should reflect real focus time |
| Manual pause | Never auto-resumed | User intent wins |
| Mac sleep | Timer pauses on system sleep; user resumes manually | Lid-closed time is not work |
| Settings mid-run | Saved immediately, applied at next Start | Avoids mutating a running sequence |
| Stats storage | JSON array of `WorkRecord` in `~/Library/Application Support/Pomodoro/stats.json`; corrupt file is moved aside, never overwritten silently | Tiny data, human-readable, testable |
| Partial work | Stop/Skip during work logs the partial seconds as `completed: false` (if ≥ 1 s) | Statistics count all focus time; session counts only completed ones |
| Day bucketing | A record belongs to the day its work phase started | Simple; sessions spanning midnight are rare |

## Components

- **PomodoroCore** (library, no UI, fully unit-tested): `PomodoroSettings`, `SettingsStore`, `PhasePlan`, `TimerEngine`, `AutoPausePolicy`, `TimeFormat`, `PhaseMessages`, `WorkRecord`, `StatsStore`, `StatsSummary`.
- **Pomodoro** (executable app): `AppModel` (glue: 1 s ticker, idle polling, sleep observer, stats, alerts), `Notifier`, `IdleDetector`, `MenuBarLabel`, `MenuContent`, `SettingsView`, `StatsView`, `WindowPresenter`.

## Statistics shown

Today (time + completed sessions), last 7 days total, all-time (time + sessions), and a bar chart of minutes per day for the last 7 days.

## Future ideas (out of scope for v1)

- Long break every N sessions
- Global keyboard shortcut to start/pause
- Launch at login (`SMAppService`)
- "+5 min" extend button and auto-start-next-phase toggle
- Task label / intention per session, with stats per label
- Daily goal + streaks
- Turn on a Focus / Do Not Disturb mode during work (via Shortcuts)
- Full-screen break overlay that gently enforces breaks
- CSV export of history
- Progress ring icon in the menu bar instead of digits
