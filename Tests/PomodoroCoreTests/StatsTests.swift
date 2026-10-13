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

    func testUnreadableFileIsKeptNotOverwritten() throws {
        let original = WorkRecord(start: Date(timeIntervalSince1970: 1_000_000), seconds: 1500, completed: true)
        try StatsStore(fileURL: fileURL).append(original)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fileURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path) }

        let store = StatsStore(fileURL: fileURL)
        try store.append(WorkRecord(start: Date(), seconds: 60, completed: false))

        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("stats.json.corrupt") }, "unreadable file should be kept, got \(names)")
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
