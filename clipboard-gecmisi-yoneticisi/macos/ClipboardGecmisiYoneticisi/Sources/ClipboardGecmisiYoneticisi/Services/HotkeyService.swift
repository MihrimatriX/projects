import Carbon
import AppKit

final class HotkeyService {
    static let shared = HotkeyService()

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventHandler: EventHandlerRef?

    private init() {}

    func register(onTrigger: @escaping () -> Void) {
        handler = onTrigger
        unregister()

        var hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1)
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 9 // V

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { service.handler?() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}
