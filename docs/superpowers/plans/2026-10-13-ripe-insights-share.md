# Ripe — Rename, Ripening Icon, Focus Insights, Share Card — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the menu bar Pomodoro app to "Ripe", draw a tomato that ripens in the menu bar, record per-app focus time and best hours, and export a 1080×1920 Story card.

**Architecture:** All logic that can be pure (ripeness colour, app tally scaling, insights, card numbers, hour labels) goes into the `PomodoroCore` library with XCTest coverage. The `Pomodoro` executable only samples the front app, draws images and lays out views. Stored data stays backward compatible: `WorkRecord` gains an optional `apps` field.

**Tech Stack:** Swift 6.0.2 compiler in Swift 5 mode (`swift-tools-version:5.10`), SwiftPM, macOS 14, SwiftUI `MenuBarExtra`, `ImageRenderer`, `ShareLink`, AppKit `NSImage`/`NSSavePanel`, XCTest.

**Spec:** `docs/superpowers/specs/2026-10-13-ripe-insights-share-design.md`

## Global Constraints

- Platform floor: macOS 14.0; `swift-tools-version:5.10`; no new package dependencies.
- Tests run with `swift test --disable-swift-testing` (XCTest only).
- Rename is user-visible only: `CFBundleName`/`CFBundleDisplayName` = "Ripe", bundle `build/Ripe.app`. Bundle id `com.conner.pomodoro`, SwiftPM target/module names, executable `Pomodoro`, and `~/Library/Application Support/Pomodoro` do not change.
- Ripeness: 24 steps; green (0.30, 0.72, 0.40) → orange (0.98, 0.60, 0.20) → red (0.90, 0.25, 0.22).
- Tomato states: work = colour by elapsed fraction; rest = fully red; paused = grey; idle = red, no clock.
- App tracking: `appTrackingEnabled`, default `true`; only app names and seconds, stored locally.
- `WorkRecord.apps: [String: Int]?` — `nil` when tracking is off, the tally is empty, or seconds is 0; never an empty dictionary.
- Best hours: 2-hour window, ties → earliest, `nil` under 5 completed sessions; label like "9–11am", "11am–1pm", "11pm–1am" (en dash).
- Top apps: last 7 days (same window as `last7Days`), top 5, seconds desc then name asc.
- Share card: 1080×1920 PNG; tomato + "Ripe", week total in a ring, 7-day bars with weekday initials, "N sessions this week", "Best: …" (omitted when `nil`); **no app names**. Default file name `Ripe-week-YYYY-MM-DD.png`.

## Review Focus

1. **Idle trimming drops or mismatches the app breakdown.** When `PendingWork` trims an idle tail, the saved record's `apps` must still sum to its (smaller) `seconds`. Pinned in Task 2 (`testResolveRescalesAppsToTrimmedSeconds`).
2. **Old stats files.** A `stats.json` written before this change (no `apps` key) must load unchanged, and a record saved with `apps = nil` must not write an `apps` key. Pinned in Task 2.
3. **Best hours across midnight.** Sessions at 23:xx and 00:xx form the window "11pm–1am", not two separate windows. Pinned in Task 3 (`testBestHoursWrapsPastMidnight`).
4. **Ripe's own windows counted as focus.** While Statistics or Settings is open, Ripe is the front app; it must not appear in Top apps. Handled in Task 4 by skipping `NSRunningApplication.current`; checked by reading the code in review (AppModel has no unit tests).
5. **The coloured tomato rendering as a monochrome template.** `MenuBarExtra` labels can template images. The tomato must show colour. Checked in Task 5 by a screenshot of the real menu bar.

---

## File Structure

| File | Responsibility |
|---|---|
| `Sources/PomodoroCore/Ripeness.swift` (new) | Progress → step → RGB colour |
| `Sources/PomodoroCore/AppTally.swift` (new) | Counting seconds per app; scaling a breakdown to a target total |
| `Sources/PomodoroCore/WorkRecord.swift` (modify) | Optional `apps` |
| `Sources/PomodoroCore/PendingWork.swift` (modify) | Rescale `apps` when trimming |
| `Sources/PomodoroCore/PomodoroSettings.swift` (modify) | `appTrackingEnabled` |
| `Sources/PomodoroCore/FocusInsights.swift` (new) | Best hours, top apps |
| `Sources/PomodoroCore/TimeFormat.swift` (modify) | `hourRange(start:)` |
| `Sources/PomodoroCore/ShareCardData.swift` (new) | Numbers shown on the card |
| `Sources/Pomodoro/TomatoImage.swift` (new) | Draws and caches the menu bar tomato |
| `Sources/Pomodoro/MenuBarLabel.swift` (modify) | Tomato + clock |
| `Sources/Pomodoro/AppModel.swift` (modify) | Samples front app, attaches `apps`, exposes `records` |
| `Sources/Pomodoro/SettingsView.swift` (modify) | Tracking toggle |
| `Sources/Pomodoro/StatsView.swift` (modify) | Top apps, best hours, Share…/Save Image… |
| `Sources/Pomodoro/ShareCardView.swift` (new) | Card layout + PNG rendering |
| `Resources/Info.plist`, `scripts/bundle.sh` (modify) | Rename |
| `Tests/PomodoroCoreTests/RipenessTests.swift`, `AppTallyTests.swift`, `FocusInsightsTests.swift`, `ShareCardDataTests.swift` (new); `PendingWorkTests.swift`, `SettingsStoreTests.swift`, `StatsTests.swift`, `FormattingTests.swift` (modify) | Tests |

