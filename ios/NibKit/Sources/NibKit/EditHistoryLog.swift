import Foundation

/// One accepted edit, as shown on Home ("Recent edits") and the History screen.
public struct EditRecord: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let tool: String
    /// Best-effort label for where the edit happened ("Messages", "Mail").
    public let sourceApp: String?
    public let before: String
    public let after: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        tool: NibTool,
        sourceApp: String? = nil,
        before: String,
        after: String
    ) {
        self.id = id
        self.date = date
        self.tool = tool.title
        self.sourceApp = sourceApp
        self.before = before
        self.after = after
    }
}

/// Append-only edit log in the shared container.
///
/// Split of responsibility, driven by the extension's tight memory budget:
/// the **extension only appends one line** — no database engine, no parsing,
/// no indexing. The **host app** owns reading and (later) compacting it. Do not
/// add a SQLite dependency to the keyboard target to make History faster.
///
/// This file is local to the device and never leaves it. The "nothing stored on
/// our servers" promise is about the backend; on-device history is a feature the
/// user can clear from Settings.
public enum EditHistoryLog {

    private static let fileName = "edit-history.jsonl"

    public static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Called from the keyboard extension. Cheap and failure-tolerant: losing a
    /// history line must never disrupt typing.
    public static func append(_ record: EditRecord) {
        guard let url = fileURL,
              let data = try? encoder.encode(record),
              var line = String(data: data, encoding: .utf8)
        else { return }
        line += "\n"

        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? line.data(using: .utf8)?.write(to: url, options: .atomic)
            return
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }

    /// Called from the host app. Newest first.
    public static func readAll(limit: Int? = nil) -> [EditRecord] {
        guard let url = fileURL,
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        let records = contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { try? decoder.decode(EditRecord.self, from: Data($0.utf8)) }
            .reversed()

        guard let limit else { return Array(records) }
        return Array(records.prefix(limit))
    }

    public static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
