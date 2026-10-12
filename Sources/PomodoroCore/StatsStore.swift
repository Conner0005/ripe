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
