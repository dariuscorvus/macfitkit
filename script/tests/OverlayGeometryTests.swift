import AppKit
import FocusFrameCore

/// Runs in a desktop session against the actual overlay, without AX access.
@main
struct OverlayGeometryTests {
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        guard !NSScreen.screens.isEmpty else { fatalError("A desktop session is required") }
        let overlay = OverlayWindow()
        var glow = Appearance()
        glow.light.mode = .glow
        glow.light.extent = 40
        var neon = glow
        neon.light.mode = .neon
        var shadow = Appearance()
        shadow.shadow.enabled = true
        shadow.shadow.blur = 40
        shadow.shadow.spread = 20
        shadow.shadow.offsetX = 40
        shadow.shadow.offsetY = -40
        var negativeShadow = shadow
        negativeShadow.shadow.offsetX = -40
        negativeShadow.shadow.offsetY = 40
        var combined = shadow
        combined.light = neon.light
        var wideFrame = Appearance()
        wideFrame.width = 12
        wideFrame.gap = 20
        wideFrame.radius = 26.6
        var wideCombined = combined
        wideCombined.width = wideFrame.width
        wideCombined.gap = wideFrame.gap
        wideCombined.radius = wideFrame.radius
        var expandedLimits = wideCombined
        expandedLimits.width = 100; expandedLimits.gap = 200; expandedLimits.radius = 300
        expandedLimits.light.extent = 200
        expandedLimits.shadow.blur = 200; expandedLimits.shadow.spread = 200
        expandedLimits.shadow.offsetX = -200; expandedLimits.shadow.offsetY = 200
        let styles = [Appearance(), glow, neon, shadow, negativeShadow, combined, wideFrame, wideCombined, expandedLimits]
        var checks = 0
        for screen in NSScreen.screens {
            for style in styles {
                for top in [screen.visibleFrame.maxY, screen.frame.maxY, screen.frame.maxY + 300] {
                    // Above/left positions also exercise unrestricted screen coordinates.
                    for x in [screen.frame.minX + 100, screen.frame.minX - 700] {
                        var target = CGRect(x: x, y: top - 420, width: 600, height: 420)
                        for step in 0..<3 {
                            if step == 1 { target = target.offsetBy(dx: 30, dy: 1) }
                            if step == 2 { target.size.height += 50 }
                            overlay.show(around: target, appearance: style, focusChanged: step == 1)
                            let expected = EffectGeometry.overlayRect(for: target, appearance: style)
                            guard overlay.frame == expected else {
                                print("FAIL: Overlay shifted: requested \(expected), actual \(overlay.frame)")
                                exit(1)
                            }
                            precondition(overlay.ignoresMouseEvents && !overlay.canBecomeKey && !overlay.canBecomeMain)
                            checks += 1
                        }
                        overlay.orderOut(nil)
                    }
                }
            }
        }
        print("Passed \(checks) actual AppKit overlay frame checks (initial display, same-size focus switch, resize, screen edges, maximal effects).")
    }
}
