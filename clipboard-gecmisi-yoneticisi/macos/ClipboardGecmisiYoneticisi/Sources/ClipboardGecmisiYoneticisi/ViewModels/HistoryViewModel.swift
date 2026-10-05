import AppKit
import Combine
import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var history: [ClipboardEntry] = []
    @Published var searchText = ""
    @Published var selectedEntry: ClipboardEntry?

    private let database = DatabaseStore.shared
    private let monitor = PasteboardMonitor()
    private var panelController: NSPanel?

    init() {
        monitor.onCapture = { [weak self] type, content in
            Task { @MainActor in
                self?.database.saveItem(type: type, content: content)
                self?.reload()
            }
        }

        if SettingsStore.shared.settings.showHotkeyEnabled {
            HotkeyService.shared.register { [weak self] in
                Task { @MainActor in self?.togglePanel() }
            }
        }

        reload()
    }

    func reload() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        history = database.fetchItems(search: query.isEmpty ? nil : query)
    }

    func copyEntry(_ entry: ClipboardEntry) {
        monitor.copyWithoutCapture(entry.content)
        database.saveItem(type: entry.type, content: entry.content)
        reload()
        NSApp.hide(nil)
    }

    func togglePin(_ entry: ClipboardEntry) {
        database.togglePin(id: entry.id, pinned: !entry.isPinned)
        reload()
    }

    func deleteEntry(_ entry: ClipboardEntry) {
        database.deleteItem(id: entry.id)
        reload()
    }

    func clearAll() {
        database.clearHistory()
        reload()
    }

    func togglePanel() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
