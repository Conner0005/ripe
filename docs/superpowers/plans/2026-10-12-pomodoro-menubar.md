# Pomodoro Menu Bar App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS menu bar Pomodoro timer with configurable work/break/repeats, sound + notification alerts, live countdown in the menu bar, work statistics, and an idle auto-pause toggle.

**Architecture:** A pure, clock-injected `PomodoroCore` library holds all logic (settings, timer state machine, auto-pause policy, stats) and is covered by XCTest. A thin SwiftUI `MenuBarExtra` executable wires it to the system: a 1 s `Timer`, `CGEventSource` idle polling, sleep notifications, `UNUserNotificationCenter`, and `NSSound`. A shell script wraps the binary into an `LSUIElement` `.app` bundle.

**Tech Stack:** Swift 6.0.2 compiler in Swift 5 language mode (`swift-tools-version:5.10`), SwiftUI, Swift Charts, UserNotifications, AppKit, XCTest, SwiftPM.

**Spec:** `docs/superpowers/specs/2026-10-12-pomodoro-menubar-design.md`

## Global Constraints

- Platform floor: `.macOS(.v14)`; `LSMinimumSystemVersion` `14.0`.
- `// swift-tools-version:5.10` (Swift 5 language mode — do not switch to 6).
- No third-party dependencies.
- Bundle identifier: `com.conner.pomodoro`; app/executable name: `Pomodoro`.
- The settings type is `PomodoroSettings` (never `Settings` — collides with SwiftUI's `Settings` scene).
- The break phase kind is `PhaseKind.rest` (`break` is a Swift keyword).
- Settings ranges: work `1...180` min, break `1...60` min, repeats `1...12`, idle threshold `15...600` s. Defaults: 25 / 5 / 4, sound on (`"Glass"`), notifications on, auto-pause off, idle 60 s.
- All logic lives in `PomodoroCore` and takes `now: Date` as a parameter; only the app target calls `Date()`.
- Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Auto-pause must not count idle time as work.** After N seconds idle the timer pauses *and* gives back the idle seconds, so stats show only real focus time → Task 3 `testIdleRewindReducesLoggedWork`.
2. **A manual pause is never auto-resumed by activity, and an idle pause never overwrites a manual one** → Task 2 `testPauseKeepsOriginalReason`, Task 3 `testNeverResumesUserOrSleepPause`.
3. **Large time gaps (sleep without notification, App Nap) advance phases correctly, once, with correct start dates** → Task 2 `testHugeGapRunsThroughWholeSequenceOnce`.
4. **Corrupt or older-version data never crashes or silently wipes history** (settings fall back to defaults per-key; a corrupt stats file is moved aside) → Task 1 `testMissingKeysUseDefaults` / `testCorruptDataFallsBackToDefaults`, Task 5 `testCorruptFileIsMovedAsideAndStartsEmpty`.
5. **Stopping or skipping mid-work still credits the partial minutes, but zero-length work is not logged** → Task 3 `testStopLogsPartialWorkAndGoesIdle`, `testStopImmediatelyLogsNothing`.

---

## File Structure

```
Package.swift
.gitignore
Resources/Info.plist                       # LSUIElement bundle metadata (Task 6)
scripts/bundle.sh                          # build + wrap into build/Pomodoro.app (Task 6)
Sources/PomodoroCore/
  PomodoroSettings.swift                   # settings model, ranges, clamping, tolerant decoding
  SettingsStore.swift                      # UserDefaults persistence
  Phase.swift                              # PhaseKind, Phase, PhasePlan
  WorkRecord.swift                         # one logged chunk of work
  TimerEngine.swift                        # state machine: start/tick/pause/resume/skip/stop/rewind
  AutoPausePolicy.swift                    # pure decision: pause / resume / nothing
  TimeFormat.swift                         # "24:59", "1h 30m"
  PhaseMessages.swift                      # notification copy
  StatsStore.swift                         # JSON file persistence of WorkRecords
  StatsSummary.swift                       # today / 7-day / all-time aggregates
Sources/Pomodoro/
  PomodoroApp.swift                        # @main, MenuBarExtra scene
  AppModel.swift                           # glue between engine and system
  Notifier.swift                           # sound + UNUserNotificationCenter
  IdleDetector.swift                       # CGEventSource idle seconds
  MenuBarLabel.swift                       # icon + countdown in the menu bar
  MenuContent.swift                        # dropdown menu
  WindowPresenter.swift                    # opens Settings/Statistics NSWindows (Task 7)
  SettingsView.swift                       # (Task 7)
  StatsView.swift                          # (Task 7)
Tests/PomodoroCoreTests/
  SettingsStoreTests.swift
  TimerEngineTests.swift
  TimerControlTests.swift
  AutoPausePolicyTests.swift
  FormattingTests.swift
  StatsTests.swift
```

---

### Task 1: Package scaffold + settings model and persistence

**Files:**
- Create: `Package.swift`, `.gitignore`
- Create: `Sources/PomodoroCore/PomodoroSettings.swift`
- Create: `Sources/PomodoroCore/SettingsStore.swift`
- Test: `Tests/PomodoroCoreTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `public struct PomodoroSettings: Codable, Equatable` with `var workMinutes: Int, breakMinutes: Int, repeats: Int, soundEnabled: Bool, soundName: String, notificationsEnabled: Bool, autoPauseEnabled: Bool, idleThresholdSeconds: Int`; `init()`; `func clamped() -> PomodoroSettings`; statics `workRange`, `breakRange`, `repeatsRange`, `idleThresholdRange: ClosedRange<Int>`, `soundNames: [String]`.
  - `public final class SettingsStore` with `static let key: String`, `init(defaults: UserDefaults = .standard)`, `func load() -> PomodoroSettings`, `func save(_ settings: PomodoroSettings)`.

- [ ] **Step 1: Initialise the repo and package**

```bash
cd /Users/conner/Documents/PROJ/pomodoro
git init
mkdir -p Sources/PomodoroCore Tests/PomodoroCoreTests
```

`Package.swift`:

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PomodoroCore"),
        .testTarget(name: "PomodoroCoreTests", dependencies: ["PomodoroCore"]),
    ]
)
```

`.gitignore`:

```
.build/
build/
.swiftpm/
.DS_Store
```

- [ ] **Step 2: Write the failing tests**

`Tests/PomodoroCoreTests/SettingsStoreTests.swift`:

```swift
import XCTest
@testable import PomodoroCore

final class SettingsStoreTests: XCTestCase {
    private let suite = "SettingsStoreTests"
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    func testLoadReturnsDefaultsWhenEmpty() {
        let settings = SettingsStore(defaults: defaults).load()
        XCTAssertEqual(settings, PomodoroSettings())
        XCTAssertEqual(settings.workMinutes, 25)
        XCTAssertEqual(settings.breakMinutes, 5)
        XCTAssertEqual(settings.repeats, 4)
        XCTAssertFalse(settings.autoPauseEnabled)
    }

    func testSaveThenLoadRoundTrips() {
        var settings = PomodoroSettings()
        settings.workMinutes = 50
        settings.autoPauseEnabled = true
        settings.soundName = "Ping"
        SettingsStore(defaults: defaults).save(settings)
        XCTAssertEqual(SettingsStore(defaults: defaults).load(), settings)
    }

    func testCorruptDataFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: SettingsStore.key)
        XCTAssertEqual(SettingsStore(defaults: defaults).load(), PomodoroSettings())
    }

    func testMissingKeysUseDefaults() {
        defaults.set(Data(#"{"workMinutes":40}"#.utf8), forKey: SettingsStore.key)
        let settings = SettingsStore(defaults: defaults).load()
        XCTAssertEqual(settings.workMinutes, 40)
        XCTAssertEqual(settings.breakMinutes, 5)
        XCTAssertTrue(settings.notificationsEnabled)
    }

    func testClampsOutOfRangeValues() {
        var settings = PomodoroSettings()
        settings.workMinutes = 0
        settings.repeats = 99
        settings.idleThresholdSeconds = 1
        settings.soundName = "NoSuchSound"
        let clamped = settings.clamped()
        XCTAssertEqual(clamped.workMinutes, 1)
        XCTAssertEqual(clamped.repeats, 12)
        XCTAssertEqual(clamped.idleThresholdSeconds, 15)
        XCTAssertEqual(clamped.soundName, "Glass")
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter SettingsStoreTests`
Expected: build FAILS with `cannot find 'SettingsStore' in scope` / `cannot find 'PomodoroSettings' in scope`.

- [ ] **Step 4: Implement**

`Sources/PomodoroCore/PomodoroSettings.swift`:

```swift
import Foundation

public struct PomodoroSettings: Codable, Equatable {
    public var workMinutes = 25
    public var breakMinutes = 5
    public var repeats = 4
    public var soundEnabled = true
    public var soundName = "Glass"
    public var notificationsEnabled = true
    public var autoPauseEnabled = false
    public var idleThresholdSeconds = 60

    public static let workRange = 1...180
    public static let breakRange = 1...60
    public static let repeatsRange = 1...12
    public static let idleThresholdRange = 15...600
    public static let soundNames = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    public init() {}

    // Decode key-by-key so data saved by an older version (missing keys) keeps the values it has.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = PomodoroSettings()
        workMinutes = try container.decodeIfPresent(Int.self, forKey: .workMinutes) ?? fallback.workMinutes
        breakMinutes = try container.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? fallback.breakMinutes
        repeats = try container.decodeIfPresent(Int.self, forKey: .repeats) ?? fallback.repeats
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? fallback.soundEnabled
        soundName = try container.decodeIfPresent(String.self, forKey: .soundName) ?? fallback.soundName
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? fallback.notificationsEnabled
        autoPauseEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoPauseEnabled) ?? fallback.autoPauseEnabled
        idleThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .idleThresholdSeconds) ?? fallback.idleThresholdSeconds
    }

    public func clamped() -> PomodoroSettings {
        var settings = self
        settings.workMinutes = Self.clamp(workMinutes, to: Self.workRange)
        settings.breakMinutes = Self.clamp(breakMinutes, to: Self.breakRange)
        settings.repeats = Self.clamp(repeats, to: Self.repeatsRange)
        settings.idleThresholdSeconds = Self.clamp(idleThresholdSeconds, to: Self.idleThresholdRange)
        if !Self.soundNames.contains(soundName) {
            settings.soundName = PomodoroSettings().soundName
        }
        return settings
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
```

`Sources/PomodoroCore/SettingsStore.swift`:

```swift
import Foundation

public final class SettingsStore {
    public static let key = "settings.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> PomodoroSettings {
        guard let data = defaults.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(PomodoroSettings.self, from: data)
        else { return PomodoroSettings() }
        return settings.clamped()
    }

    public func save(_ settings: PomodoroSettings) {
        guard let data = try? JSONEncoder().encode(settings.clamped()) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter SettingsStoreTests`
Expected: `Executed 5 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift .gitignore Sources Tests docs
git commit -m "feat: scaffold package with settings model and store" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Phase plan and timer engine (start / tick / pause / resume)

**Files:**
- Create: `Sources/PomodoroCore/Phase.swift`
- Create: `Sources/PomodoroCore/WorkRecord.swift`
- Create: `Sources/PomodoroCore/TimerEngine.swift`
- Test: `Tests/PomodoroCoreTests/TimerEngineTests.swift`

**Interfaces:**
- Consumes: `PomodoroSettings` (Task 1).
- Produces:
  - `public enum PhaseKind: String, Codable, Equatable { case work, rest }`
  - `public struct Phase: Equatable { let kind: PhaseKind; let cycle: Int; let duration: TimeInterval }` + public memberwise `init(kind:cycle:duration:)`
  - `public enum PhasePlan { static func phases(for: PomodoroSettings) -> [Phase] }`
  - `public struct WorkRecord: Codable, Equatable { let start: Date; let seconds: Int; let completed: Bool }` + `init(start:seconds:completed:)`
  - `public enum PauseReason: Equatable { case user, idle, sleep }`
  - `public enum EngineStatus: Equatable { case idle, running, paused(PauseReason) }`
  - `public enum EngineEvent: Equatable { case workLogged(WorkRecord); case phaseCompleted(Phase, next: Phase?); case finished }`
  - `public final class TimerEngine`: `status`, `phases`, `remaining: TimeInterval`, `currentPhase: Phase?`, `totalCycles: Int`, `start(settings:now:)`, `@discardableResult tick(now:) -> [EngineEvent]`, `@discardableResult pause(reason:now:) -> [EngineEvent]`, `resume(now:)`. (Task 3 adds `skip`, `stop`, `rewind` to this same class.)

- [ ] **Step 1: Write the failing tests**

`Tests/PomodoroCoreTests/TimerEngineTests.swift`:

```swift
import XCTest
@testable import PomodoroCore

final class TimerEngineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let work1 = Phase(kind: .work, cycle: 1, duration: 1500)
    let rest1 = Phase(kind: .rest, cycle: 1, duration: 300)
    let work2 = Phase(kind: .work, cycle: 2, duration: 1500)

    func settings(work: Int = 25, rest: Int = 5, repeats: Int = 2) -> PomodoroSettings {
        var settings = PomodoroSettings()
        settings.workMinutes = work
        settings.breakMinutes = rest
        settings.repeats = repeats
        return settings
    }

    func startedEngine(repeats: Int = 2) -> TimerEngine {
        let engine = TimerEngine()
        engine.start(settings: settings(repeats: repeats), now: t0)
        return engine
    }

    func testPhasePlanAlternatesAndOmitsTrailingBreak() {
        let phases = PhasePlan.phases(for: settings(repeats: 3))
        XCTAssertEqual(phases.map(\.kind), [.work, .rest, .work, .rest, .work])
        XCTAssertEqual(phases.map(\.cycle), [1, 1, 2, 2, 3])
        XCTAssertEqual(phases[0].duration, 1500)
        XCTAssertEqual(phases[1].duration, 300)
    }

    func testStartBeginsFirstWorkPhase() {
        let engine = startedEngine()
        XCTAssertEqual(engine.status, .running)
        XCTAssertEqual(engine.currentPhase, work1)
        XCTAssertEqual(engine.remaining, 1500)
        XCTAssertEqual(engine.totalCycles, 2)
    }

    func testTickCountsDown() {
        let engine = startedEngine()
        XCTAssertEqual(engine.tick(now: t0 + 10), [])
        XCTAssertEqual(engine.remaining, 1490)
    }

    func testTickIgnoredWhenIdle() {
        let engine = TimerEngine()
        XCTAssertEqual(engine.tick(now: t0), [])
        XCTAssertEqual(engine.status, .idle)
        XCTAssertNil(engine.currentPhase)
    }

    func testCompletingWorkLogsAndAdvancesToBreak() {
        let engine = startedEngine()
        XCTAssertEqual(engine.tick(now: t0 + 1500), [
            .workLogged(WorkRecord(start: t0, seconds: 1500, completed: true)),
            .phaseCompleted(work1, next: rest1),
        ])
        XCTAssertEqual(engine.currentPhase, rest1)
        XCTAssertEqual(engine.remaining, 300)
    }

    func testOvershootCarriesIntoNextPhase() {
        let engine = startedEngine()
        engine.tick(now: t0 + 1510)
        XCTAssertEqual(engine.currentPhase, rest1)
        XCTAssertEqual(engine.remaining, 290)
    }

    func testFinishingLastPhaseEmitsFinishedAndGoesIdle() {
        let engine = startedEngine(repeats: 1)
        XCTAssertEqual(engine.tick(now: t0 + 1500), [
            .workLogged(WorkRecord(start: t0, seconds: 1500, completed: true)),
            .phaseCompleted(work1, next: nil),
            .finished,
        ])
        XCTAssertEqual(engine.status, .idle)
        XCTAssertNil(engine.currentPhase)
        XCTAssertEqual(engine.remaining, 0)
    }

    func testHugeGapRunsThroughWholeSequenceOnce() {
        let engine = startedEngine(repeats: 2)
        XCTAssertEqual(engine.tick(now: t0 + 100_000), [
            .workLogged(WorkRecord(start: t0, seconds: 1500, completed: true)),
            .phaseCompleted(work1, next: rest1),
            .phaseCompleted(rest1, next: work2),
            .workLogged(WorkRecord(start: t0 + 1800, seconds: 1500, completed: true)),
            .phaseCompleted(work2, next: nil),
            .finished,
        ])
        XCTAssertEqual(engine.status, .idle)
        XCTAssertEqual(engine.tick(now: t0 + 200_000), [])
    }

    func testPauseAccountsElapsedTimeBeforePausing() {
        let engine = startedEngine()
        engine.pause(reason: .user, now: t0 + 30)
        XCTAssertEqual(engine.status, .paused(.user))
        XCTAssertEqual(engine.remaining, 1470)
    }

    func testPauseFreezesRemainingUntilResume() {
        let engine = startedEngine()
        engine.pause(reason: .user, now: t0 + 10)
        XCTAssertEqual(engine.tick(now: t0 + 100), [])
        XCTAssertEqual(engine.remaining, 1490)
        engine.resume(now: t0 + 100)
        engine.tick(now: t0 + 105)
        XCTAssertEqual(engine.remaining, 1485)
    }

    func testPauseKeepsOriginalReason() {
        let engine = startedEngine()
        engine.pause(reason: .user, now: t0 + 10)
        engine.pause(reason: .idle, now: t0 + 20)
        XCTAssertEqual(engine.status, .paused(.user))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TimerEngineTests`
Expected: build FAILS with `cannot find 'Phase' in scope` / `cannot find 'TimerEngine' in scope`.

- [ ] **Step 3: Implement**

`Sources/PomodoroCore/Phase.swift`:

```swift
import Foundation

public enum PhaseKind: String, Codable, Equatable {
    case work, rest
}

public struct Phase: Equatable {
    public let kind: PhaseKind
    public let cycle: Int
    public let duration: TimeInterval

    public init(kind: PhaseKind, cycle: Int, duration: TimeInterval) {
        self.kind = kind
        self.cycle = cycle
        self.duration = duration
    }
}

public enum PhasePlan {
    /// work, rest, work, rest, …, work — `repeats` work phases and no trailing break.
    public static func phases(for settings: PomodoroSettings) -> [Phase] {
        let settings = settings.clamped()
        var phases: [Phase] = []
        for cycle in 1...settings.repeats {
            phases.append(Phase(kind: .work, cycle: cycle, duration: TimeInterval(settings.workMinutes * 60)))
            if cycle < settings.repeats {
                phases.append(Phase(kind: .rest, cycle: cycle, duration: TimeInterval(settings.breakMinutes * 60)))
            }
        }
        return phases
    }
}
```

`Sources/PomodoroCore/WorkRecord.swift`:

```swift
import Foundation

public struct WorkRecord: Codable, Equatable {
    public let start: Date
    public let seconds: Int
    public let completed: Bool

    public init(start: Date, seconds: Int, completed: Bool) {
        self.start = start
        self.seconds = seconds
        self.completed = completed
    }
}
```

`Sources/PomodoroCore/TimerEngine.swift`:

```swift
import Foundation

public enum PauseReason: Equatable {
    case user, idle, sleep
}

public enum EngineStatus: Equatable {
    case idle, running, paused(PauseReason)
}

public enum EngineEvent: Equatable {
    case workLogged(WorkRecord)
    case phaseCompleted(Phase, next: Phase?)
    case finished
}

public final class TimerEngine {
    public private(set) var status: EngineStatus = .idle
    public private(set) var phases: [Phase] = []
    public private(set) var remaining: TimeInterval = 0
    private var index = 0
    private var phaseStartedAt = Date.distantPast
    private var lastTick: Date?

    public init() {}

    public var currentPhase: Phase? { status == .idle ? nil : phases[index] }
    public var totalCycles: Int { phases.last?.cycle ?? 0 }

    public func start(settings: PomodoroSettings, now: Date) {
        phases = PhasePlan.phases(for: settings)
        index = 0
        remaining = phases[0].duration
        phaseStartedAt = now
        lastTick = now
        status = .running
    }

    /// Advances by wall-clock time since the last tick. A large gap runs through as many phases as it covers.
    @discardableResult
    public func tick(now: Date) -> [EngineEvent] {
        guard status == .running, let last = lastTick else { return [] }
        var delta = max(0, now.timeIntervalSince(last))
        lastTick = now
        var events: [EngineEvent] = []
        while status == .running {
            let step = min(delta, remaining)
            remaining -= step
            delta -= step
            guard remaining <= 0 else { break }
            events += endCurrentPhase(at: now.addingTimeInterval(-delta), completed: true)
        }
        return events
    }

    /// Counts time up to `now`, then pauses. Does nothing if already paused, so the first reason wins.
    @discardableResult
    public func pause(reason: PauseReason, now: Date) -> [EngineEvent] {
        let events = tick(now: now)
        if status == .running {
            status = .paused(reason)
            lastTick = nil
        }
        return events
    }

    public func resume(now: Date) {
        guard case .paused = status else { return }
        status = .running
        lastTick = now
    }

    private func endCurrentPhase(at date: Date, completed: Bool) -> [EngineEvent] {
        let phase = phases[index]
        var events: [EngineEvent] = []
        if completed, phase.kind == .work {
            events.append(.workLogged(WorkRecord(start: phaseStartedAt, seconds: Int(phase.duration), completed: true)))
        }
        index += 1
        let next = index < phases.count ? phases[index] : nil
        if completed {
            events.append(.phaseCompleted(phase, next: next))
        }
        if let next {
            remaining = next.duration
            phaseStartedAt = date
        } else {
            status = .idle
            remaining = 0
            lastTick = nil
            events.append(.finished)
        }
        return events
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TimerEngineTests`
Expected: `Executed 11 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/PomodoroCore Tests/PomodoroCoreTests/TimerEngineTests.swift
git commit -m "feat: add phase plan and timer engine" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Skip / stop / rewind + auto-pause policy

**Files:**
- Modify: `Sources/PomodoroCore/TimerEngine.swift` (add `skip`, `stop`, `rewind`, `partialWorkRecord`; extend `endCurrentPhase`)
- Create: `Sources/PomodoroCore/AutoPausePolicy.swift`
- Test: `Tests/PomodoroCoreTests/TimerControlTests.swift`, `Tests/PomodoroCoreTests/AutoPausePolicyTests.swift`

**Interfaces:**
- Consumes: everything from Task 2.
- Produces:
  - `TimerEngine.skip(now: Date) -> [EngineEvent]` (`@discardableResult`) — ends the current phase early (partial work logged as `completed: false`, no `.phaseCompleted`), next phase starts **running**.
  - `TimerEngine.stop(now: Date) -> [EngineEvent]` (`@discardableResult`) — logs partial work, goes `.idle`.
  - `TimerEngine.rewind(seconds: TimeInterval)` — adds time back to `remaining`, capped at the phase duration.
  - `public enum AutoPauseAction: Equatable { case none, pause(rewind: TimeInterval), resume }`
  - `public enum AutoPausePolicy { static let activityWindow: TimeInterval; static func decide(enabled: Bool, status: EngineStatus, phaseKind: PhaseKind?, idleSeconds: TimeInterval, threshold: TimeInterval) -> AutoPauseAction }`

- [ ] **Step 1: Write the failing tests**

`Tests/PomodoroCoreTests/TimerControlTests.swift`:

```swift
import XCTest
@testable import PomodoroCore

final class TimerControlTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func startedEngine() -> TimerEngine {
        var settings = PomodoroSettings()
        settings.workMinutes = 25
        settings.breakMinutes = 5
        settings.repeats = 2
        let engine = TimerEngine()
        engine.start(settings: settings, now: t0)
        return engine
    }

    func testSkipWorkLogsPartialAndStartsBreak() {
        let engine = startedEngine()
        XCTAssertEqual(engine.skip(now: t0 + 600), [
            .workLogged(WorkRecord(start: t0, seconds: 600, completed: false)),
        ])
        XCTAssertEqual(engine.currentPhase, Phase(kind: .rest, cycle: 1, duration: 300))
        XCTAssertEqual(engine.remaining, 300)
        XCTAssertEqual(engine.status, .running)
    }

    func testSkipBreakLogsNothing() {
        let engine = startedEngine()
        engine.tick(now: t0 + 1500)
        XCTAssertEqual(engine.skip(now: t0 + 1600), [])
        XCTAssertEqual(engine.currentPhase, Phase(kind: .work, cycle: 2, duration: 1500))
        XCTAssertEqual(engine.remaining, 1500)
    }

    func testSkipWhilePausedStartsNextPhaseRunning() {
        let engine = startedEngine()
        engine.pause(reason: .user, now: t0 + 10)
        XCTAssertEqual(engine.skip(now: t0 + 50), [
            .workLogged(WorkRecord(start: t0, seconds: 10, completed: false)),
        ])
        XCTAssertEqual(engine.status, .running)
        engine.tick(now: t0 + 60)
        XCTAssertEqual(engine.remaining, 290)
    }

    func testSkipLastPhaseFinishes() {
        let engine = startedEngine()
        engine.tick(now: t0 + 1800)
        let events = engine.skip(now: t0 + 1800)
        XCTAssertEqual(events.last, .finished)
        XCTAssertEqual(engine.status, .idle)
    }

    func testStopLogsPartialWorkAndGoesIdle() {
        let engine = startedEngine()
        XCTAssertEqual(engine.stop(now: t0 + 120), [
            .workLogged(WorkRecord(start: t0, seconds: 120, completed: false)),
        ])
        XCTAssertEqual(engine.status, .idle)
        XCTAssertNil(engine.currentPhase)
        XCTAssertEqual(engine.remaining, 0)
    }

    func testStopImmediatelyLogsNothing() {
        let engine = startedEngine()
        XCTAssertEqual(engine.stop(now: t0), [])
        XCTAssertEqual(engine.status, .idle)
    }

    func testStopWhenIdleDoesNothing() {
        XCTAssertEqual(TimerEngine().stop(now: t0), [])
    }

    func testRewindRestoresTimeButNotPastFullDuration() {
        let engine = startedEngine()
        engine.tick(now: t0 + 100)
        engine.rewind(seconds: 60)
        XCTAssertEqual(engine.remaining, 1460)
        engine.rewind(seconds: 1000)
        XCTAssertEqual(engine.remaining, 1500)
    }

    func testIdleRewindReducesLoggedWork() {
        let engine = startedEngine()
        engine.tick(now: t0 + 600)
        engine.pause(reason: .idle, now: t0 + 600)
        engine.rewind(seconds: 60)
        XCTAssertEqual(engine.stop(now: t0 + 700), [
            .workLogged(WorkRecord(start: t0, seconds: 540, completed: false)),
        ])
    }
}
```

`Tests/PomodoroCoreTests/AutoPausePolicyTests.swift`:

```swift
import XCTest
@testable import PomodoroCore

final class AutoPausePolicyTests: XCTestCase {
    func decide(enabled: Bool = true, status: EngineStatus, kind: PhaseKind? = .work, idle: TimeInterval) -> AutoPauseAction {
        AutoPausePolicy.decide(enabled: enabled, status: status, phaseKind: kind, idleSeconds: idle, threshold: 60)
    }

    func testPausesRunningWorkWhenIdlePastThreshold() {
        XCTAssertEqual(decide(status: .running, idle: 61), .pause(rewind: 61))
    }

    func testDoesNothingUnderThreshold() {
        XCTAssertEqual(decide(status: .running, idle: 59), AutoPauseAction.none)
    }

    func testDoesNothingWhenDisabled() {
        XCTAssertEqual(decide(enabled: false, status: .running, idle: 600), AutoPauseAction.none)
    }

    func testNeverPausesDuringBreak() {
        XCTAssertEqual(decide(status: .running, kind: .rest, idle: 600), AutoPauseAction.none)
    }

    func testResumesIdlePauseOnActivity() {
        XCTAssertEqual(decide(status: .paused(.idle), idle: 0.5), .resume)
    }

    func testResumesIdlePauseEvenIfFeatureTurnedOffMeanwhile() {
        XCTAssertEqual(decide(enabled: false, status: .paused(.idle), idle: 0.5), .resume)
    }

    func testStaysPausedWhileStillIdle() {
        XCTAssertEqual(decide(status: .paused(.idle), idle: 120), AutoPauseAction.none)
    }

    func testNeverResumesUserOrSleepPause() {
        XCTAssertEqual(decide(status: .paused(.user), idle: 0), AutoPauseAction.none)
        XCTAssertEqual(decide(status: .paused(.sleep), idle: 0), AutoPauseAction.none)
    }

    func testDoesNothingWhenIdle() {
        XCTAssertEqual(decide(status: .idle, kind: nil, idle: 600), AutoPauseAction.none)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "TimerControlTests|AutoPausePolicyTests"`
Expected: build FAILS with `value of type 'TimerEngine' has no member 'skip'` and `cannot find 'AutoPausePolicy' in scope`.

- [ ] **Step 3: Implement**

In `Sources/PomodoroCore/TimerEngine.swift`, add these public methods after `resume(now:)`:

```swift
    /// Ends the current phase early. Partial work is logged; the next phase starts running.
    @discardableResult
    public func skip(now: Date) -> [EngineEvent] {
        var events = tick(now: now)
        guard status != .idle else { return events }
        events += endCurrentPhase(at: now, completed: false)
        if status != .idle {
            status = .running
            lastTick = now
        }
        return events
    }

    @discardableResult
    public func stop(now: Date) -> [EngineEvent] {
        var events = tick(now: now)
        guard status != .idle else { return events }
        if let record = partialWorkRecord() {
            events.append(.workLogged(record))
        }
        status = .idle
        remaining = 0
        lastTick = nil
        return events
    }

    /// Gives back time that shouldn't have counted (e.g. idle time), never beyond the phase length.
    public func rewind(seconds: TimeInterval) {
        guard let phase = currentPhase else { return }
        remaining = min(phase.duration, remaining + max(0, seconds))
    }
```

Add this private helper above `endCurrentPhase`:

```swift
    private func partialWorkRecord() -> WorkRecord? {
        guard let phase = currentPhase, phase.kind == .work else { return nil }
        let worked = Int((phase.duration - remaining).rounded())
        return worked >= 1 ? WorkRecord(start: phaseStartedAt, seconds: worked, completed: false) : nil
    }
```

In `endCurrentPhase`, replace:

```swift
        if completed, phase.kind == .work {
            events.append(.workLogged(WorkRecord(start: phaseStartedAt, seconds: Int(phase.duration), completed: true)))
        }
```

with:

```swift
        if completed {
            if phase.kind == .work {
                events.append(.workLogged(WorkRecord(start: phaseStartedAt, seconds: Int(phase.duration), completed: true)))
            }
        } else if let record = partialWorkRecord() {
            events.append(.workLogged(record))
        }
```

`Sources/PomodoroCore/AutoPausePolicy.swift`:

```swift
import Foundation

public enum AutoPauseAction: Equatable {
    case none
    case pause(rewind: TimeInterval)
    case resume
}

public enum AutoPausePolicy {
    /// Input within this many seconds counts as "the user is back".
    public static let activityWindow: TimeInterval = 2

    public static func decide(
        enabled: Bool,
        status: EngineStatus,
        phaseKind: PhaseKind?,
        idleSeconds: TimeInterval,
        threshold: TimeInterval
    ) -> AutoPauseAction {
        switch status {
        case .running:
            // Rewind the whole idle stretch so time away isn't logged as work.
            return enabled && phaseKind == .work && idleSeconds >= threshold ? .pause(rewind: idleSeconds) : .none
        case .paused(.idle):
            return idleSeconds < activityWindow ? .resume : .none
        default:
            return .none
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: all suites pass (`Executed 34 tests, with 0 failures`).

- [ ] **Step 5: Commit**

```bash
git add Sources/PomodoroCore Tests/PomodoroCoreTests
git commit -m "feat: add skip/stop/rewind and idle auto-pause policy" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Time formatting and notification copy

**Files:**
- Create: `Sources/PomodoroCore/TimeFormat.swift`
- Create: `Sources/PomodoroCore/PhaseMessages.swift`
- Test: `Tests/PomodoroCoreTests/FormattingTests.swift`

**Interfaces:**
- Consumes: `Phase`, `PhaseKind` (Task 2).
- Produces:
  - `public enum TimeFormat { static func clock(_ seconds: TimeInterval) -> String; static func duration(_ seconds: Int) -> String }`
  - `public struct PhaseMessage: Equatable { let title: String; let body: String }`
  - `public enum PhaseMessages { static func completed(_ phase: Phase, next: Phase, totalCycles: Int) -> PhaseMessage; static func finished(workedSeconds: Int) -> PhaseMessage }`

- [ ] **Step 1: Write the failing tests**

`Tests/PomodoroCoreTests/FormattingTests.swift`:

```swift
import XCTest
@testable import PomodoroCore

final class FormattingTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(TimeFormat.clock(1500), "25:00")
        XCTAssertEqual(TimeFormat.clock(1499.2), "25:00") // rounds up: never show 00:00 while time remains
        XCTAssertEqual(TimeFormat.clock(59), "00:59")
        XCTAssertEqual(TimeFormat.clock(0), "00:00")
        XCTAssertEqual(TimeFormat.clock(-3), "00:00")
        XCTAssertEqual(TimeFormat.clock(3600), "1:00:00")
        XCTAssertEqual(TimeFormat.clock(3725), "1:02:05")
    }

    func testDuration() {
        XCTAssertEqual(TimeFormat.duration(0), "0m")
        XCTAssertEqual(TimeFormat.duration(59), "0m")
        XCTAssertEqual(TimeFormat.duration(1500), "25m")
        XCTAssertEqual(TimeFormat.duration(3600), "1h")
        XCTAssertEqual(TimeFormat.duration(5400), "1h 30m")
    }

    func testWorkCompletedMessage() {
        let message = PhaseMessages.completed(
            Phase(kind: .work, cycle: 1, duration: 1500),
            next: Phase(kind: .rest, cycle: 1, duration: 300),
            totalCycles: 4
        )
        XCTAssertEqual(message, PhaseMessage(title: "Work session 1 of 4 done", body: "Time for a 5-minute break."))
    }

    func testBreakCompletedMessage() {
        let message = PhaseMessages.completed(
            Phase(kind: .rest, cycle: 1, duration: 300),
            next: Phase(kind: .work, cycle: 2, duration: 1500),
            totalCycles: 4
        )
        XCTAssertEqual(message, PhaseMessage(title: "Break over", body: "Starting work session 2 of 4 (25 min)."))
    }

    func testFinishedMessage() {
        XCTAssertEqual(
            PhaseMessages.finished(workedSeconds: 6000),
            PhaseMessage(title: "All sessions done", body: "You focused for 1h 40m.")
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter FormattingTests`
Expected: build FAILS with `cannot find 'TimeFormat' in scope`.

- [ ] **Step 3: Implement**

`Sources/PomodoroCore/TimeFormat.swift`:

```swift
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
}
```

`Sources/PomodoroCore/PhaseMessages.swift`:

```swift
import Foundation

public struct PhaseMessage: Equatable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public enum PhaseMessages {
    public static func completed(_ phase: Phase, next: Phase, totalCycles: Int) -> PhaseMessage {
        let nextMinutes = Int(next.duration / 60)
        switch phase.kind {
        case .work:
            return PhaseMessage(
                title: "Work session \(phase.cycle) of \(totalCycles) done",
                body: "Time for a \(nextMinutes)-minute break."
            )
        case .rest:
            return PhaseMessage(
                title: "Break over",
                body: "Starting work session \(next.cycle) of \(totalCycles) (\(nextMinutes) min)."
            )
        }
    }

    public static func finished(workedSeconds: Int) -> PhaseMessage {
        PhaseMessage(title: "All sessions done", body: "You focused for \(TimeFormat.duration(workedSeconds)).")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter FormattingTests`
Expected: `Executed 5 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/PomodoroCore Tests/PomodoroCoreTests/FormattingTests.swift
git commit -m "feat: add time formatting and notification messages" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Statistics store and summary

**Files:**
- Create: `Sources/PomodoroCore/StatsStore.swift`
- Create: `Sources/PomodoroCore/StatsSummary.swift`
- Test: `Tests/PomodoroCoreTests/StatsTests.swift`

**Interfaces:**
- Consumes: `WorkRecord` (Task 2).
- Produces:
  - `public final class StatsStore`: `init(fileURL: URL)`, `private(set) var records: [WorkRecord]`, `func append(_ record: WorkRecord) throws`, `static func defaultURL() throws -> URL`.
  - `public struct DayTotal: Equatable, Identifiable { let day: Date; let seconds: Int; var id: Date }`
  - `public struct StatsSummary: Equatable`: `todaySeconds`, `todaySessions`, `weekSeconds`, `allTimeSeconds`, `allTimeSessions: Int`, `last7Days: [DayTotal]` (oldest → today, always 7 entries); `init(records: [WorkRecord], now: Date, calendar: Calendar = .current)`.

- [ ] **Step 1: Write the failing tests**

`Tests/PomodoroCoreTests/StatsTests.swift`:

```swift
import XCTest
@testable import PomodoroCore

final class StatsStoreTests: XCTestCase {
    private var dir: URL!
    private var fileURL: URL { dir.appendingPathComponent("stats.json") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testMissingFileStartsEmpty() {
        XCTAssertEqual(StatsStore(fileURL: fileURL).records, [])
    }

    func testAppendPersistsAcrossInstances() throws {
        let record = WorkRecord(start: Date(timeIntervalSince1970: 1_000_000), seconds: 1500, completed: true)
        try StatsStore(fileURL: fileURL).append(record)
        XCTAssertEqual(StatsStore(fileURL: fileURL).records, [record])
    }

    func testCorruptFileIsMovedAsideAndStartsEmpty() throws {
        try Data("garbage".utf8).write(to: fileURL)
        let store = StatsStore(fileURL: fileURL)
        XCTAssertEqual(store.records, [])
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("stats.json.corrupt") }, "corrupt file should be kept, got \(names)")
        try store.append(WorkRecord(start: Date(), seconds: 60, completed: false))
        XCTAssertEqual(StatsStore(fileURL: fileURL).records.count, 1)
    }
}

final class StatsSummaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "GMT")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    func testAggregates() {
        let records = [
            WorkRecord(start: date(12, 9), seconds: 1500, completed: true),
            WorkRecord(start: date(12, 10), seconds: 1500, completed: true),
            WorkRecord(start: date(12, 11), seconds: 600, completed: false),
            WorkRecord(start: date(11, 9), seconds: 1500, completed: true),
            WorkRecord(start: date(4, 9), seconds: 1500, completed: true), // 8 days ago
        ]
        let summary = StatsSummary(records: records, now: date(12, 15), calendar: calendar)
        XCTAssertEqual(summary.todaySeconds, 3600)
        XCTAssertEqual(summary.todaySessions, 2)
        XCTAssertEqual(summary.weekSeconds, 5100)
        XCTAssertEqual(summary.allTimeSeconds, 6600)
        XCTAssertEqual(summary.allTimeSessions, 4)
        XCTAssertEqual(summary.last7Days.count, 7)
        XCTAssertEqual(summary.last7Days.first?.day, date(6, 0))
        XCTAssertEqual(summary.last7Days.last?.day, date(12, 0))
        XCTAssertEqual(summary.last7Days[5].seconds, 1500)
        XCTAssertEqual(summary.last7Days[6].seconds, 3600)
    }

    func testEmpty() {
        let summary = StatsSummary(records: [], now: date(12, 15), calendar: calendar)
        XCTAssertEqual(summary.todaySeconds, 0)
        XCTAssertEqual(summary.allTimeSessions, 0)
        XCTAssertEqual(summary.last7Days.map(\.seconds), [0, 0, 0, 0, 0, 0, 0])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "StatsStoreTests|StatsSummaryTests"`
Expected: build FAILS with `cannot find 'StatsStore' in scope`.

- [ ] **Step 3: Implement**

`Sources/PomodoroCore/StatsStore.swift`:

```swift
import Foundation

public final class StatsStore {
    public private(set) var records: [WorkRecord]
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        guard let data = try? Data(contentsOf: fileURL) else {
            records = []
            return
        }
        do {
            records = try JSONDecoder().decode([WorkRecord].self, from: data)
        } catch {
            // Keep the unreadable file for recovery instead of overwriting it on the next append.
            let backup = fileURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            records = []
        }
    }

    public func append(_ record: WorkRecord) throws {
        records.append(record)
        try JSONEncoder().encode(records).write(to: fileURL, options: .atomic)
    }

    /// ~/Library/Application Support/Pomodoro/stats.json (directory is created if needed).
    public static func defaultURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = support.appendingPathComponent("Pomodoro", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }
}
```

`Sources/PomodoroCore/StatsSummary.swift`:

```swift
import Foundation

public struct DayTotal: Equatable, Identifiable {
    public let day: Date
    public let seconds: Int
    public var id: Date { day }
}

public struct StatsSummary: Equatable {
    public let todaySeconds: Int
    public let todaySessions: Int
    public let weekSeconds: Int
    public let allTimeSeconds: Int
    public let allTimeSessions: Int
    /// Oldest first, ending today; always 7 entries.
    public let last7Days: [DayTotal]

    /// A record counts toward the day its work started.
    public init(records: [WorkRecord], now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        var secondsByDay: [Date: Int] = [:]
        for record in records {
            secondsByDay[calendar.startOfDay(for: record.start), default: 0] += record.seconds
        }
        last7Days = (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return DayTotal(day: day, seconds: secondsByDay[day] ?? 0)
        }
        todaySeconds = secondsByDay[today] ?? 0
        todaySessions = records.filter { $0.completed && calendar.isDate($0.start, inSameDayAs: now) }.count
        weekSeconds = last7Days.reduce(0) { $0 + $1.seconds }
        allTimeSeconds = records.reduce(0) { $0 + $1.seconds }
        allTimeSessions = records.filter(\.completed).count
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: all suites pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/PomodoroCore Tests/PomodoroCoreTests/StatsTests.swift
git commit -m "feat: add statistics store and summary" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Menu bar app — timer, countdown, alerts, idle + sleep handling, bundling

**Files:**
- Modify: `Package.swift`
- Create: `Resources/Info.plist`, `scripts/bundle.sh`
- Create: `Sources/Pomodoro/PomodoroApp.swift`, `AppModel.swift`, `Notifier.swift`, `IdleDetector.swift`, `MenuBarLabel.swift`, `MenuContent.swift`

**Interfaces:**
- Consumes: all `PomodoroCore` types from Tasks 1–5.
- Produces (used by Task 7):
  - `@MainActor final class AppModel: ObservableObject` with `@Published var settings: PomodoroSettings` (auto-saves), `@Published private(set) var status: EngineStatus`, `phase: Phase?`, `remaining: TimeInterval`, `totalCycles: Int`, `summary: StatsSummary`; methods `togglePause()`, `skip()`, `stop()`, `refreshSummary()`.
  - `MenuContent(model: AppModel)` — Task 7 inserts two buttons into it.

No unit tests here (UI/system glue); verification is the manual checklist in Step 8. All logic it calls is already tested.

- [ ] **Step 1: Add the executable target**

Replace `Package.swift` with:

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pomodoro", targets: ["Pomodoro"]),
    ],
    targets: [
        .target(name: "PomodoroCore"),
        .executableTarget(name: "Pomodoro", dependencies: ["PomodoroCore"]),
        .testTarget(name: "PomodoroCoreTests", dependencies: ["PomodoroCore"]),
    ]
)
```

- [ ] **Step 2: System adapters**

`Sources/Pomodoro/IdleDetector.swift`:

```swift
import CoreGraphics
import Foundation

enum IdleDetector {
    /// Seconds since the last mouse or keyboard event. Needs no Accessibility permission.
    /// For mouse-only detection use `eventType: .mouseMoved` instead.
    static func secondsSinceLastInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}
```

`Sources/Pomodoro/Notifier.swift`:

```swift
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
```

- [ ] **Step 3: App model**

`Sources/Pomodoro/AppModel.swift`:

```swift
import AppKit
import PomodoroCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: PomodoroSettings {
        didSet { settingsStore.save(settings) }
    }
    @Published private(set) var status: EngineStatus = .idle
    @Published private(set) var phase: Phase?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var totalCycles = 0
    @Published private(set) var summary: StatsSummary

    private let engine = TimerEngine()
    private let settingsStore: SettingsStore
    private let statsStore: StatsStore
    private let notifier = Notifier()
    private var ticker: Timer?
    private var activity: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var sequenceWorkedSeconds = 0

    init() {
        let settingsStore = SettingsStore()
        let statsURL = (try? StatsStore.defaultURL())
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("pomodoro-stats.json")
        let statsStore = StatsStore(fileURL: statsURL)
        self.settingsStore = settingsStore
        self.statsStore = statsStore
        self.settings = settingsStore.load()
        self.summary = StatsSummary(records: statsStore.records, now: Date())

        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pause(reason: .sleep) }
        }
        notifier.requestAuthorization()
    }

    func togglePause() {
        switch status {
        case .idle: start()
        case .running: pause(reason: .user)
        case .paused:
            engine.resume(now: Date())
            sync()
        }
    }

    func skip() {
        handle(engine.skip(now: Date()))
        sync()
    }

    func stop() {
        handle(engine.stop(now: Date()))
        stopTicker()
        sync()
    }

    func refreshSummary() {
        summary = StatsSummary(records: statsStore.records, now: Date())
    }

    private func start() {
        sequenceWorkedSeconds = 0
        engine.start(settings: settings, now: Date())
        startTicker()
        refreshSummary()
        sync()
    }

    private func pause(reason: PauseReason) {
        handle(engine.pause(reason: reason, now: Date()))
        sync()
    }

    // Keeps running while paused so an idle pause can auto-resume.
    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common) // .common keeps ticking while the menu is open
        ticker = timer
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Pomodoro timer running"
        )
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }

    private func tick() {
        let now = Date()
        handle(engine.tick(now: now))
        let action = AutoPausePolicy.decide(
            enabled: settings.autoPauseEnabled,
            status: engine.status,
            phaseKind: engine.currentPhase?.kind,
            idleSeconds: IdleDetector.secondsSinceLastInput(),
            threshold: TimeInterval(settings.idleThresholdSeconds)
        )
        switch action {
        case .pause(let rewind):
            handle(engine.pause(reason: .idle, now: now))
            engine.rewind(seconds: rewind)
        case .resume:
            engine.resume(now: now)
        case .none:
            break
        }
        sync()
    }

    private func handle(_ events: [EngineEvent]) {
        for event in events {
            switch event {
            case .workLogged(let record):
                sequenceWorkedSeconds += record.seconds
                do {
                    try statsStore.append(record)
                } catch {
                    NSLog("Pomodoro: failed to save stats: \(error)")
                }
                refreshSummary()
            case .phaseCompleted(let phase, let next):
                // The last phase is announced by .finished instead.
                if let next {
                    notifier.announce(
                        PhaseMessages.completed(phase, next: next, totalCycles: engine.totalCycles),
                        settings: settings
                    )
                }
            case .finished:
                notifier.announce(PhaseMessages.finished(workedSeconds: sequenceWorkedSeconds), settings: settings)
                stopTicker()
            }
        }
    }

    private func sync() {
        status = engine.status
        phase = engine.currentPhase
        remaining = engine.remaining
        totalCycles = engine.totalCycles
    }
}
```

- [ ] **Step 4: Menu bar views and entry point**

`Sources/Pomodoro/MenuBarLabel.swift`:

```swift
import PomodoroCore
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.status == .idle {
            Image(systemName: "timer")
        } else {
            Text("\(Image(systemName: symbol)) \(TimeFormat.clock(model.remaining))")
                .monospacedDigit()
        }
    }

    private var symbol: String {
        if case .paused = model.status { return "pause.circle" }
        return model.phase?.kind == .rest ? "cup.and.saucer" : "brain.head.profile"
    }
}
```

`Sources/Pomodoro/MenuContent.swift`:

```swift
import AppKit
import PomodoroCore
import SwiftUI

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(statusLine)
        Divider()
        Button(primaryTitle) { model.togglePause() }
        if model.status != .idle {
            Button("Skip Phase") { model.skip() }
            Button("Stop") { model.stop() }
        }
        Divider()
        Text("Today: \(TimeFormat.duration(model.summary.todaySeconds)) · \(model.summary.todaySessions) sessions")
        Divider()
        Button("Quit Pomodoro") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var primaryTitle: String {
        switch model.status {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        }
    }

    private var statusLine: String {
        guard let phase = model.phase else {
            return "Ready — \(model.settings.workMinutes) min × \(model.settings.repeats)"
        }
        let name = phase.kind == .work ? "Work" : "Break"
        let base = "\(name) \(phase.cycle)/\(model.totalCycles) — \(TimeFormat.clock(model.remaining))"
        switch model.status {
        case .paused(.user): return base + " (paused)"
        case .paused(.idle): return base + " (paused — idle)"
        case .paused(.sleep): return base + " (paused — sleep)"
        default: return base
        }
    }
}
```

`Sources/Pomodoro/PomodoroApp.swift`:

```swift
import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
    }
}
```

- [ ] **Step 5: Bundle metadata and script**

`Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.conner.pomodoro</string>
    <key>CFBundleName</key>
    <string>Pomodoro</string>
    <key>CFBundleExecutable</key>
    <string>Pomodoro</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

