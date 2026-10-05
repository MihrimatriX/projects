import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsStore = SettingsStore.shared

    var body: some View {
        Form {
            Section("Geçmiş") {
                Stepper(
                    "Limit: \(settingsStore.settings.historyLimit) öğe",
                    value: $settingsStore.settings.historyLimit,
                    in: 50...2000,
                    step: 50
                )
                .onChange(of: settingsStore.settings.historyLimit) { _ in settingsStore.save() }
            }

            Section("Güvenlik") {
                Text("Hariç tutulan uygulama bundle ID'leri (satır başına bir)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: Binding(
                    get: { settingsStore.settings.excludedBundleIds.joined(separator: "\n") },
                    set: {
                        settingsStore.settings.excludedBundleIds = $0
                            .split(separator: "\n")
                            .map { String($0).trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        settingsStore.save()
                    }
                ))
                .frame(height: 80)
            }

            Section("Kısayol") {
                Toggle("⌘⇧V global kısayol", isOn: $settingsStore.settings.showHotkeyEnabled)
                    .onChange(of: settingsStore.settings.showHotkeyEnabled) { enabled in
                        settingsStore.save()
                        if enabled {
                            HotkeyService.shared.register {
                                Task { @MainActor in
                                    NSApp.activate(ignoringOtherApps: true)
                                }
                            }
                        } else {
                            HotkeyService.shared.unregister()
                        }
                    }
            }

            Section("Hakkında") {
                Text("Clipboard Geçmişi Yöneticisi — macOS v1.2")
                Text("Veriler yalnızca yerel olarak saklanır.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
    }
}
