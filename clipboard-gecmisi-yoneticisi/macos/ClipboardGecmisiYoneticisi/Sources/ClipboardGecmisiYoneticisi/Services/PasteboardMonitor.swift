import AppKit
import Foundation

enum PasteboardWriter {
    static func copyToClipboard(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
}

final class PasteboardMonitor {
    var onCapture: ((String, String) -> Void)?

    private var lastChangeCount: Int
    private var timer: Timer?
    private var ignoreNext = false

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    deinit {
        timer?.invalidate()
    }

    func copyWithoutCapture(_ content: String) {
        ignoreNext = true
        PasteboardWriter.copyToClipboard(content)
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if ignoreNext {
            ignoreNext = false
            return
        }

        if shouldIgnoreFrontApp() { return }

        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], urls.count == 1 {
            onCapture?("File", urls[0].path)
            return
        }

        guard let text = pb.string(forType: .string), !text.isEmpty else { return }
        let type = ContentClassifier.classify(text) == .plain ? "Text" : "Text"
        onCapture?(type, text)
    }

    private func shouldIgnoreFrontApp() -> Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return SettingsStore.shared.settings.excludedBundleIds.contains(where: { bundleId.localizedCaseInsensitiveContains($0) })
    }
}
