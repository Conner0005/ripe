# Ripe — Rename, Ripening Icon, Focus Insights, Share Card — Design

**Date:** 2026-10-13
**Status:** Approved in conversation; spec under review
**Builds on:** `2026-10-12-pomodoro-menubar-design.md`

## Goal

Rename the app to **Ripe**, make the menu bar tomato ripen as a focus session runs, show where focus time went (per app, best hours), and export an Instagram Story card of the week.

## What the user asked for / chose

| Topic | Choice |
|---|---|
| Name | **Ripe** |
| Menu bar | Tomato + clock; tomato ripens green → red during focus |
| Focus insights | Per-app breakdown and best focus hours |
| App tracking | On by default, with a Settings toggle to turn it off |
| Share | Instagram **Story image**, 1080×1920 PNG, made in-app (no server) |
| Card contents | No app names on the card |

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Rename scope | User-visible only: `CFBundleName`/`CFBundleDisplayName` = "Ripe", bundle `build/Ripe.app`, window titles, card. Bundle id `com.conner.pomodoro`, SwiftPM target/module names, executable name `Pomodoro`, and the `Application Support/Pomodoro` folder stay | Keeps settings (UserDefaults domain), stats and notification permission; avoids a churny module rename |
| Install | `bundle.sh` builds `build/Ripe.app`; installing removes the old `/Applications/Pomodoro.app` | One copy in Applications |
| Tomato drawing | Drawn in code (NSImage, non-template) at menu bar size, 18pt tall | SF Symbols has no tomato; colour must show, so not a template image |
| Ripeness colour | Pure function in PomodoroCore: `Ripeness.step(progress:)` quantises 0…1 into 24 steps; `Ripeness.color(step:)` interpolates green (0.30, 0.72, 0.40) → orange (0.98, 0.60, 0.20) → red (0.90, 0.25, 0.22) | Testable; redraw only on step change (~24 times per session) |
| Tomato states | Work: colour by elapsed fraction (0 at start, 1 at end). Rest: fully red. Paused: grey. Idle: red with no clock | Matches the approved preview |
| App sampling | On each 1 s tick while status is `.running` and phase is work, add 1 s to `NSWorkspace.shared.frontmostApplication?.localizedName` (fallback "Other") | No permission prompt; only app names |
| Matching logged work | `AppTally.scaled(to: seconds)` proportionally scales the tally so per-app seconds sum exactly to the record's `seconds` (largest-remainder rounding) | Auto-pause rewind and PendingWork trimming change logged seconds; the breakdown must agree with them |
| Storage | `WorkRecord` gains `apps: [String: Int]?`, decoded with `decodeIfPresent`; `nil` when tracking is off | Old `stats.json` keeps loading; no second file |
| Tracking toggle | `PomodoroSettings.appTrackingEnabled`, default `true`, tolerant decode like other keys | Same pattern as existing settings |
| Best hours | `FocusInsights.bestHours(records:calendar:)` counts completed sessions by start hour, finds the 2-hour window (h, h+1) with the most sessions (ties → earliest), returns `nil` under 5 completed sessions | Needs no new data; avoids noise from tiny samples |
| Top apps | `FocusInsights.topApps(records:now:limit: 5)` sums `apps` over the last 7 days (same window as `last7Days`), sorted by seconds desc, name asc on ties | One week matches the card and stats tiles |
| Hours label | `TimeFormat.hourRange(start:)` → e.g. "9–11am", "11am–1pm", "11pm–1am" | Shared by Statistics and the card |
| Share card | SwiftUI `ShareCardView` rendered by `ImageRenderer` at 1080×1920 (scale 1). Contents: tomato + "Ripe", week total inside a ring, 7-day bars with weekday initials, "N sessions this week", "Best: 9–11am" (omitted if `nil`) | Approved layout |
| Share flow | Statistics gets **Share…** (NSSharingServicePicker with the PNG: AirDrop, Messages, …) and **Save Image…** (NSSavePanel, default name `Ripe-week-YYYY-MM-DD.png`) | AirDrop to phone, then post as Story |
| Card numbers | `ShareCardData(records:now:calendar:)` in PomodoroCore: week seconds, week completed sessions, 7 day totals, best hours | Card content is testable without rendering |

## Components

- **PomodoroCore (new/changed, unit-tested):** `Ripeness`, `AppTally`, `FocusInsights`, `ShareCardData`, `TimeFormat.hourRange`, `WorkRecord.apps`, `PomodoroSettings.appTrackingEnabled`.
- **Pomodoro app (changed):** `MenuBarLabel` (tomato image + clock), `TomatoImage` (draws/caches NSImage per step/state), `AppModel` (samples front app, attaches scaled tally when saving work, resets tally per work phase), `StatsView` (top apps, best hours, Share…/Save Image…), `ShareCardView`, `SettingsView` (tracking toggle), window titles, `Info.plist`, `scripts/bundle.sh`.

## Data flow

1. Work phase starts → `AppModel` resets the tally.
2. Each tick (running, work) → tally += 1 s for the front app.
3. `workLogged(record)` (directly or via `PendingWork`) → if tracking is on, the saved record gets `apps = tally.scaled(to: record.seconds)`; tally resets.
4. Statistics and the share card read `StatsStore.records` through `FocusInsights` / `ShareCardData`.

## Error handling

- No front app (e.g. screen locked) → counted under "Other".
- `record.seconds == 0` or an empty tally → `apps` is stored as `nil`, never as an empty dictionary.
- Image render or write fails → the Save panel shows an NSAlert with the error; Share… is disabled if rendering returned nil.
- Old records without `apps` simply don't contribute to Top apps; if no records in the week have apps, the section shows "No app data yet".

## Testing

XCTest in PomodoroCoreTests, written first:
- `Ripeness`: step boundaries (0 → 0, 1 → 23, clamps outside 0…1), colour endpoints and midpoint.
- `AppTally`: add/scale; scaled sums equal target; zero target; empty tally.
- `WorkRecord`: decodes old JSON without `apps`; round-trips with `apps`.
- `PomodoroSettings`: `appTrackingEnabled` defaults to true when missing.
- `FocusInsights`: best hours window, tie → earliest, wrap past midnight (23 → "11pm–1am"), `nil` under 5 sessions; top apps window, sorting, limit.
- `TimeFormat.hourRange`: am/pm/noon/midnight cases.
- `ShareCardData`: week totals and sessions.

Visual: offscreen renders of the tomato at each state and of the share card, checked by screenshot.

## Out of scope

Public web page, square post format, app names on the card, calendar/call awareness, distraction parking lot.