---

### Task 1: Ripeness colour

**Files:**
- Create: `Sources/PomodoroCore/Ripeness.swift`
- Test: `Tests/PomodoroCoreTests/RipenessTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public struct RGB: Equatable { public let red, green, blue: Double }`; `public enum Ripeness { static let steps = 24; static func step(progress: Double) -> Int; static func color(fraction: Double) -> RGB; static func color(step: Int) -> RGB; static let green, orange, red: RGB }`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import PomodoroCore

final class RipenessTests: XCTestCase {
    func testStepBoundaries() {
        XCTAssertEqual(Ripeness.step(progress: 0), 0)
        XCTAssertEqual(Ripeness.step(progress: 0.5), 12)
        XCTAssertEqual(Ripeness.step(progress: 0.999), 23)
        XCTAssertEqual(Ripeness.step(progress: 1), 23)
    }

    func testStepClampsOutOfRange() {
        XCTAssertEqual(Ripeness.step(progress: -0.5), 0)
        XCTAssertEqual(Ripeness.step(progress: 3), 23)
        XCTAssertEqual(Ripeness.step(progress: .nan), 0)
    }

    func testColourEndpointsAndMidpoint() {
        XCTAssertEqual(Ripeness.color(step: 0), Ripeness.green)
        XCTAssertEqual(Ripeness.color(step: 23), Ripeness.red)
        XCTAssertEqual(Ripeness.color(fraction: 0.5), Ripeness.orange)
        XCTAssertEqual(Ripeness.green, RGB(red: 0.30, green: 0.72, blue: 0.40))
        XCTAssertEqual(Ripeness.orange, RGB(red: 0.98, green: 0.60, blue: 0.20))
        XCTAssertEqual(Ripeness.red, RGB(red: 0.90, green: 0.25, blue: 0.22))
    }

