import Foundation

struct AppSettings: Codable {
    var historyLimit: Int = 500
    var showHotkeyEnabled: Bool = true
    var excludedBundleIds: [String] = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop"
    ]
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var settings: AppSettings

    private init() {
        AppPaths.ensureDirectories()
        if let data = try? Data(contentsOf: AppPaths.settingsURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: AppPaths.settingsURL, options: .atomic)
    }
}
