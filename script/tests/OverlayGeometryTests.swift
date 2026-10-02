import AppKit
import QuartzCore
import FocusFrameCore

/// Runs in a desktop session against the actual overlay, without AX access.
@main
struct OverlayGeometryTests {
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        guard !NSScreen.screens.isEmpty else { fatalError("A desktop session is required") }
        verifyPixels()
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
        var metalCombined = expandedLimits; metalCombined.material.mode = .gold; metalCombined.material.reflectionEnabled = true
        var chromeCombined = metalCombined; chromeCombined.material.mode = .chrome
        let styles = [Appearance(), glow, neon, shadow, negativeShadow, combined, wideFrame, wideCombined, expandedLimits, metalCombined, chromeCombined]
        var checks = 0
        for screen in NSScreen.screens {
            for placement in BorderPlacement.allCases {
              for initialStyle in styles {
                var style = initialStyle; style.placement = placement
                for top in [screen.visibleFrame.maxY, screen.frame.maxY, screen.frame.maxY + 300] {
                    // Above/left positions also exercise unrestricted screen coordinates.
                    for x in [screen.frame.minX + 100, screen.frame.minX - 700] {
                        var target = CGRect(x: x, y: top - 420, width: 600, height: 420)
                        for step in 0..<4 {
                            if step == 1 { target = target.offsetBy(dx: 30, dy: 1) }
                            if step == 2 { target.size.height += 50 }
                            if step == 3 { target = target.offsetBy(dx: 0.25, dy: 0.75) }
                            let canvas = overlay.contentView as! EffectCanvas
                            let previousMask = canvas.renderer.root.sublayers?.dropFirst().first?.mask
                            overlay.show(around: target, appearance: style, focusChanged: step == 1)
                            let expected = EffectGeometry.alignedOverlayRect(for: target, appearance: style)
                            guard overlay.frame == expected else {
                                print("FAIL: Overlay shifted: requested \(expected), actual \(overlay.frame)")
                                exit(1)
                            }
                            let root = (overlay.contentView as! EffectCanvas).renderer.root
                            let mask = root.sublayers![1].mask as! CAShapeLayer
                            if step == 1 || step == 3 { precondition(mask === previousMask, "Move rebuilt contour layers") }
                            let painted = mask.path!.boundingBoxOfPath.applying(root.affineTransform())
                                .offsetBy(dx: overlay.frame.minX,dy: overlay.frame.minY)
                            let requested = EffectGeometry.contour(for: target, appearance: style).outerRect
                            precondition(abs(painted.minX-requested.minX) < 0.001 && abs(painted.minY-requested.minY) < 0.001 &&
                                         abs(painted.width-requested.width) < 0.001 && abs(painted.height-requested.height) < 0.001,
                                         "Actual renderer contour moved away from the target")
                            precondition(overlay.ignoresMouseEvents && !overlay.canBecomeKey && !overlay.canBecomeMain)
                            checks += 1
                        }
                        overlay.orderOut(nil)
                    }
                }
              }
            }
        }
        print("Passed \(checks) actual AppKit overlay frame checks (initial display, same-size focus switch, resize, screen edges, maximal effects).")
    }
    /// Exercises the actual layer tree in a transparent bitmap, not just its bounds.
    @MainActor private static func verifyPixels() {
        let w = 480, h = 300
        let target = CGRect(x: 100,y: 60,width: 280,height: 180)
        for material in FrameMaterial.allCases {
            for placement in BorderPlacement.allCases {
                var a = Appearance(); a.width = 20; a.material.mode = material; a.placement = placement
                let renderer = EffectRenderer()
                var pixels = [UInt8](repeating: 0,count: w*h*4)
                pixels.withUnsafeMutableBytes { data in
                    let context = CGContext(data: data.baseAddress,width: w,height: h,bitsPerComponent: 8,bytesPerRow: w*4,
                        space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
                    renderer.update(bounds: CGRect(x: 0,y: 0,width: w,height: h),target: target,style: a,scale: 1)
                    renderer.root.render(in: context)
                    if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--snapshot-dir" {
                        let image = NSBitmapImageRep(cgImage: context.makeImage()!)
                        let directory = URL(fileURLWithPath: CommandLine.arguments[2])
                        try! FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
                        try! image.representation(using: .png,properties: [:])!.write(to: directory.appendingPathComponent("\(material.rawValue)-\(placement.rawValue).png"))
                    }
                }
                func alpha(_ x: Int,_ y: Int) -> UInt8 { pixels[(y*w+x)*4+3] }
                let sample = placement == .outside ? 90 : (placement == .centered ? 100 : 110)
                precondition(alpha(sample,150) > 240, "Missing painted border: \(material)/\(placement)")
                precondition(alpha(240,150) == 0, "Window center is not transparent")
                precondition(alpha(60,150) == 0, "Border leaked outside its ring")
                if placement == .inside { precondition(alpha(90,150) == 0, "Inside border painted outside") }
                if placement == .outside { precondition(alpha(110,150) == 0, "Outside border painted inside") }
                let color = (150*w+sample)*4
                if material == .gold { precondition(pixels[color] > pixels[color+2], "Gold palette missing") }
                if material == .chrome { precondition(pixels[color+2] >= pixels[color], "Chrome palette missing") }
            }
        }
        print("Passed 9 native renderer pixel checks (placement, gold/chrome, transparent center and contour clipping).")
    }

}
