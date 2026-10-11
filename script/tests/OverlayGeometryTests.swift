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
        verifyNewEffects()
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
                            let previousMask = canvas.renderer.root.sublayers?.dropFirst().first?.sublayers?.first?.mask
                            overlay.show(around: target, appearance: style, focusChanged: step == 1)
                            let expected = EffectGeometry.alignedOverlayRect(for: target, appearance: style)
                            guard overlay.frame == expected else {
                                print("FAIL: Overlay shifted: requested \(expected), actual \(overlay.frame)")
                                exit(1)
                            }
                            let root = (overlay.contentView as! EffectCanvas).renderer.root
                            let mask = root.sublayers![1].sublayers!.first!.mask as! CAShapeLayer
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
    @MainActor private static func verifyNewEffects() {
        let size = 300, target = CGRect(x: 100,y: 100,width: 100,height: 100)
        func nodes(_ root: CALayer) -> [CALayer] { [root] + (root.sublayers ?? []).flatMap(nodes) + (root.mask.map { nodes($0) } ?? []) }
        func render(_ style: Appearance) -> [UInt8] {
            let renderer = EffectRenderer(); var pixels = [UInt8](repeating: 0,count: size*size*4)
            pixels.withUnsafeMutableBytes { data in
                let context = CGContext(data: data.baseAddress,width: size,height: size,bitsPerComponent: 8,bytesPerRow: size*4,
                    space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
                renderer.update(bounds: CGRect(x: 0,y: 0,width: size,height: size),target: target,style: style,scale: 1)
                renderer.root.render(in: context)
            }
            return pixels
        }
        var a = Appearance(); a.width = 10; a.shadow.enabled = true; a.shadow.colorSource = .gradient
        a.shadow.blur = 4; a.shadow.spread = 8; a.shadow.offsetY = 0; a.shadow.opacity = 0.8
        a.gradient.mode = .linear; a.gradient.first = EffectColor(1,0,0); a.gradient.second = EffectColor(0,0,1)
        let pixels = render(a); let left = (150*size+86)*4, right = (150*size+214)*4
        precondition(pixels[left+3] > 10 && pixels[right+3] > 10, "Gradient shadow missing")
        precondition(pixels[left] > pixels[left+2] && pixels[right+2] > pixels[right], "Gradient shadow lost spatial colors")
        precondition(pixels[(150*size+150)*4+3] == 0, "Gradient shadow covers window contents")
        a.shadow.colorSource = .frame; a.red = 0; a.green = 1; a.blue = 0
        // CALayer.render does not rasterize native shadow properties; inspect the
        // actual layer color here, while the gradient mask is pixel-checked above.
        let solid = EffectRenderer(); solid.update(bounds: CGRect(x: 0,y: 0,width: size,height: size),target: target,style: a,scale: 1)
        let inherited = nodes(solid.root).first { $0.shadowPath != nil }!.shadowColor!
        precondition(NSColor(cgColor: inherited)!.greenComponent == 1 && NSColor(cgColor: inherited)!.redComponent == 0, "Frame-color shadow not inherited")
        a.shadow.colorSource = .gradient; a.rotation.enabled = true; a.rotation.trigger = .continuous
        let renderer = EffectRenderer(); renderer.update(bounds: CGRect(x: 0,y: 0,width: size,height: size),target: target,style: a,scale: 1)
        renderer.setVisible(true,focusChanged: true)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let rotations = nodes(renderer.root).compactMap { $0.animation(forKey: "rotationEffect") }
            precondition(rotations.count == 2 && rotations[0].beginTime == rotations[1].beginTime, "Shadow rotation not synchronized")
        }
        for mode in [MotionMode.impulse,.runner,.draw,.breathe,.flow] {
            a.rotation.enabled = false; a.motion.mode = mode; a.motion.target = .shadow; a.motion.cycles = 2
            renderer.update(bounds: CGRect(x: 0,y: 0,width: size,height: size),target: target,style: a,scale: 1)
            renderer.setVisible(true,focusChanged: true)
            let layers = nodes(renderer.root), animated = layers.flatMap { $0.animationKeys() ?? [] }
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { precondition(animated.isEmpty) }
            else {
                precondition(!animated.isEmpty, "Missing motion: \(mode)")
                let motion = layers.compactMap { $0.animation(forKey: animated[0]) }.first!
                precondition(motion.repeatCount == 1 && motion.duration == a.motion.duration, "Finite repetition/duration incorrect")
                if mode == .flow {
                    let flows = layers.compactMap { $0.animation(forKey: "motionFlow") }
                    precondition(flows.count == 2 && flows[0].beginTime == flows[1].beginTime, "Frame/shadow color flow not synchronized")
                }
                if mode == .draw { precondition(animated.contains("motionTrace"), "Draw does not reveal actual border") }
                if mode == .breathe { precondition(animated.contains("motionTightShadow"), "Gradient shadow has no compact phase") }
                let before = layers.compactMap { $0.animation(forKey: animated[0]) }.first!.beginTime
                renderer.update(bounds: CGRect(x: 0,y: 0,width: 340,height: size),target: target.insetBy(dx: -10,dy: 0),style: a,scale: 1)
                renderer.setVisible(true,focusChanged: false)
                let after = nodes(renderer.root).compactMap { $0.animation(forKey: animated[0]) }.first!.beginTime
                precondition(before == after, "Resize restarted animation")
            }
            renderer.setVisible(false)
            precondition(nodes(renderer.root).allSatisfy { ($0.animationKeys() ?? []).isEmpty }, "Hidden motion still running")
        }
        a.motion.mode = .off; a.opacityAnimation.mode = .pulse; a.opacityAnimation.target = .shadow; a.opacityAnimation.trigger = .continuous
        renderer.update(bounds: CGRect(x: 0,y: 0,width: size,height: size),target: target,style: a,scale: 1); renderer.setVisible(true)
        precondition(renderer.root.animation(forKey: "opacityEffect") == nil, "Targeted shadow animation pulses whole frame")
        print("Passed gradient-shadow colors/transparency, inherited color, synchronized rotation, five motion modes, resize phase, hidden cleanup and independent shadow opacity checks.")
    }
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
