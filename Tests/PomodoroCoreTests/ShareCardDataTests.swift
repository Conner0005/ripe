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
