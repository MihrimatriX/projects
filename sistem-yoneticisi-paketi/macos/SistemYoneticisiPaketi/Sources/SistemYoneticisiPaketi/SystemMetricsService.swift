import AppKit
import Foundation

@MainActor
public final class MetricsViewModel: ObservableObject {
    public init() {}

    @Published var cpuPercent: Double = 0
    @Published var ramPercent: Double = 0
    @Published var ramUsedGb: Double = 0
    @Published var ramTotalGb: Double = 0
    @Published var disks: [DiskInfo] = []
    @Published var processes: [ProcessRow] = []

    private let service = SystemMetricsService()
    private var timer: Timer?

    func start() {
        stop() // ikinci pencere onAppear'ı eski zamanlayıcıyı sızdırmasın
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let snap = service.snapshot()
        cpuPercent = snap.cpuPercent
        ramPercent = snap.ramPercent
        ramUsedGb = snap.ramUsedGb
        ramTotalGb = snap.ramTotalGb
        disks = snap.disks
        processes = snap.processes
    }
}

struct DiskInfo: Identifiable {
    let id: String
    let name: String
    let usedGb: Double
    let totalGb: Double
    var percent: Double { totalGb > 0 ? (usedGb / totalGb) * 100 : 0 }
}

struct ProcessRow: Identifiable {
    let id: Int
    let name: String
    let cpu: Double
    let memoryMb: Double
}

struct MetricsSnapshot {
    var cpuPercent: Double = 0
    var ramPercent: Double = 0
    var ramUsedGb: Double = 0
    var ramTotalGb: Double = 0
    var disks: [DiskInfo] = []
    var processes: [ProcessRow] = []
}

final class SystemMetricsService {
    private var prevBusy: Double = 0
    private var prevTotal: Double = 0

    func snapshot() -> MetricsSnapshot {
        var snap = MetricsSnapshot()
        snap.cpuPercent = readCpuPercent()
        let mem = readMemory()
        snap.ramPercent = mem.percent
        snap.ramUsedGb = mem.usedGb
        snap.ramTotalGb = mem.totalGb
        snap.disks = readDisks()
        snap.processes = readProcesses(limit: 40)
        return snap
    }

    private func readCpuPercent() -> Double {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        // cpu_ticks açılıştan beri birikimli sayaçlardır (user, system, idle, nice);
        // anlık kullanım için iki örnek arasındaki fark alınır.
        let busy = Double(load.cpu_ticks.0) + Double(load.cpu_ticks.1) + Double(load.cpu_ticks.3)
        let total = busy + Double(load.cpu_ticks.2)
        let dBusy = busy - prevBusy
        let dTotal = total - prevTotal
        prevBusy = busy
        prevTotal = total
        return dTotal > 0 ? (dBusy / dTotal) * 100 : 0
    }

    private func readMemory() -> (percent: Double, usedGb: Double, totalGb: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0, 0) }
        let pageSize = Double(vm_kernel_page_size)
        let totalPages = Double(stats.active_count + stats.inactive_count + stats.wire_count + stats.free_count)
        let usedPages = Double(stats.active_count + stats.wire_count)
        let totalBytes = totalPages * pageSize
        let usedBytes = usedPages * pageSize
        let totalGb = totalBytes / 1_073_741_824
        let usedGb = usedBytes / 1_073_741_824
        let percent = totalGb > 0 ? (usedGb / totalGb) * 100 : 0
        return (percent, usedGb, totalGb)
    }

    private func readDisks() -> [DiskInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let total = values.volumeTotalCapacity,
                  let avail = values.volumeAvailableCapacity else { return nil }
            let totalGb = Double(total) / 1_073_741_824
            let freeGb = Double(avail) / 1_073_741_824
            let usedGb = max(0, totalGb - freeGb)
            let name = values.volumeName ?? url.path
            return DiskInfo(id: url.path, name: name, usedGb: usedGb, totalGb: totalGb)
        }
    }

    private func readProcesses(limit: Int) -> [ProcessRow] {
        let apps = NSWorkspace.shared.runningApplications
        var rows: [ProcessRow] = apps.prefix(limit).map { app in
            ProcessRow(
                id: Int(app.processIdentifier),
                name: app.localizedName ?? "?",
                cpu: 0,
                memoryMb: 0
            )
        }
        rows.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return rows
    }
}
