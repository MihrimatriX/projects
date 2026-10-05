import SwiftUI

struct SettingsView: View {
    @AppStorage("runAtLogin") private var runAtLogin = false

    var body: some View {
        Form {
            Section("Başlangıç") {
                Toggle("Oturum açılışında başlat", isOn: $runAtLogin)
                    .onChange(of: runAtLogin) { enabled in
                        LaunchAtLoginService.setEnabled(enabled)
                    }
            }
            Section("Hakkında") {
                Text("Sistem Yöneticisi Paketi — macOS")
                Text("Yerel sistem monitörü, telemetri yok.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 260)
        .onAppear {
            runAtLogin = LaunchAtLoginService.isEnabled
        }
    }
}
