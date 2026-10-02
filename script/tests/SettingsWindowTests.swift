import AppKit
import FocusFrameCore

@main
struct SettingsWindowTests {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let suite = "FocusFrame.SettingsProbe.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = PreferencesStore(defaults: defaults)
        let settings = SettingsWindowController(store: store)
        let manager = FocusManager()
        manager.configuration = store.value
        manager.settingsWindow = settings.window
        settings.onTestFocus = { manager.testSettingsFocusAnimation() }
        store.onChange = { manager.configuration = store.value }
        manager.start()
        settings.present()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let result: String
            if !app.isActive || app.keyWindow !== settings.window {
                result = "FAIL: Test settings did not become active/key."
            } else if let overlay = app.windows.first(where: { $0 is OverlayWindow }) as? OverlayWindow,
                      let window = settings.window {
                var failures: [String] = []
                func check(_ condition: Bool, _ message: String) { if !condition { failures.append(message) } }
                func tables(in view: NSView) -> [NSTableView] {
                    (view as? NSTableView).map { [$0] } ?? view.subviews.flatMap { tables(in: $0) }
                }
                func descendants(in view: NSView) -> [NSView] {
                    [view] + view.subviews.flatMap { descendants(in: $0) }
                }
                if let navigation = tables(in: window.contentView!).first(where: { $0.numberOfRows == 7 }) {
                    let initialFrame = window.frame
                    for row in 0..<7 {
                        navigation.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                        window.contentView?.layoutSubtreeIfNeeded()
                        let controls = descendants(in: window.contentView!)
                        let sliders = controls.compactMap { $0 as? NSSlider }
                        let inputs = controls.compactMap { $0 as? NSTextField }.filter { $0.isEditable }
                        check(sliders.count == inputs.count, "Section \(row) lacks numeric inputs for its sliders")
                        check(window.frame == initialFrame, "Selecting section \(row) changed window size")
                    }
                    navigation.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    if let width = descendants(in: window.contentView!).compactMap({ $0 as? NSTextField })
                        .first(where: { $0.identifier?.rawValue == "Stärke" && $0.isEditable }) {
                        func enter(_ text: String) {
                            width.stringValue = text
                            settings.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: width))
                        }
                        enter("64,5")
                        check(store.value.appearance.width == 64.5, "Decimal comma was not accepted")
                        check(PreferencesStore(defaults: defaults).value.appearance.width == 64.5, "Numeric input was not saved")
                        enter("invalid")
                        check(store.value.appearance.width == 64.5 && width.stringValue != "invalid", "Invalid input did not restore saved value")
                        enter("2000")
                        check(store.value.appearance.width == 100, "Numeric input exceeded its limit")
                        enter("8.25")
                        check(store.value.appearance.width == 8.25, "Decimal point was not accepted")
                        enter("8")
                    } else { failures.append("Width input missing") }
                } else { failures.append("Seven-section sidebar missing") }
                check(overlay.isVisible, "No live settings frame")
                check(overlay.frame == EffectGeometry.overlayRect(for: window.frame, appearance: store.value.appearance), "Initial frame mismatch")
                store.value.appearance.width = 8
                store.value.appearance.gap = 5
                check(overlay.frame == EffectGeometry.overlayRect(for: window.frame, appearance: store.value.appearance), "Appearance did not update live")
                store.value.appearance.opacityAnimation.mode = .pulse
                store.value.appearance.opacityAnimation.trigger = .continuous
                let canvas = overlay.contentView as! EffectCanvas
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    check((canvas.renderer.root.animationKeys() ?? []).isEmpty, "Reduced-motion settings animated")
                } else {
                    check(!(canvas.renderer.root.animationKeys() ?? []).isEmpty, "Settings animation not running")
                }
                manager.enabled = false
                check(!overlay.isVisible, "Paused settings frame remained visible")
                check((canvas.renderer.root.animationKeys() ?? []).isEmpty, "Paused settings animation remained active")
                manager.enabled = true
                check(overlay.isVisible, "Settings frame did not resume")
                // Own NSWindow changes synchronously deliver local geometry notifications.
                let moved = window.frame.offsetBy(dx: 40, dy: -25)
                window.setFrameOrigin(moved.origin)
                check(overlay.frame == EffectGeometry.overlayRect(for: window.frame, appearance: store.value.appearance), "Move did not follow local window")
                window.setFrame(NSRect(origin: window.frame.origin, size: NSSize(width: 980, height: 730)), display: true)
                check(overlay.frame == EffectGeometry.overlayRect(for: window.frame, appearance: store.value.appearance), "Resize did not follow local window")
                check(overlay.ignoresMouseEvents && !overlay.canBecomeKey, "Overlay intercepted input/focus")
                manager.stop()
                check(!overlay.isVisible && (canvas.renderer.root.animationKeys() ?? []).isEmpty, "Stopped settings frame/animation remained active")
                result = failures.isEmpty ? "PASS: Seven sidebar sections, numeric inputs, persistence, validation, live settings frame, appearance, animation, pause/resume, move, resize, input transparency and stop." : "FAIL: " + failures.joined(separator: "; ")
            } else { result = "FAIL: Overlay or settings window missing." }
            defaults.removePersistentDomain(forName: suite)
            try! result.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
            app.terminate(nil)
        }
        app.run()
    }
}
