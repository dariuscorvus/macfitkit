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
                result = "FAIL: Test settings did not become active/key. Active=\(app.isActive), key=\(app.keyWindow?.title ?? "nil"), foreground=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")."
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
                check(overlay.frame == EffectGeometry.alignedOverlayRect(for: window.frame, appearance: store.value.appearance), "Initial frame mismatch")
                store.value.appearance.width = 8
                store.value.appearance.gap = 5
                check(overlay.frame == EffectGeometry.alignedOverlayRect(for: window.frame, appearance: store.value.appearance), "Appearance did not update live")
                store.value.appearance.opacityAnimation.mode = .pulse
                store.value.appearance.opacityAnimation.trigger = .continuous
                let canvas = overlay.contentView as! EffectCanvas
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    check((canvas.renderer.root.animationKeys() ?? []).isEmpty, "Reduced-motion settings animated")
                } else {
                    check(!(canvas.renderer.root.animationKeys() ?? []).isEmpty, "Settings animation not running")
                }
                // Material and placement changes use the same live renderer.
                store.value.appearance.opacityAnimation.mode = .off
                store.value.appearance.material.mode = .gold
                store.value.appearance.material.reflectionEnabled = true
                store.value.appearance.material.trigger = .continuous
                func animationKeys(in layer: CALayer) -> [String] {
                    (layer.animationKeys() ?? []) + (layer.sublayers ?? []).flatMap { animationKeys(in: $0) }
                }
                let metalKeys = animationKeys(in: canvas.renderer.root)
                check(metalKeys.contains("metalReflection") != NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, "Metal reflection motion policy incorrect")
                for placement in BorderPlacement.allCases {
                    store.value.appearance.placement = placement
                    check(overlay.frame == EffectGeometry.alignedOverlayRect(for: window.frame, appearance: store.value.appearance), "Placement update did not follow window")
                }
                store.value.appearance.material.mode = .chrome
                check(PreferencesStore(defaults: defaults).value.appearance == store.value.appearance, "Metal/placement values not persisted")
                store.value.appearance.material.trigger = .focus
                check(!animationKeys(in: canvas.renderer.root).contains("metalReflection"), "Focus reflection started on a settings update")
                manager.testSettingsFocusAnimation()
                func reflection(in layer: CALayer) -> CAAnimation? {
                    layer.animation(forKey: "metalReflection") ?? (layer.sublayers ?? []).compactMap { reflection(in: $0) }.first
                }
                if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    let before = reflection(in: canvas.renderer.root)!
                    check(before.duration == store.value.appearance.material.focusDuration && before.repeatCount == 0,
                          "Focus reflection did not use one bounded sweep")
                    window.setFrameOrigin(window.frame.origin.applying(CGAffineTransform(translationX: 10,y: -10)))
                    check(reflection(in: canvas.renderer.root)?.beginTime == before.beginTime, "Move restarted focus reflection")
                }
                manager.enabled = false
                check(!overlay.isVisible, "Paused settings frame remained visible")
                check(animationKeys(in: canvas.renderer.root).isEmpty, "Paused settings animation remained active")
                manager.enabled = true
                check(overlay.isVisible, "Settings frame did not resume")
                // Own NSWindow changes synchronously deliver local geometry notifications.
                let moved = window.frame.offsetBy(dx: 40, dy: -25)
                window.setFrameOrigin(moved.origin)
                check(overlay.frame == EffectGeometry.alignedOverlayRect(for: window.frame, appearance: store.value.appearance), "Move did not follow local window")
                window.setFrame(NSRect(origin: window.frame.origin, size: NSSize(width: 980, height: 730)), display: true)
                check(overlay.frame == EffectGeometry.alignedOverlayRect(for: window.frame, appearance: store.value.appearance), "Resize did not follow local window")
                check(overlay.ignoresMouseEvents && !overlay.canBecomeKey, "Overlay intercepted input/focus")
                canvas.renderer.setVisible(false)
                check(animationKeys(in: canvas.renderer.root).isEmpty, "Hidden metal reflection remained active")
                canvas.renderer.motionPreferenceChanged()
                check(animationKeys(in: canvas.renderer.root).isEmpty, "Hidden renderer restarted on motion preference change")
                manager.stop()
                check(!overlay.isVisible && animationKeys(in: canvas.renderer.root).isEmpty, "Stopped settings frame/animation remained active")
                if let navigation = tables(in: window.contentView!).first(where: { $0.numberOfRows == 7 }) {
                    navigation.selectRowIndexes(IndexSet(integer: 4), byExtendingSelection: false)
                    window.contentView?.layoutSubtreeIfNeeded()
                    let controls = descendants(in: window.contentView!)
                    let preset = controls.compactMap { $0 as? NSButton }.first { $0.title == "Lichtläufer" }
                    preset?.performClick(nil); window.contentView?.layoutSubtreeIfNeeded()
                    check(store.value.appearance.motion.mode == .runner, "Runner preset did not apply")
                    controls.compactMap { $0 as? NSButton }.first { $0.title == "Animation abspielen" }?.performClick(nil)
                    let preview = controls.compactMap { $0 as? EffectCanvas }.first
                    check(preview != nil, "Animation preview missing")
                    if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let preview {
                        check(animationKeys(in: preview.renderer.root).contains("motionRunner"), "Preview did not play runner")
                    }
                    navigation.selectRowIndexes(IndexSet(integer: 5), byExtendingSelection: false)
                    if let preview { check(animationKeys(in: preview.renderer.root).isEmpty, "Detached preview kept animating") }
                }
                result = failures.isEmpty ? "PASS: Seven sidebar sections, numeric inputs, persistence, validation, live settings frame, appearance, metals, focus sweep without movement restart, animation, pause/resume, move, resize, input transparency and stop." : "FAIL: " + failures.joined(separator: "; ")
            } else { result = "FAIL: Overlay or settings window missing." }
            defaults.removePersistentDomain(forName: suite)
            try! result.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
            app.terminate(nil)
        }
        app.run()
    }
}
