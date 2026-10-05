import SwiftUI

@main
struct ClipboardGecmisiYoneticisiApp: App {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some Scene {
        MenuBarExtra {
            HistoryPanelView()
                .environmentObject(viewModel)
                .frame(width: 380, height: 520)
        } label: {
            Image(systemName: viewModel.history.isEmpty ? "doc.on.clipboard" : "doc.on.clipboard.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}
