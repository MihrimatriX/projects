import Foundation

enum AppPaths {
    static var dataFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("ClipboardGecmisiYoneticisi", isDirectory: true)
    }

    static var dbURL: URL { dataFolder.appendingPathComponent("clipboard.db") }
    static var settingsURL: URL { dataFolder.appendingPathComponent("settings.json") }

    static func ensureDirectories() {
        try? FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true)
    }
}
