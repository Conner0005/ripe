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
