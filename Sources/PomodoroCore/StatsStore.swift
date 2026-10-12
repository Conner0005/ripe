import Foundation

public final class StatsStore {
    public private(set) var records: [WorkRecord]
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        do {
            records = try JSONDecoder().decode([WorkRecord].self, from: Data(contentsOf: fileURL))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            records = []
        } catch {
            // Unreadable or corrupt: keep it for recovery instead of overwriting it on the next append.
            let backup = fileURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            do {
                try FileManager.default.moveItem(at: fileURL, to: backup)
                NSLog("Pomodoro: could not read stats (\(error)); moved it to \(backup.path)")
            } catch {
                NSLog("Pomodoro: could not move unreadable stats aside: \(error)")
            }
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
