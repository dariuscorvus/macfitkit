import AppKit
import Carbon

@MainActor
final class ShortcutService {
    var onPress: (() -> Void)?
    var isEnabled: Bool { hotKey != nil }
    private var hotKey: EventHotKeyRef?
    private var registeredKey: UInt32?
    private var registeredModifiers: UInt32?
    private var handler: EventHandlerRef?
    private let signature: OSType = 0x4646524D // FFRM

    func setEnabled(_ enabled: Bool, keyCode: UInt32 = 3, modifiers: UInt32 = 6144) throws {
        if !enabled { stop(); return }
        if hotKey != nil && registeredKey == keyCode && registeredModifiers == modifiers { return }
        stop()
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
        let result = RegisterEventHotKey(keyCode, modifiers,
            EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { stop(); throw failure(result) }
        registeredKey = keyCode; registeredModifiers = modifiers
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        registeredKey = nil; registeredModifiers = nil
        hotKey = nil
        handler = nil
    }
    private func failure(_ status: OSStatus) -> NSError {
        NSError(domain: "FocusFrame.Shortcut", code: Int(status), userInfo: [NSLocalizedDescriptionKey:
            "Das Tastenkürzel konnte nicht aktiviert werden. Es kann bereits von einer anderen App verwendet werden. (\(status))"])
    }
}
