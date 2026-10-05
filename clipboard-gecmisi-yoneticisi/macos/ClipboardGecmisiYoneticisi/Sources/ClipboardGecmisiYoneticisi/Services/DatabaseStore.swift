import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class DatabaseStore {
    static let shared = DatabaseStore()

    private var db: OpaquePointer?

    private init() {
        AppPaths.ensureDirectories()
        openDatabase()
        initializeSchema()
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    func saveItem(type: String, content: String) {
        guard let db else { return }
        let sql = "INSERT INTO ClipboardItems (Type, Content) VALUES (?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, type, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, content, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)

        enforceLimit()
    }

    func fetchItems(search: String? = nil, limit: Int = 500) -> [ClipboardEntry] {
        guard let db else { return [] }

        let sql: String
        if let search, !search.isEmpty {
            sql = """
            SELECT Id, Type, Content, Timestamp, IsPinned FROM ClipboardItems
            WHERE Content LIKE ? ESCAPE '\\'
            ORDER BY IsPinned DESC, Timestamp DESC LIMIT ?;
            """
        } else {
            sql = """
            SELECT Id, Type, Content, Timestamp, IsPinned FROM ClipboardItems
            ORDER BY IsPinned DESC, Timestamp DESC LIMIT ?;
            """
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        if let search, !search.isEmpty {
            let pattern = "%\(search.replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_"))%"
            sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        } else {
            sqlite3_bind_int(stmt, 1, Int32(limit))
        }

        var items: [ClipboardEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let type = String(cString: sqlite3_column_text(stmt, 1))
            let content = String(cString: sqlite3_column_text(stmt, 2))
            let tsRaw = String(cString: sqlite3_column_text(stmt, 3))
            let pinned = sqlite3_column_int(stmt, 4) != 0
            let ts = ISO8601DateFormatter().date(from: tsRaw) ?? Date()

            items.append(ClipboardEntry(id: id, type: type, content: content, timestamp: ts, isPinned: pinned))
        }
        return items
    }

    func togglePin(id: Int64, pinned: Bool) {
        execute("UPDATE ClipboardItems SET IsPinned = ? WHERE Id = ?;", bind: { stmt in
            sqlite3_bind_int(stmt, 1, pinned ? 1 : 0)
            sqlite3_bind_int64(stmt, 2, id)
        })
    }

    func deleteItem(id: Int64) {
        execute("DELETE FROM ClipboardItems WHERE Id = ?;", bind: { stmt in
            sqlite3_bind_int64(stmt, 1, id)
        })
    }

    func clearHistory() {
        execute("DELETE FROM ClipboardItems;", bind: { _ in })
    }

    private func openDatabase() {
        let path = AppPaths.dbURL.path
        if sqlite3_open(path, &db) != SQLITE_OK {
            db = nil
        }
    }

    private func initializeSchema() {
        execute("PRAGMA journal_mode=WAL;", bind: { _ in })
        execute("""
            CREATE TABLE IF NOT EXISTS ClipboardItems (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                Type TEXT NOT NULL,
                Content TEXT NOT NULL,
                Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                IsPinned INTEGER DEFAULT 0
            );
            """, bind: { _ in })
    }

    private func enforceLimit() {
        let limit = SettingsStore.shared.settings.historyLimit
        execute("""
            DELETE FROM ClipboardItems WHERE Id NOT IN (
                SELECT Id FROM ClipboardItems ORDER BY IsPinned DESC, Timestamp DESC LIMIT ?
            ) AND IsPinned = 0;
            """, bind: { stmt in
            sqlite3_bind_int(stmt, 1, Int32(limit))
        })
    }

    private func execute(_ sql: String, bind: (OpaquePointer?) -> Void) {
        guard let db else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        sqlite3_step(stmt)
    }
}
