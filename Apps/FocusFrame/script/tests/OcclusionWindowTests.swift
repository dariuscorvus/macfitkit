import AppKit
import FocusFrameCore

@main struct OcclusionWindowTests {
    @MainActor static func pump(_ seconds: Double = 0.15) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let rect = CGRect(x: 200, y: 200, width: 400, height: 300)
        if CommandLine.arguments.count > 1 {
            let target = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
            target.backgroundColor = .blue; target.orderFrontRegardless()
            let cover = NSPanel(contentRect: rect.offsetBy(dx: 200, dy: 0), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            cover.backgroundColor = .red; cover.level = .floating; cover.hidesOnDeactivate = false
            cover.orderFrontRegardless()
            try "\(target.windowNumber),\(cover.windowNumber)".write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
            let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                MainActor.assumeIsolated {
                    let command = try? String(contentsOfFile: CommandLine.arguments[1] + ".command", encoding: .utf8)
                    switch command {
                    case "full": cover.setFrame(rect.insetBy(dx: -100, dy: -100), display: true)
                    case "reveal": cover.orderOut(nil)
                    case "normal": cover.level = .normal; cover.orderFrontRegardless()
                    case "floating": cover.level = .floating; cover.orderFrontRegardless()
                    case "move": cover.setFrame(rect.offsetBy(dx: -200, dy: 0), display: true); cover.orderFrontRegardless()
                    default: break
                    }
                }
            }
            pump(20)
            timer.invalidate()
            return
        }
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let file = NSTemporaryDirectory() + UUID().uuidString
        let child = Process(); child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]); child.arguments = [file]
        try child.run()
        defer { child.terminate(); try? FileManager.default.removeItem(atPath: file); try? FileManager.default.removeItem(atPath: file + ".command") }
        for _ in 0..<50 { if FileManager.default.fileExists(atPath: file) { break }; pump(0.1) }
        let ids = try String(contentsOfFile: file, encoding: .utf8).split(separator: ",").map { UInt32($0)! }
        let overlay = OverlayWindow()
        var style = Appearance(); style.width = 10; style.light.mode = .glow; style.light.extent = 30
        style.shadow.enabled = true; style.shadow.blur = 20; style.shadow.offsetX = 20
        overlay.show(around: rect, appearance: style)
        defer { overlay.orderOut(nil) }
        pump()
        let stack = WindowStackSnapshot.read(excluding: overlay.windowNumber)!
        let target = WindowOcclusion.target(in: stack, pid: child.processIdentifier, bounds: rect, knownID: ids[0])!
        let covers = stack[..<target].filter { $0.id == ids[1] }.map(\.bounds)
        precondition(stack[..<target].contains { $0.id == ids[1] }, "Foreign nonactivating panel missing")
        overlay.setOcclusion(covers)
        let canvas = overlay.contentView as! EffectCanvas
        let root = canvas.renderer.root
        var existingLayers = root.sublayers!
        let mask = canvas.layer!.mask as! CAShapeLayer
        let global = CGPoint(x: 605, y: 350) // right frame and effects underneath the red panel
        let local = CGPoint(x: global.x - overlay.frame.minX, y: global.y - overlay.frame.minY)
        precondition(!mask.path!.contains(local), "Foreign panel must hide all effects")
        let w = Int(overlay.frame.width), h = Int(overlay.frame.height)
        var pixels = [UInt8](repeating: 0, count: w*h*4)
        pixels.withUnsafeMutableBytes { data in
            let context = CGContext(data: data.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            canvas.layer!.render(in: context)
        }
        var visible = 0
        for y in 0..<h { for x in 0..<w {
            let alpha = pixels[(y*w+x)*4+3]
            let point = CGPoint(x: overlay.frame.minX + CGFloat(x) + 0.5, y: overlay.frame.minY + CGFloat(y) + 0.5)
            if covers.contains(where: { $0.insetBy(dx: 1, dy: 1).contains(point) }) { precondition(alpha == 0, "Effect leaked through mask") }
            else if alpha > 0 { visible += 1 }
        }}
        precondition(visible > 0, "Uncovered effects must remain")
        precondition(root.sublayers! == existingLayers, "Occlusion rebuilt animated effects")
        for placement in BorderPlacement.allCases {
            style.placement = placement
            overlay.show(around: rect, appearance: style)
            overlay.setOcclusion(covers + covers)
            let local = CGPoint(x: global.x - overlay.frame.minX, y: global.y - overlay.frame.minY)
            precondition(!(canvas.layer!.mask as! CAShapeLayer).path!.contains(local))
        }
        existingLayers = root.sublayers!
        for command in ["normal", "floating", "move", "full", "reveal"] {
            try command.write(toFile: file + ".command", atomically: true, encoding: .utf8); pump(0.2)
            let updated = WindowStackSnapshot.read(excluding: overlay.windowNumber)!
            let index = WindowOcclusion.target(in: updated, pid: child.processIdentifier, bounds: rect, knownID: ids[0])!
            let fixtureCovers = updated[..<index].filter { $0.id == ids[1] }.map(\.bounds)
            overlay.setOcclusion(fixtureCovers)
            let path = (canvas.layer!.mask as! CAShapeLayer).path!
            if command == "normal" || command == "floating" || command == "move" {
                precondition(fixtureCovers.count == 1 && !path.isEmpty, "Moving/normal/floating cover lost")
            }
            if command == "full" { precondition(path.isEmpty, "Full cover did not hide effects") }
            if command == "reveal" { precondition(!path.isEmpty && fixtureCovers.isEmpty, "Reveal failed") }
        }
        var times: [Double] = []
        for _ in 0..<100 {
            let began = ProcessInfo.processInfo.systemUptime
            _ = WindowStackSnapshot.read(excluding: overlay.windowNumber)
            times.append((ProcessInfo.processInfo.systemUptime - began) * 1000)
        }
        print("Metadata sample: mean \(times.reduce(0,+)/Double(times.count)) ms, P95 \(times.sorted()[94]) ms (100 reads)")
        overlay.setOcclusion([overlay.frame]); precondition((canvas.layer!.mask as! CAShapeLayer).path!.isEmpty)
        overlay.setOcclusion([])
        precondition(root.sublayers! == existingLayers, "Occlusion rebuilt animated effects")
        precondition(overlay.ignoresMouseEvents && !overlay.canBecomeKey && !overlay.canBecomeMain)
        precondition(NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmost, "Probe stole focus")
        // Bounded native ordering experiment: does normal-level relative ordering
        // leave the floating foreign panel ahead? Production still masks metadata.
        try "move".write(toFile: file + ".command", atomically: true, encoding: .utf8); pump(0.2)
        overlay.level = .normal; overlay.order(.above, relativeTo: Int(ids[0])); pump()
        let ordered = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
        let order = ordered.compactMap { $0[kCGWindowNumber as String] as? UInt32 }
        precondition(order.firstIndex(of: ids[1])! < order.firstIndex(of: UInt32(overlay.windowNumber))!)
        print("PASS: foreign-process target/panel metadata, actual masked renderer pixels, full cover/reveal, unchanged effect layers, click-through and focus; native normal-level ordering leaves floating panel ahead.")
    }
}