`scripts/bundle.sh`:

```bash
#!/bin/bash
# Builds a release binary and wraps it into build/Pomodoro.app (menu-bar-only, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Pomodoro

APP=build/Pomodoro.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Pomodoro "$APP/Contents/MacOS/Pomodoro"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $APP"
```

```bash
chmod +x scripts/bundle.sh
```

- [ ] **Step 6: Build**

Run: `swift build && swift test`
Expected: `Build complete!` with no errors (deprecation warnings acceptable); all tests still pass.

- [ ] **Step 7: Bundle and launch**

Run: `scripts/bundle.sh && open build/Pomodoro.app`
Expected: `Built build/Pomodoro.app`; a timer icon appears in the menu bar; no Dock icon; macOS asks to allow notifications.

- [ ] **Step 8: Manual verification checklist**

1. Click the icon → menu shows "Ready — 25 min × 4", Start, Today line, Quit.
2. Start → menu bar shows brain icon + `25:00` counting down each second; it keeps counting while the menu is open.
3. Pause → icon becomes pause symbol, digits freeze; menu says "(paused)". Resume → continues.
4. Skip Phase → switches to cup icon at `05:00`. Stop → back to timer icon; Today line now shows the partial minutes (if ≥ 1 min).
5. Quit works.

If any check fails, stop and debug with superpowers:systematic-debugging before committing.