    func testColourBetweenGreenAndOrange() {
        let quarter = Ripeness.color(fraction: 0.25)
        XCTAssertEqual(quarter.red, 0.64, accuracy: 0.0001)
        XCTAssertEqual(quarter.green, 0.66, accuracy: 0.0001)
        XCTAssertEqual(quarter.blue, 0.30, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --disable-swift-testing --filter RipenessTests`
Expected: build error "cannot find 'Ripeness' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --disable-swift-testing --filter RipenessTests`
Expected: 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/PomodoroCore/Ripeness.swift Tests/PomodoroCoreTests/RipenessTests.swift
git commit -m "feat(core): ripeness colour for the menu bar tomato"
```

---

### Task 2: App tally, `WorkRecord.apps`, tracking setting

**Files:**
- Create: `Sources/PomodoroCore/AppTally.swift`
- Modify: `Sources/PomodoroCore/WorkRecord.swift`, `Sources/PomodoroCore/PendingWork.swift`, `Sources/PomodoroCore/PomodoroSettings.swift`
- Test: `Tests/PomodoroCoreTests/AppTallyTests.swift` (new); `Tests/PomodoroCoreTests/PendingWorkTests.swift`, `Tests/PomodoroCoreTests/SettingsStoreTests.swift`, `Tests/PomodoroCoreTests/StatsTests.swift` (add tests)

**Interfaces:**
- Consumes: existing `WorkRecord(start:seconds:completed:)`, `PendingWork.resolve(now:idleSeconds:threshold:)`.
- Produces:
  - `public struct AppTally: Equatable { public private(set) var seconds: [String: Int]; public init(); public mutating func add(_ app: String?, seconds: Int = 1); public func scaled(to total: Int) -> [String: Int]?; public static func scale(_ apps: [String: Int], to total: Int) -> [String: Int]?; public static let otherName = "Other" }`
  - `WorkRecord.apps: [String: Int]?` and `WorkRecord(start:seconds:completed:apps: [String: Int]? = nil)`
  - `PomodoroSettings.appTrackingEnabled: Bool` (default `true`)

- [ ] **Step 1: Write the failing tests**

`Tests/PomodoroCoreTests/AppTallyTests.swift`:

```swift
import XCTest
@testable import PomodoroCore

final class AppTallyTests: XCTestCase {
    func testAddCountsSecondsPerApp() {
        var tally = AppTally()
        tally.add("Xcode")
        tally.add("Xcode")
        tally.add("Safari")
        tally.add(nil)
        XCTAssertEqual(tally.seconds, ["Xcode": 2, "Safari": 1, "Other": 1])
    }

    func testScaledSumsExactlyToTarget() {
        var tally = AppTally()
        tally.add("Xcode", seconds: 2)
        tally.add("Safari", seconds: 1)
        let scaled = tally.scaled(to: 100)
        XCTAssertEqual(scaled?.values.reduce(0, +), 100)
        XCTAssertEqual(scaled, ["Xcode": 67, "Safari": 33])
    }

    func testScaleTieBreaksByName() {
        // 1 s split between two equal apps: the remainder goes to the alphabetically first.
        XCTAssertEqual(AppTally.scale(["Zed": 5, "Arc": 5], to: 1), ["Arc": 1])
    }

    func testScaleToZeroOrEmptyIsNil() {
        XCTAssertNil(AppTally.scale(["Xcode": 10], to: 0))
        XCTAssertNil(AppTally.scale([:], to: 100))
        XCTAssertNil(AppTally().scaled(to: 100))
    }
}
```

Append to `PendingWorkTests` (inside the class):

```swift
    func testResolveRescalesAppsToTrimmedSeconds() {
        let record = WorkRecord(start: t0, seconds: 1500, completed: true, apps: ["Xcode": 1200, "Safari": 300])
        let resolved = PendingWork(record: record, phaseEnd: t0 + 1500)
            .resolve(now: t0 + 1520, idleSeconds: 60, threshold: 60)
        XCTAssertEqual(resolved?.seconds, 1460)
        XCTAssertEqual(resolved?.apps, ["Xcode": 1168, "Safari": 292])
    }
```

Append to `SettingsStoreTests` (inside the class):

```swift
    func testAppTrackingDefaultsOnWhenMissing() {
        defaults.set(Data(#"{"workMinutes":40}"#.utf8), forKey: SettingsStore.key)
        XCTAssertTrue(SettingsStore(defaults: defaults).load().appTrackingEnabled)
    }
```

Append to `StatsStoreTests` in `StatsTests.swift` (inside the class):

```swift
    func testOldRecordsWithoutAppsStillLoad() throws {
        try Data(#"[{"start":0,"seconds":1500,"completed":true}]"#.utf8).write(to: fileURL)
        XCTAssertEqual(StatsStore(fileURL: fileURL).records,
                       [WorkRecord(start: Date(timeIntervalSinceReferenceDate: 0), seconds: 1500, completed: true)])
    }

    func testAppsRoundTripAndNilIsNotWritten() throws {
        let withApps = WorkRecord(start: Date(timeIntervalSince1970: 1_000_000), seconds: 60, completed: true, apps: ["Xcode": 60])
        let without = WorkRecord(start: Date(timeIntervalSince1970: 1_000_100), seconds: 30, completed: false)
        let store = StatsStore(fileURL: fileURL)
        try store.append(withApps)
        try store.append(without)
        XCTAssertEqual(StatsStore(fileURL: fileURL).records, [withApps, without])
        let json = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(json.components(separatedBy: "\"apps\"").count - 1, 1, json)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --disable-swift-testing --filter "AppTallyTests|PendingWorkTests|SettingsStoreTests|StatsStoreTests"`
Expected: build errors — "cannot find 'AppTally' in scope", "extra argument 'apps' in call", "value of type 'PomodoroSettings' has no member 'appTrackingEnabled'".

- [ ] **Step 3: Write minimal implementation**

`Sources/PomodoroCore/AppTally.swift`:

```swift
import Foundation

/// Seconds of focus per front app during one work phase.
public struct AppTally: Equatable {
    public static let otherName = "Other"
    public private(set) var seconds: [String: Int] = [:]

    public init() {}

    public mutating func add(_ app: String?, seconds: Int = 1) {
        self.seconds[app ?? Self.otherName, default: 0] += seconds
    }

    public func scaled(to total: Int) -> [String: Int]? {
        Self.scale(seconds, to: total)
    }

    /// Proportionally rescales so the values sum exactly to `total` (largest-remainder rounding, ties by name).
    /// Logged work is trimmed by auto-pause and idle handling, so the breakdown must follow it. Nil when nothing to store.
    public static func scale(_ apps: [String: Int], to total: Int) -> [String: Int]? {
        let sum = apps.values.reduce(0, +)
        guard total > 0, sum > 0 else { return nil }
        var result: [String: Int] = [:]
        var remainders: [(name: String, remainder: Int)] = []
        for (name, value) in apps {
            let exact = value * total
            result[name] = exact / sum
            remainders.append((name, exact % sum))
        }
        let leftover = total - result.values.reduce(0, +)
        let order = remainders.sorted { $0.remainder != $1.remainder ? $0.remainder > $1.remainder : $0.name < $1.name }
        for entry in order.prefix(leftover) { result[entry.name, default: 0] += 1 }
        let nonZero = result.filter { $0.value > 0 }
        return nonZero.isEmpty ? nil : nonZero
    }
}
```

`Sources/PomodoroCore/WorkRecord.swift` (whole file):

```swift
import Foundation

public struct WorkRecord: Codable, Equatable {
    public let start: Date
    public let seconds: Int
    public let completed: Bool
    /// Seconds per front app, summing to `seconds`. Nil for older records or when tracking is off.
    public let apps: [String: Int]?

    public init(start: Date, seconds: Int, completed: Bool, apps: [String: Int]? = nil) {
        self.start = start
        self.seconds = seconds
        self.completed = completed
        self.apps = apps
    }
}
```

(Synthesized `Codable` uses `decodeIfPresent`/`encodeIfPresent` for optionals, so old files load and `nil` writes no key.)

`Sources/PomodoroCore/PendingWork.swift` — replace the last line of `resolve`:

```swift
        return WorkRecord(start: record.start, seconds: seconds, completed: record.completed,
                          apps: record.apps.flatMap { AppTally.scale($0, to: seconds) })
```

`Sources/PomodoroCore/PomodoroSettings.swift` — add after `public var hotkeyEnabled = true`:

```swift
    public var appTrackingEnabled = true
```

and after the `hotkeyEnabled = try …` line in `init(from:)`:

```swift
        appTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .appTrackingEnabled) ?? fallback.appTrackingEnabled
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --disable-swift-testing`
Expected: all tests pass (59 after Task 1, + 4 + 1 + 1 + 2 = 67, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add Sources/PomodoroCore Tests/PomodoroCoreTests
git commit -m "feat(core): per-app focus tally stored on work records"
```

---

### Task 3: Hour labels and focus insights

**Files:**
- Create: `Sources/PomodoroCore/FocusInsights.swift`
- Modify: `Sources/PomodoroCore/TimeFormat.swift`
- Test: `Tests/PomodoroCoreTests/FocusInsightsTests.swift` (new); `Tests/PomodoroCoreTests/FormattingTests.swift` (add)

**Interfaces:**
- Consumes: `WorkRecord.apps` (Task 2).
- Produces:
  - `TimeFormat.hourRange(start: Int) -> String`
  - `public struct AppTime: Equatable, Identifiable { public let name: String; public let seconds: Int; public var id: String }`
  - `public enum FocusInsights { static let minimumSessions = 5; static func bestHours(records: [WorkRecord], calendar: Calendar = .current) -> Int?; static func topApps(records: [WorkRecord], now: Date, limit: Int = 5, calendar: Calendar = .current) -> [AppTime] }` — `bestHours` returns the window's start hour (0–23).

- [ ] **Step 1: Write the failing tests**

Append to the class in `FormattingTests.swift`:

```swift
    func testHourRange() {
        XCTAssertEqual(TimeFormat.hourRange(start: 9), "9–11am")
        XCTAssertEqual(TimeFormat.hourRange(start: 11), "11am–1pm")
        XCTAssertEqual(TimeFormat.hourRange(start: 10), "10am–12pm")
        XCTAssertEqual(TimeFormat.hourRange(start: 12), "12–2pm")
        XCTAssertEqual(TimeFormat.hourRange(start: 22), "10pm–12am")
        XCTAssertEqual(TimeFormat.hourRange(start: 23), "11pm–1am")
        XCTAssertEqual(TimeFormat.hourRange(start: 0), "12–2am")
    }
```

`Tests/PomodoroCoreTests/FocusInsightsTests.swift`:

```swift
import XCTest
@testable import PomodoroCore

final class FocusInsightsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: 10))!
    }

    private func session(day: Int = 5, hour: Int, completed: Bool = true, apps: [String: Int]? = nil) -> WorkRecord {
        WorkRecord(start: date(day: day, hour: hour), seconds: 1500, completed: completed, apps: apps)
    }

    func testBestHoursNilUnderFiveCompletedSessions() {
        let records = [9, 9, 10, 10].map { session(hour: $0) } + [session(hour: 9, completed: false)]
        XCTAssertNil(FocusInsights.bestHours(records: records, calendar: calendar))
    }

    func testBestHoursPicksBusiestTwoHourWindow() {
        let records = [9, 9, 10, 15, 15].map { session(hour: $0) }
        XCTAssertEqual(FocusInsights.bestHours(records: records, calendar: calendar), 9)
    }

    func testBestHoursTieGoesToEarliest() {
        // Windows 8–10 (8:1, 9:1) and 14–16 (14:1, 15:1) and 9–11 (9:1, 10:1) all score 2 → earliest is 8.
        let records = [8, 9, 10, 14, 15].map { session(hour: $0) }
        XCTAssertEqual(FocusInsights.bestHours(records: records, calendar: calendar), 8)
    }

    func testBestHoursWrapsPastMidnight() {
        let records = [23, 23, 0, 0, 12].map { session(hour: $0) }
        XCTAssertEqual(FocusInsights.bestHours(records: records, calendar: calendar), 23)
    }

    func testTopAppsSumsLastSevenDaysSortedAndLimited() {
        let now = date(day: 10, hour: 18)
        let records = [
            session(day: 10, hour: 9, apps: ["Xcode": 1000, "Safari": 500]),
            session(day: 4, hour: 9, apps: ["Xcode": 300, "Arc": 500, "Notes": 500]),
            session(day: 3, hour: 9, apps: ["Old": 9999]),           // outside the 7-day window
            session(day: 9, hour: 9),                                  // no app data
            session(day: 8, hour: 9, apps: ["Mail": 10, "Figma": 20, "Zed": 5]),
        ]
        let top = FocusInsights.topApps(records: records, now: now, limit: 5, calendar: calendar)
        XCTAssertEqual(top, [
            AppTime(name: "Xcode", seconds: 1300),
            AppTime(name: "Arc", seconds: 500),
            AppTime(name: "Notes", seconds: 500),
            AppTime(name: "Safari", seconds: 500),
            AppTime(name: "Figma", seconds: 20),
        ])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --disable-swift-testing --filter "FocusInsightsTests|FormattingTests"`
Expected: build errors — "type 'TimeFormat' has no member 'hourRange'", "cannot find 'FocusInsights' in scope".

- [ ] **Step 3: Write minimal implementation**

Add inside `enum TimeFormat` in `TimeFormat.swift`:

```swift
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
```

`Sources/PomodoroCore/FocusInsights.swift`:

```swift
import Foundation

public struct AppTime: Equatable, Identifiable {
    public let name: String
    public let seconds: Int
    public var id: String { name }

    public init(name: String, seconds: Int) {
        self.name = name
        self.seconds = seconds
    }
}

public enum FocusInsights {
    public static let minimumSessions = 5

    /// Start hour of the two-hour window in which the most completed sessions started; nil until there are enough.
    public static func bestHours(records: [WorkRecord], calendar: Calendar = .current) -> Int? {
        let completed = records.filter(\.completed)
        guard completed.count >= minimumSessions else { return nil }
        var counts = [Int](repeating: 0, count: 24)
        for record in completed { counts[calendar.component(.hour, from: record.start)] += 1 }
        var best = 0
        var bestScore = -1
        for hour in 0..<24 {
            let score = counts[hour] + counts[(hour + 1) % 24]
            if score > bestScore {
                best = hour
                bestScore = score
            }
        }
        return best
    }

    /// Apps with the most focus time over the last 7 days (today and the 6 days before).
    public static func topApps(records: [WorkRecord], now: Date, limit: Int = 5, calendar: Calendar = .current) -> [AppTime] {
        let firstDay = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        var totals: [String: Int] = [:]
        for record in records where calendar.startOfDay(for: record.start) >= firstDay {
            for (name, seconds) in record.apps ?? [:] { totals[name, default: 0] += seconds }
        }
        return totals
            .map { AppTime(name: $0.key, seconds: $0.value) }
            .sorted { $0.seconds != $1.seconds ? $0.seconds > $1.seconds : $0.name < $1.name }
            .prefix(limit)
            .map { $0 }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --disable-swift-testing`
Expected: all tests pass (67 + 1 + 5 = 73, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add Sources/PomodoroCore Tests/PomodoroCoreTests
git commit -m "feat(core): best focus hours and top apps"
```

---

### Task 4: Sample the front app while focusing

**Files:**
- Modify: `Sources/Pomodoro/AppModel.swift`, `Sources/Pomodoro/SettingsView.swift`

**Interfaces:**
- Consumes: `AppTally` (Task 2), `WorkRecord(start:seconds:completed:apps:)`, `PomodoroSettings.appTrackingEnabled`.
- Produces: `AppModel.records: [WorkRecord]` (read-only, used by Tasks 6–7).

No unit tests: `AppModel` is untested glue (as in the previous plan); the tally maths is covered by Task 2. Verification is a clean build plus the full suite.

- [ ] **Step 1: Add the tally to `AppModel`**

Add next to `private var pendingWork: PendingWork?`:

```swift
    private var appTally = AppTally()
```

Add after `refreshSummary()`:

```swift
    var records: [WorkRecord] { statsStore.records }
```

In `start()`, after `sequenceWorkedSeconds = 0`:

```swift
        appTally = AppTally()
```

At the top of `tick()`, right after `let now = Date()`:

```swift
        sampleFrontApp()
```

Add a method after `tick()`:

```swift
    /// One second of focus for whichever app is in front. Ripe's own windows (Statistics, Settings) don't count.
    private func sampleFrontApp() {
        guard settings.appTrackingEnabled, engine.status == .running, engine.currentPhase?.kind == .work else { return }
        let front = NSWorkspace.shared.frontmostApplication
        if front == NSRunningApplication.current { return }
        appTally.add(front?.localizedName)
    }
```

In `handle(_:)`, change the `.workLogged` case's first lines from

```swift
            case .workLogged(let record):
                sequenceWorkedSeconds += record.seconds
```

to

```swift
            case .workLogged(let logged):
                let apps = settings.appTrackingEnabled ? appTally.scaled(to: logged.seconds) : nil
                let record = WorkRecord(start: logged.start, seconds: logged.seconds, completed: logged.completed, apps: apps)
                appTally = AppTally()
                sequenceWorkedSeconds += record.seconds
```

(The rest of the case already uses `record`, so the pending/save paths now carry `apps`.)

- [ ] **Step 2: Add the Settings toggle**

In `SettingsView.swift`, insert a section between `Section("Auto-pause") { … }` and `Section("General") {`:

```swift
            Section("Insights") {
                Toggle("Track which app I'm focusing in", isOn: $model.settings.appTrackingEnabled)
                Text("Only app names and seconds, stored on this Mac. Shown in Statistics, never on the share card.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
```

Change `.frame(width: 400, height: 600)` to `.frame(width: 400, height: 680)` so the new section fits without scrolling past the end of General.

- [ ] **Step 3: Build and run the suite**

Run: `swift build 2>&1 | tail -3 && swift test --disable-swift-testing 2>&1 | tail -3`
Expected: "Build complete!" and 73 tests, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Sources/Pomodoro/AppModel.swift Sources/Pomodoro/SettingsView.swift
git commit -m "feat: record which app is in front during focus"
```

---

### Task 5: Ripening tomato in the menu bar

**Files:**
- Create: `Sources/Pomodoro/TomatoImage.swift`
- Modify: `Sources/Pomodoro/MenuBarLabel.swift`

**Interfaces:**
- Consumes: `Ripeness.step(progress:)`, `Ripeness.color(step:)`, `Ripeness.steps`, `RGB` (Task 1); `AppModel.status`, `.phase`, `.remaining`.
- Produces: `enum TomatoState: Hashable { case ripening(Int), rest, paused, idle }`; `TomatoImage.image(for: TomatoState) -> NSImage`.

- [ ] **Step 1: Write `TomatoImage.swift`**

```swift
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
        let leaf = state == .paused ? NSColor.secondaryLabelColor : NSColor(red: 0.30, green: 0.72, blue: 0.40, alpha: 1)
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
```

- [ ] **Step 2: Replace `MenuBarLabel.swift`**

```swift
import PomodoroCore
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let tomato = Image(nsImage: TomatoImage.image(for: state)).renderingMode(.original)
        if model.status == .idle {
            tomato
        } else {
            Text("\(tomato) \(TimeFormat.clock(model.remaining))")
                .monospacedDigit()
        }
    }

    private var state: TomatoState {
        switch model.status {
        case .idle: return .idle
        case .paused: return .paused
        case .running:
            guard let phase = model.phase, phase.kind == .work, phase.duration > 0 else { return .rest }
            return .ripening(Ripeness.step(progress: 1 - model.remaining / phase.duration))
        }
    }
}
```

- [ ] **Step 3: Build, run, and look at the real menu bar**

Run:

```bash
scripts/bundle.sh 2>&1 | tail -1
pkill -x Pomodoro; open build/Pomodoro.app
sleep 2; screencapture -x "$SCRATCH/menubar-idle.png"
```

Open the screenshot with Read and look at the right-hand end of the menu bar.

(`$SCRATCH` is the session scratchpad. The bundle is still named `Pomodoro.app` until Task 8.)

Expected: the captured right-hand menu bar strip shows a **red** tomato with a green leaf (not a monochrome silhouette). Start a session with the hotkey ⌥⌘P (or ask the user to click Start) and capture again: a **green** tomato followed by the clock. If the tomato is monochrome, the template-rendering risk from Review Focus #5 has hit: replace the `Text` interpolation with `HStack(spacing: 3) { tomato; Text(TimeFormat.clock(model.remaining)).monospacedDigit() }`, rebuild, and re-capture; ledger a ruling.

- [ ] **Step 4: Run the suite and commit**

Run: `swift test --disable-swift-testing 2>&1 | tail -3`
Expected: 73 tests, 0 failures.

```bash
git add Sources/Pomodoro/TomatoImage.swift Sources/Pomodoro/MenuBarLabel.swift
git commit -m "feat: ripening tomato in the menu bar"
```

---

### Task 6: Insights in the Statistics window

**Files:**
- Modify: `Sources/Pomodoro/StatsView.swift`

**Interfaces:**
- Consumes: `AppModel.records` (Task 4), `FocusInsights.topApps(records:now:limit:calendar:)`, `FocusInsights.bestHours(records:calendar:)`, `FocusInsights.minimumSessions`, `TimeFormat.hourRange(start:)`, `AppTime` (Task 3), `TimeFormat.duration(_:)`.
- Produces: `StatsView` sections that Task 7 adds buttons beneath.

- [ ] **Step 1: Add the insights sections**

In `StatsView.body`, after the `Chart(…) { … }.chartYAxisLabel("Minutes").frame(height: 180)` block and still inside the `VStack`, add:

```swift
            Divider()
            insights
```

Add these members to `StatsView`:

```swift
    private var insights: some View {
        let records = model.records
        let top = FocusInsights.topApps(records: records, now: Date())
        let best = FocusInsights.bestHours(records: records)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Best focus hours", systemImage: "sun.max.fill")
                Spacer()
                Text(best.map(TimeFormat.hourRange) ?? "after \(FocusInsights.minimumSessions) sessions")
                    .foregroundStyle(best == nil ? .secondary : .primary)
            }
            Text("Top apps this week").font(.headline)
            if top.isEmpty {
                Text("No app data yet").foregroundStyle(.secondary)
            } else {
                ForEach(top) { app in appRow(app, max: top[0].seconds) }
            }
        }
    }

    private func appRow(_ app: AppTime, max: Int) -> some View {
        HStack(spacing: 8) {
            Text(app.name).frame(width: 120, alignment: .leading).lineLimit(1)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.93, green: 0.33, blue: 0.27))
                    .frame(width: geo.size.width * CGFloat(app.seconds) / CGFloat(Swift.max(max, 1)))
            }
            .frame(height: 8)
            Text(TimeFormat.duration(app.seconds)).monospacedDigit().frame(width: 60, alignment: .trailing)
        }
        .font(.callout)
    }
```

- [ ] **Step 2: Build and render it offscreen**

Run: `swift build 2>&1 | tail -1`
Expected: "Build complete!"

Visual check: in the scratch preview harness (`$SCRATCH/preview`, which symlinks `Sources/PomodoroCore` and `Sources/Pomodoro/*.swift` into a `Preview` executable; add symlinks for any new files from Tasks 1–5), make `main.swift` render `StatsView(model: AppModel())` with `ImageRenderer` to `$SCRATCH/stats.png`, run it, and look at the image. Expected: the tiles and chart as before, then "Best focus hours" and "Top apps this week" (or "No app data yet") with no clipped text.

- [ ] **Step 3: Commit**

```bash
git add Sources/Pomodoro/StatsView.swift
git commit -m "feat: top apps and best focus hours in Statistics"
```

---

### Task 7: Share card

**Files:**
- Create: `Sources/PomodoroCore/ShareCardData.swift`, `Sources/Pomodoro/ShareCardView.swift`
- Modify: `Sources/Pomodoro/StatsView.swift`
- Test: `Tests/PomodoroCoreTests/ShareCardDataTests.swift`

**Interfaces:**
- Consumes: `StatsSummary(records:now:calendar:)`, `DayTotal`, `FocusInsights.bestHours` (Task 3), `TimeFormat.hourRange`, `TimeFormat.duration`, `AppModel.records`, `AppModel.summary`.
- Produces: `public struct ShareCardData: Equatable { weekSeconds: Int; weekSessions: Int; days: [DayTotal]; bestHoursStart: Int?; init(records:now:calendar:) }`; `ShareCard.png(for: ShareCardData, now: Date) -> URL?` (writes `Ripe-week-YYYY-MM-DD.png` to a temp dir).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import PomodoroCore

final class ShareCardDataTests: XCTestCase {
    func testWeekTotalsSessionsAndBestHours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func at(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
        }
        let now = at(10, 18)
        let records = [
            WorkRecord(start: at(10, 9), seconds: 1500, completed: true),
            WorkRecord(start: at(9, 9), seconds: 1500, completed: true),
            WorkRecord(start: at(8, 10), seconds: 1500, completed: true),
            WorkRecord(start: at(4, 9), seconds: 600, completed: false),
            WorkRecord(start: at(1, 9), seconds: 1500, completed: true),  // before the week; counts for best hours only
            WorkRecord(start: at(2, 20), seconds: 1500, completed: true), // before the week
        ]
        let data = ShareCardData(records: records, now: now, calendar: calendar)
        XCTAssertEqual(data.weekSeconds, 1500 * 3 + 600)
        XCTAssertEqual(data.weekSessions, 3)
        XCTAssertEqual(data.days.count, 7)
        XCTAssertEqual(data.days.last?.seconds, 1500)
        XCTAssertEqual(data.bestHoursStart, 9)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --disable-swift-testing --filter ShareCardDataTests`
Expected: build error "cannot find 'ShareCardData' in scope".

- [ ] **Step 3: Implement `ShareCardData`**

```swift
import Foundation

/// The numbers on the Instagram Story card. Deliberately has no app names.
public struct ShareCardData: Equatable {
    public let weekSeconds: Int
    public let weekSessions: Int
    public let days: [DayTotal]
    public let bestHoursStart: Int?

    public init(records: [WorkRecord], now: Date, calendar: Calendar = .current) {
        let summary = StatsSummary(records: records, now: now, calendar: calendar)
        let firstDay = summary.last7Days[0].day
        weekSeconds = summary.weekSeconds
        weekSessions = records.filter { $0.completed && calendar.startOfDay(for: $0.start) >= firstDay }.count
        days = summary.last7Days
        bestHoursStart = FocusInsights.bestHours(records: records, calendar: calendar)
    }
}
```

Run: `swift test --disable-swift-testing`
Expected: 74 tests, 0 failures.

- [ ] **Step 4: Write `ShareCardView.swift`**

```swift
import AppKit
import PomodoroCore
import SwiftUI

/// 1080×1920 Instagram Story card for the past week.
struct ShareCardView: View {
    let data: ShareCardData
    private let cream = Color(red: 1, green: 0.96, blue: 0.92)

    var body: some View {
        VStack(spacing: 70) {
            HStack(spacing: 24) {
                Image(nsImage: TomatoImage.image(for: .idle)).resizable().frame(width: 96, height: 96)
                Text("Ripe").font(.system(size: 88, weight: .bold, design: .rounded))
            }
            ZStack {
                Circle().stroke(cream.opacity(0.25), lineWidth: 36)
                Circle().trim(from: 0, to: 0.75)
                    .stroke(cream, style: StrokeStyle(lineWidth: 36, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 8) {
                    Text(TimeFormat.duration(data.weekSeconds))
                        .font(.system(size: 130, weight: .bold, design: .rounded))
                    Text("focused this week").font(.system(size: 44, weight: .medium, design: .rounded))
                }
            }
            .frame(width: 620, height: 620)
            bars
            VStack(spacing: 18) {
                Text("\(data.weekSessions) \(data.weekSessions == 1 ? "session" : "sessions") this week")
                if let start = data.bestHoursStart {
                    Text("Best: \(TimeFormat.hourRange(start: start))")
                }
            }
            .font(.system(size: 52, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(cream)
        .frame(width: 1080, height: 1920)
        .background(LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.36), Color(red: 0.80, green: 0.20, blue: 0.19)],
                                   startPoint: .top, endPoint: .bottom))
    }

    private var bars: some View {
        let maxSeconds = max(data.days.map(\.seconds).max() ?? 0, 1)
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack(alignment: .bottom, spacing: 36) {
            ForEach(data.days) { day in
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(cream.opacity(day.seconds > 0 ? 1 : 0.3))
                        .frame(width: 80, height: max(16, 300 * CGFloat(day.seconds) / CGFloat(maxSeconds)))
                    Text(symbols[Calendar.current.component(.weekday, from: day.day) - 1])
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                }
            }
        }
        .frame(height: 380, alignment: .bottom)
    }
}

@MainActor
enum ShareCard {
    /// Renders the card to a PNG in a temporary folder; nil if rendering fails.
    static func png(for data: ShareCardData, now: Date) -> URL? {
        let renderer = ImageRenderer(content: ShareCardView(data: data))
        renderer.scale = 1
        guard let cgImage = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Ripe-week-\(formatter.string(from: now)).png")
        do {
            try png.write(to: url)
            return url
        } catch {
            NSLog("Ripe: failed to write share card: \(error)")
            return nil
        }
    }
}
```

- [ ] **Step 5: Add Share… and Save Image… to Statistics**

In `StatsView`, add a state property:

```swift
    @State private var cardURL: URL?
```

After `insights` in the `VStack`, add:

```swift
            HStack {
                Spacer()
                if let cardURL {
                    ShareLink(item: cardURL) { Label("Share…", systemImage: "square.and.arrow.up") }
                    Button("Save Image…") { save(cardURL) }
                } else {
                    Text("Couldn't create the share image").font(.caption).foregroundStyle(.secondary)
                }
            }
```

After `.onAppear { model.refreshSummary() }` add:

```swift
        .task(id: model.summary) { // re-render the card whenever the numbers change
            cardURL = ShareCard.png(for: ShareCardData(records: model.records, now: Date()), now: Date())
        }
```

Add the save method:

```swift
    private func save(_ cardURL: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = cardURL.lastPathComponent
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: cardURL, to: destination)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
```

Add `import AppKit` and `import UniformTypeIdentifiers` at the top of `StatsView.swift` if not present.

- [ ] **Step 6: Build, render the card, and look at it**

Run: `swift build 2>&1 | tail -1 && swift test --disable-swift-testing 2>&1 | tail -3`
Expected: "Build complete!" and 74 tests, 0 failures.

Visual check: in the preview harness, render `ShareCardView(data: ShareCardData(records: <a few sample records over the last week>, now: Date()))` with `ShareCard.png(for:now:)`, then `sips -g pixelWidth -g pixelHeight` the file and open it with Read. Expected: 1080×1920; tomato + "Ripe" at top, the week total inside the ring, seven bars with weekday initials, "N sessions this week" and "Best: …"; no app names.

- [ ] **Step 7: Commit**

```bash
git add Sources/PomodoroCore/ShareCardData.swift Sources/Pomodoro/ShareCardView.swift Sources/Pomodoro/StatsView.swift Tests/PomodoroCoreTests/ShareCardDataTests.swift
git commit -m "feat: Instagram Story share card for the week"
```

---

### Task 8: Rename to Ripe and install

**Files:**
- Modify: `Resources/Info.plist`, `scripts/bundle.sh`, `Sources/Pomodoro/AppModel.swift` (two strings)

**Interfaces:**
- Consumes: everything above.
- Produces: `build/Ripe.app`, installed at `/Applications/Ripe.app`.

- [ ] **Step 1: Rename the visible strings**

`Resources/Info.plist`: change `<string>Pomodoro</string>` under `CFBundleName` to `<string>Ripe</string>`, and add after it:

```xml
    <key>CFBundleDisplayName</key>
    <string>Ripe</string>
```

(Leave `CFBundleExecutable` = `Pomodoro` and `CFBundleIdentifier` = `com.conner.pomodoro`.)

`scripts/bundle.sh`: change `APP=build/Pomodoro.app` to `APP=build/Ripe.app`, and the header comment `build/Pomodoro.app` to `build/Ripe.app`.

`Sources/Pomodoro/AppModel.swift`: `reason: "Pomodoro timer running"` → `reason: "Ripe timer running"`; `NSLog("Pomodoro: failed to save stats: \(error)")` → `NSLog("Ripe: failed to save stats: \(error)")`.

- [ ] **Step 2: Build the bundle and verify it**

Run:

```bash
rm -rf build/Pomodoro.app
scripts/bundle.sh 2>&1 | tail -1
plutil -extract CFBundleDisplayName raw build/Ripe.app/Contents/Info.plist
plutil -extract CFBundleIdentifier raw build/Ripe.app/Contents/Info.plist
codesign --verify build/Ripe.app && echo signed-ok
swift test --disable-swift-testing 2>&1 | tail -3
```

Expected: "Built build/Ripe.app", `Ripe`, `com.conner.pomodoro`, `signed-ok`, 74 tests, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add Resources/Info.plist scripts/bundle.sh Sources/Pomodoro/AppModel.swift
git commit -m "feat: rename the app to Ripe"
```

- [ ] **Step 4: Install (replaces the old Pomodoro.app)**

Run:

```bash
pkill -x Pomodoro; sleep 1
rm -rf /Applications/Pomodoro.app
ditto build/Ripe.app /Applications/Ripe.app
open /Applications/Ripe.app
sleep 2; ps -axo command | grep -c "/Applications/Ripe.app/Contents/MacOS/Pomodoro"
```

Expected: `1` (running from `/Applications/Ripe.app`). Tell the user to re-toggle **Launch at login** once so it points at `Ripe.app`.
