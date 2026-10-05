import SwiftUI

public struct ContentView: View {
    @EnvironmentObject private var metrics: MetricsViewModel

    public init() {}

    public var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Gösterge", systemImage: "gauge") }
            ProcessListView()
                .tabItem { Label("Süreçler", systemImage: "cpu") }
            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
        }
        .onAppear { metrics.start() }
        .onDisappear { metrics.stop() }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var metrics: MetricsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    metricCard(title: "CPU", value: String(format: "%.0f%%", metrics.cpuPercent), color: .blue)
                    metricCard(title: "RAM", value: String(format: "%.0f%%", metrics.ramPercent), color: .purple)
                    metricCard(title: "Bellek", value: String(format: "%.1f / %.1f GB", metrics.ramUsedGb, metrics.ramTotalGb), color: .green)
                }
                Text("Disk Sürücüleri").font(.headline)
                ForEach(metrics.disks) { disk in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(disk.name)
                            Spacer()
                            Text(String(format: "%.0f%%", disk.percent))
                        }
                        ProgressView(value: disk.percent, total: 100)
                    }
                }
            }
            .padding()
        }
    }

    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

struct ProcessListView: View {
    @EnvironmentObject private var metrics: MetricsViewModel

    var body: some View {
        List(metrics.processes) { proc in
            HStack {
                Text("\(proc.id)").frame(width: 60, alignment: .trailing).foregroundStyle(.secondary)
                Text(proc.name)
                Spacer()
            }
        }
    }
}