- [ ] **Step 9: Commit**

```bash
git add Package.swift Resources scripts Sources/Pomodoro
git commit -m "feat: add menu bar app with countdown, alerts, idle and sleep handling" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Settings and Statistics windows

**Files:**
- Create: `Sources/Pomodoro/WindowPresenter.swift`, `Sources/Pomodoro/SettingsView.swift`, `Sources/Pomodoro/StatsView.swift`
- Modify: `Sources/Pomodoro/MenuContent.swift` (add two buttons after the Today line)

**Interfaces:**
- Consumes: `AppModel` (Task 6): `settings` binding, `status`, `summary`, `refreshSummary()`; `PomodoroSettings` ranges and `soundNames`; `TimeFormat`; `DayTotal`.
- Produces: `WindowPresenter.shared.show(id:title:content:)`.

Windows are plain `NSWindow`s hosting SwiftUI rather than SwiftUI `Settings`/`Window` scenes: a menu-bar-only (`LSUIElement`) app must explicitly activate itself or its windows open behind other apps.

- [ ] **Step 1: Window presenter**

`Sources/Pomodoro/WindowPresenter.swift`:

```swift
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
```

- [ ] **Step 2: Settings view**

`Sources/Pomodoro/SettingsView.swift`:

```swift
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
```

- [ ] **Step 3: Statistics view**

`Sources/Pomodoro/StatsView.swift`:

```swift
import Charts
import PomodoroCore
import SwiftUI

