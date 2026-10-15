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

    private func appRecords(now: Date, calendar: Calendar) -> [WorkRecord] {
        let start = calendar.date(byAdding: .hour, value: -3, to: now)!
        return [
            WorkRecord(start: start, seconds: 3000, completed: true,
                       apps: ["Xcode": 1200, "Figma": 700, "Slack": 500, "Safari": 300, "Notes": 200, "Mail": 100]),
        ]
    }

    func testAppsAreTheTopFiveWhenNothingIsHidden() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 18))!
        let data = ShareCardData(records: appRecords(now: now, calendar: calendar), now: now, calendar: calendar)
        XCTAssertEqual(data.apps.map(\.name), ["Xcode", "Figma", "Slack", "Safari", "Notes"])
        XCTAssertEqual(data.apps.first?.seconds, 1200)
    }

    func testHiddenAppsAreLeftOffWithoutPullingInTheSixth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 18))!
        let data = ShareCardData(records: appRecords(now: now, calendar: calendar), now: now,
                                 hiddenApps: ["Slack", "Xcode"], calendar: calendar)
        XCTAssertEqual(data.apps.map(\.name), ["Figma", "Safari", "Notes"])
    }

    func testAppsEmptyWithoutAppData() {
        let now = Date()
        let data = ShareCardData(records: [WorkRecord(start: now, seconds: 1500, completed: true)], now: now)
        XCTAssertEqual(data.apps, [])
    }
}
