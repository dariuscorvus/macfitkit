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
    var status: NSTextField!
    var generation = 0
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
        for (index,title) in ["0 · Baseline / freilegen", "1 · Teilweise verdecken", "2 · Zwei überlappende Fenster", "3 · Vollständig verdecken (12 s)", "4 · Abdeckung links versetzen", "5 · Normales Fenster vor dem Ziel", "6 · Transparente höhere Ebene", "7 · Ziel verschieben und vergrößern"].enumerated() {
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
        let menu=NSMenu();let item=NSMenuItem();let submenu=NSMenu();submenu.addItem(NSMenuItem(title:"Beenden",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"));item.submenu=submenu;menu.addItem(item);NSApp.mainMenu=menu
        target.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === target { NSApp.terminate(nil) }
    }
    @objc func change(_ sender: NSButton) {
        generation += 1; let current=generation
        covers.forEach { $0.orderOut(nil); $0.level = .floating }; high.orderOut(nil)
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
        default: break
        }
        status.stringValue="\(sender.title) · Ziel Key: \(NSApp.keyWindow === target)"
    }
}
let app=NSApplication.shared;let delegate=DesktopFixture();app.delegate=delegate;app.setActivationPolicy(.regular);app.run()