struct StatsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let summary = model.summary
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                tile("Today", TimeFormat.duration(summary.todaySeconds), "\(summary.todaySessions) sessions")
                tile("Last 7 days", TimeFormat.duration(summary.weekSeconds), " ")
                tile("All time", TimeFormat.duration(summary.allTimeSeconds), "\(summary.allTimeSessions) sessions")
            }
            Chart(summary.last7Days) { day in
                BarMark(
                    x: .value("Day", day.day, unit: .day),
                    y: .value("Minutes", day.seconds / 60)
                )
            }
            .chartYAxisLabel("Minutes")
            .frame(height: 180)
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { model.refreshSummary() } // "today" rolls over at midnight
    }

    private func tile(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 4: Wire into the menu**

In `Sources/Pomodoro/MenuContent.swift`, replace:

```swift
        Text("Today: \(TimeFormat.duration(model.summary.todaySeconds)) · \(model.summary.todaySessions) sessions")
        Divider()
```

with:

```swift
        Text("Today: \(TimeFormat.duration(model.summary.todaySeconds)) · \(model.summary.todaySessions) sessions")
        Button("Statistics…") {
            WindowPresenter.shared.show(id: "stats", title: "Statistics") { StatsView(model: model) }
        }
        Button("Settings…") {
            WindowPresenter.shared.show(id: "settings", title: "Settings") { SettingsView(model: model) }
        }
        .keyboardShortcut(",")
        Divider()
```

- [ ] **Step 5: Build, bundle, launch**

Run: `swift build && swift test && scripts/bundle.sh && (pkill -x Pomodoro || true) && open build/Pomodoro.app`
Expected: build succeeds, all tests pass, app relaunches.

- [ ] **Step 6: Manual verification checklist**

1. Settings… opens a window in front of other apps; reopening it focuses the same window (no duplicates).
2. Set Work 1 min, Break 1 min, Repeats 2. Changing the Sound picker plays the chosen sound.
3. Quit and relaunch → settings persisted.
4. Start → after 1 min: sound plays + banner "Work session 1 of 2 done". After the break: "Break over". After the second work: "All sessions done — You focused for 2m"; icon returns to idle.
5. Turn sound off / notifications off → the next phase end is silent / shows no banner respectively.
6. Enable auto-pause, idle threshold 15 s, Start, keep hands off for ~20 s → menu bar shows pause icon, menu says "(paused — idle)", remaining time jumped back up by ~15 s. Move the mouse → resumes within ~1 s. Type without moving the mouse → does **not** pause.
7. Pause manually, wait 20 s, move the mouse → stays paused.
8. Statistics… shows Today / Last 7 days / All time tiles and a bar for today matching the minutes worked.
9. Start, then `pmset sleepnow` (or close the lid), wake → timer is "(paused — sleep)" with the same remaining time as before sleep.

If any check fails, stop and debug with superpowers:systematic-debugging before committing.

- [ ] **Step 7: Commit**

```bash
git add Sources/Pomodoro
git commit -m "feat: add settings and statistics windows" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Long break every N sessions

Rule: when enabled, the break after work session `c` is long if `c % longBreakEvery == 0`. There is still no trailing break, so a long break only happens if `repeats > longBreakEvery`; the settings UI says so.

**Files:**
- Modify: `Sources/PomodoroCore/PomodoroSettings.swift`, `Sources/PomodoroCore/Phase.swift`, `Sources/Pomodoro/SettingsView.swift`
- Test: `Tests/PomodoroCoreTests/LongBreakTests.swift`

**Interfaces:**
- Produces: `PomodoroSettings.longBreakEnabled: Bool = false`, `longBreakMinutes: Int = 15`, `longBreakEvery: Int = 4`; statics `longBreakRange = 1...60`, `longBreakEveryRange = 2...12`.

- [ ] **Step 1: Write the failing tests**

`Tests/PomodoroCoreTests/LongBreakTests.swift`:

```swift
import XCTest
@testable import PomodoroCore

final class LongBreakTests: XCTestCase {
    func settings(repeats: Int, every: Int, enabled: Bool = true) -> PomodoroSettings {
        var settings = PomodoroSettings()
        settings.repeats = repeats
        settings.longBreakEnabled = enabled
        settings.longBreakEvery = every
        settings.longBreakMinutes = 15
        return settings
    }

    func restDurations(_ settings: PomodoroSettings) -> [TimeInterval] {
        PhasePlan.phases(for: settings).filter { $0.kind == .rest }.map(\.duration)
    }

    func testLongBreakAfterEveryNthSession() {
        XCTAssertEqual(restDurations(settings(repeats: 5, every: 2)), [300, 900, 300, 900])
    }

    func testDisabledUsesShortBreaksOnly() {
        XCTAssertEqual(restDurations(settings(repeats: 5, every: 2, enabled: false)), [300, 300, 300, 300])
    }

    func testNoTrailingLongBreak() {
        XCTAssertEqual(restDurations(settings(repeats: 4, every: 4)), [300, 300, 300])
    }

    func testDefaultsAndClamping() {
        let defaults = PomodoroSettings()
        XCTAssertFalse(defaults.longBreakEnabled)
        XCTAssertEqual(defaults.longBreakMinutes, 15)
        XCTAssertEqual(defaults.longBreakEvery, 4)
        var settings = PomodoroSettings()
        settings.longBreakEvery = 1
        settings.longBreakMinutes = 500
        XCTAssertEqual(settings.clamped().longBreakEvery, 2)
        XCTAssertEqual(settings.clamped().longBreakMinutes, 60)
    }

    func testOldSavedSettingsGetLongBreakDefaults() throws {
        let old = Data(#"{"workMinutes":30,"breakMinutes":5,"repeats":4}"#.utf8)
        let settings = try JSONDecoder().decode(PomodoroSettings.self, from: old)
        XCTAssertEqual(settings.workMinutes, 30)
        XCTAssertFalse(settings.longBreakEnabled)
        XCTAssertEqual(settings.longBreakEvery, 4)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LongBreakTests`
Expected: build FAILS with `value of type 'PomodoroSettings' has no member 'longBreakEnabled'`.

- [ ] **Step 3: Implement**

In `PomodoroSettings.swift` add properties after `idleThresholdSeconds`:

```swift
    public var longBreakEnabled = false
    public var longBreakMinutes = 15
    public var longBreakEvery = 4
```

ranges after `idleThresholdRange`:

```swift
    public static let longBreakRange = 1...60
    public static let longBreakEveryRange = 2...12
```

decoding lines at the end of `init(from:)`:

```swift
        longBreakEnabled = try container.decodeIfPresent(Bool.self, forKey: .longBreakEnabled) ?? fallback.longBreakEnabled
        longBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? fallback.longBreakMinutes
        longBreakEvery = try container.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? fallback.longBreakEvery
```

clamping lines in `clamped()` after the idle threshold line:

```swift
        settings.longBreakMinutes = Self.clamp(longBreakMinutes, to: Self.longBreakRange)
        settings.longBreakEvery = Self.clamp(longBreakEvery, to: Self.longBreakEveryRange)
```

In `Phase.swift`, replace the rest-phase append in `PhasePlan.phases(for:)`:

```swift
            if cycle < settings.repeats {
                phases.append(Phase(kind: .rest, cycle: cycle, duration: TimeInterval(settings.breakMinutes * 60)))
            }
```

with:

```swift
            if cycle < settings.repeats {
                let isLong = settings.longBreakEnabled && cycle % settings.longBreakEvery == 0
                let minutes = isLong ? settings.longBreakMinutes : settings.breakMinutes
                phases.append(Phase(kind: .rest, cycle: cycle, duration: TimeInterval(minutes * 60)))
            }
```

In `SettingsView.swift`, add a section after `Section("Timer") { … }`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test && swift build`
Expected: all tests pass; app builds.

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: add long break every N sessions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Launch at login + global start/pause hotkey (⌥⌘P)

Launch at login uses `SMAppService.mainApp` (the system is the source of truth — not stored in settings). The hotkey uses Carbon `RegisterEventHotKey`, which needs no Accessibility permission. Shortcut is fixed at ⌥⌘P; a setting turns it on/off.

**Files:**
- Modify: `Sources/PomodoroCore/PomodoroSettings.swift` (add `hotkeyEnabled`)
- Create: `Sources/Pomodoro/HotKey.swift`, `Sources/Pomodoro/LoginItem.swift`
- Modify: `Sources/Pomodoro/AppModel.swift`, `Sources/Pomodoro/SettingsView.swift`
- Test: `Tests/PomodoroCoreTests/LongBreakTests.swift` (add one test)

**Interfaces:**
- Produces: `PomodoroSettings.hotkeyEnabled: Bool = true`; `HotKey(action:)` with `register()` / `unregister()`; `enum LoginItem { static var isEnabled: Bool; static func setEnabled(_:) throws }`.

- [ ] **Step 1: Write the failing test** (append to `LongBreakTests`)

```swift
    func testHotkeyEnabledByDefaultAndDecodedFromOldData() throws {
        XCTAssertTrue(PomodoroSettings().hotkeyEnabled)
        let old = try JSONDecoder().decode(PomodoroSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(old.hotkeyEnabled)
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter LongBreakTests`
Expected: build FAILS with `has no member 'hotkeyEnabled'`.

- [ ] **Step 3: Implement the setting**

In `PomodoroSettings.swift` add `public var hotkeyEnabled = true` after `longBreakEvery`, and at the end of `init(from:)`:

```swift
        hotkeyEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? fallback.hotkeyEnabled
```

Run: `swift test` → all pass.

- [ ] **Step 4: System adapters**

`Sources/Pomodoro/HotKey.swift`:

```swift
import Carbon.HIToolbox

/// Global ⌥⌘P. Carbon hot keys work without Accessibility permission; the handler runs on the main thread.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func register() {
        guard hotKeyRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            Unmanaged<HotKey>.fromOpaque(userData!).takeUnretainedValue().action()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        let id = EventHotKeyID(signature: OSType(0x504F_4D4F), id: 1) // 'POMO'
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(cmdKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
```

`Sources/Pomodoro/LoginItem.swift`:

```swift
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

- [ ] **Step 5: Wire into AppModel**

In `AppModel.swift`, change the `settings` property to:

```swift
    @Published var settings: PomodoroSettings {
        didSet {
            settingsStore.save(settings)
            applyHotKey()
        }
    }
```

add a property after `sequenceWorkedSeconds`:

```swift
    private lazy var hotKey = HotKey { [weak self] in
        MainActor.assumeIsolated { self?.togglePause() }
    }
```

add as the last line of `init()`:

```swift
        applyHotKey()
```

and add this private method after `refreshSummary()`:

```swift
    private func applyHotKey() {
        if settings.hotkeyEnabled { hotKey.register() } else { hotKey.unregister() }
    }
```

- [ ] **Step 6: Settings UI**

In `SettingsView.swift` add state and a section at the end of the `Form`:

```swift
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?
```

```swift
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
```

- [ ] **Step 7: Build, bundle, verify**

Run: `swift test && scripts/bundle.sh && (pkill -x Pomodoro || true) && open build/Pomodoro.app`

Manual checks:
1. In another app, press ⌥⌘P → timer starts; again → pauses; again → resumes. Turn the toggle off → ⌥⌘P does nothing.
2. Toggle Launch at login on → it appears in System Settings › General › Login Items; toggling off removes it. If registration fails, the error text shows and the toggle snaps back.
3. Long break: Work 1, Break 1, Long break 2 min after every 2, Repeats 3 → the 2nd break notification says "Time for a 2-minute break".

- [ ] **Step 8: Commit**

```bash
git add Sources Tests
git commit -m "feat: add launch at login and global start/pause hotkey" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Future ideas (not in this plan)

See the spec's "Future ideas" section. Long break, launch at login and the global hotkey are now Tasks 8–9.
