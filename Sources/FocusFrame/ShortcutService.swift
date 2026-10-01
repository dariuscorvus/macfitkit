import AppKit
import Carbon

@MainActor
final class ShortcutService {
    var onPress: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let signature: OSType = 0x4646524D // FFRM

    func setEnabled(_ enabled: Bool) throws {
        if !enabled { stop(); return }
        if hotKey != nil { return }
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let install = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let service = Unmanaged<ShortcutService>.fromOpaque(context).takeUnretainedValue()
                var identifier = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr,
                      identifier.signature == service.signature, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
                service.onPress?()
                return noErr
            }
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard install == noErr else { throw failure(install) }
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_F), UInt32(controlKey | optionKey),
            EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { stop(); throw failure(result) }
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }
    private func failure(_ status: OSStatus) -> NSError {
        NSError(domain: "FocusFrame.Shortcut", code: Int(status), userInfo: [NSLocalizedDescriptionKey:
            "Das Tastenkürzel konnte nicht aktiviert werden. Es kann bereits von einer anderen App verwendet werden. (\(status))"])
    }
}
