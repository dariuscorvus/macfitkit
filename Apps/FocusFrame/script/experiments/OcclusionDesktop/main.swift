import AppKit

@MainActor final class CoverPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor final class StripeView: NSView {
    var stripe = CGRect.zero
    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.12, green: 0.52, blue: 0.32, alpha: 1).setFill()
        stripe.fill()
    }
}
@MainActor final class DesktopFixture: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var target: NSWindow!
    var background: CoverPanel!
    var covers: [CoverPanel] = []
    var high: CoverPanel!
    var customMenu: CoverPanel!
    var nativeMenu: NSMenu?
    var status: NSTextField!
    var generation = 0
    var commandTimer: Timer?
    var lastToken = ""
    let initial = CGRect(x: 350, y: 250, width: 760, height: 480)
    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.screens.first!.frame
        background = CoverPanel(contentRect: screen, styleMask: [.borderless,.nonactivatingPanel], backing: .buffered, defer: false)
        background.backgroundColor = NSColor(white: 0.16, alpha: 1); background.hasShadow = false
        background.hidesOnDeactivate = false; background.ignoresMouseEvents = true
        background.orderFrontRegardless()
        target = NSWindow(contentRect: initial, styleMask: [.titled,.closable,.resizable], backing: .buffered, defer: false)
        target.title = "FocusFrame · echte Überdeckungsprüfung"; target.isReleasedWhenClosed = false; target.delegate = self
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        let headline = NSTextField(labelWithString: "Mac mini · Frame / Glow / Shadow")
        headline.font = .boldSystemFont(ofSize: 19); stack.addArrangedSubview(headline)
        for (index,title) in ["0 · Baseline / freilegen", "1 · Teilweise verdecken", "2 · Zwei überlappende Fenster", "3 · Vollständig verdecken (12 s)", "4 · Abdeckung links versetzen", "5 · Normales Fenster vor dem Ziel", "6 · Transparente höhere Ebene", "7 · Ziel verschieben und vergrößern", "8 · Natives Kontextmenü (25 s)", "9 · Eigenes Menü auf Normal-Level"].enumerated() {
            let b = NSButton(title: title, target: self, action: #selector(change(_:))); b.tag = index; stack.addArrangedSubview(b)
        }
        status = NSTextField(labelWithString: "Baseline · Ziel fokussiert"); stack.addArrangedSubview(status)
        target.contentView!.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:target.contentView!.leadingAnchor,constant:24),stack.topAnchor.constraint(equalTo:target.contentView!.topAnchor,constant:24)])
        for i in 0..<2 {
            let p = CoverPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            p.backgroundColor = i == 0 ? NSColor(srgbRed:0.12,green:0.52,blue:0.32,alpha:1) : NSColor(srgbRed:0.2,green:0.35,blue:0.75,alpha:1)
            p.hasShadow=false; p.hidesOnDeactivate=false; p.level = .floating; p.isMovableByWindowBackground = true
            p.title="Testabdeckung \(i+1)"; covers.append(p)
        }
        high=CoverPanel(contentRect:screen,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        high.backgroundColor = .clear; high.isOpaque=false; high.hasShadow=false; high.hidesOnDeactivate=false
        high.level=NSWindow.Level(rawValue:20); high.ignoresMouseEvents=true; high.contentView=StripeView(frame:screen)
        customMenu = CoverPanel(contentRect: .zero, styleMask: [.borderless,.nonactivatingPanel], backing: .buffered, defer: false)
        customMenu.backgroundColor = NSColor(white: 0.85, alpha: 1); customMenu.hasShadow = true
        customMenu.hidesOnDeactivate = false; customMenu.level = .normal
        let rows = NSStackView(); rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 20
        for text in ["Eigenes Kontextmenü", "Öffnen", "Kopieren", "Informationen", "Schließen"] {
            rows.addArrangedSubview(NSTextField(labelWithString: text))
        }
        customMenu.contentView!.addSubview(rows); rows.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([rows.leadingAnchor.constraint(equalTo: customMenu.contentView!.leadingAnchor, constant: 16), rows.topAnchor.constraint(equalTo: customMenu.contentView!.topAnchor, constant: 16)])
        let menu=NSMenu();let item=NSMenuItem();let submenu=NSMenu();submenu.addItem(NSMenuItem(title:"Beenden",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"));item.submenu=submenu;menu.addItem(item);NSApp.mainMenu=menu
        target.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        if let index = CommandLine.arguments.firstIndex(of: "--commands"),
           CommandLine.arguments.indices.contains(index + 1) {
            let file = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            commandTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.readCommand(file) }
            }
        }
    }
    // Explicit test-only scene commands; no input synthesis or app preference changes.
    func readCommand(_ file: URL) {
        guard let data = try? Data(contentsOf: file), data.count < 4096,
              let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let phase = request["phase"] as? Int, (0...9).contains(phase),
              let token = request["token"] as? String, token != lastToken else { return }
        lastToken = token
        let button = NSButton(); button.tag = phase; button.title = "Phase \(phase)"
        change(button)
        let serial = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard self.generation == serial else { return }
            func rect(_ r: CGRect) -> [CGFloat] { [r.minX,r.minY,r.width,r.height] }
            let payload: [String: Any] = ["phase": phase, "token": token,
                "pid": ProcessInfo.processInfo.processIdentifier, "targetID": self.target.windowNumber,
                "targetFrame": rect(self.target.frame), "key": NSApp.keyWindow === self.target,
                "active": NSApp.isActive,
                "covers": self.covers.map { ["id":$0.windowNumber,"visible":$0.isVisible,"layer":$0.level.rawValue,"frame":rect($0.frame)] as [String:Any] },
                "customMenu": ["id":self.customMenu.windowNumber,"visible":self.customMenu.isVisible,"layer":self.customMenu.level.rawValue,"frame":rect(self.customMenu.frame)],
                "high": ["id":self.high.windowNumber,"visible":self.high.isVisible,"layer":self.high.level.rawValue,"frame":rect(self.high.frame)]]
            try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted,.sortedKeys])
                .write(to: file.deletingLastPathComponent().appendingPathComponent("phase-ready.json"), options: .atomic)
        }
    }
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === target { NSApp.terminate(nil) }
    }
    @objc func change(_ sender: NSButton) {
        generation += 1; let current=generation
        nativeMenu?.cancelTracking(); nativeMenu = nil
        covers.forEach { $0.orderOut(nil); $0.level = .floating }; high.orderOut(nil); customMenu.orderOut(nil)
        let r=target.frame
        let partial=CGRect(x:r.maxX-120,y:r.minY-80,width:340,height:r.height+160)
        switch sender.tag {
        case 0: break
        case 1: covers[0].setFrame(partial,display:true);covers[0].orderFrontRegardless()
        case 2:
            covers[0].setFrame(partial,display:true);covers[0].orderFrontRegardless()
            covers[1].setFrame(CGRect(x:r.maxX-240,y:r.minY-80,width:350,height:260),display:true);covers[1].orderFrontRegardless()
        case 3:
            covers[0].setFrame(r.insetBy(dx:-120,dy:-120),display:true);covers[0].orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline:.now()+12) { if self.generation == current { self.covers[0].orderOut(nil);self.status.stringValue="Wieder freigelegt · Ziel Key: \(NSApp.keyWindow === self.target)" } }
        case 4: covers[0].setFrame(partial.offsetBy(dx:-180,dy:0),display:true);covers[0].orderFrontRegardless()
        case 5: covers[0].level = .normal;covers[0].setFrame(partial,display:true);covers[0].order(.above,relativeTo:target.windowNumber)
        case 6:
            let view=high.contentView as! StripeView
            view.stripe=partial.offsetBy(dx:-high.frame.minX,dy:-high.frame.minY);view.needsDisplay=true;high.orderFrontRegardless()
        case 7: target.setFrame(CGRect(x:r.minX+50,y:r.minY+30,width:r.width+40,height:r.height+20),display:true)
        case 8:
            let menu = NSMenu(); menu.autoenablesItems = false; menu.minimumWidth = 320
            for title in ["Natives Kontextmenü", "Öffnen", "Kopieren", "Informationen", "Schließen"] {
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: ""); item.isEnabled = true; menu.addItem(item)
            }
            nativeMenu = menu
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                guard self.generation == current else { return }
                let timeout = Timer(timeInterval: 25, repeats: false) { _ in MainActor.assumeIsolated { self.nativeMenu?.cancelTracking() } }
                RunLoop.main.add(timeout, forMode: .common)
                menu.popUp(positioning: nil, at: NSPoint(x: self.target.contentView!.bounds.maxX - 100, y: 280), in: self.target.contentView!)
                timeout.invalidate()
            }
        case 9:
            customMenu.setFrame(CGRect(x: r.maxX - 100, y: r.minY + 140, width: 320, height: 240), display: true)
            customMenu.order(.above, relativeTo: target.windowNumber)
        default: break
        }
        status.stringValue="\(sender.title) · Ziel Key: \(NSApp.keyWindow === target)"
    }
}
let app=NSApplication.shared;let delegate=DesktopFixture();app.delegate=delegate;app.setActivationPolicy(.regular);app.run()
