import AppKit
import SwiftUI
import AVFoundation

@main
struct LiveDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { BackgroundLibraryView(controller: WallpaperController.shared) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var probe: DesktopSurface?
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var libraryWindow: NSWindow?

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: "LiveDesktop")
        item.button?.toolTip = "LiveDesktop – Apple-Hintergründe"
        item.button?.setAccessibilityTitle("LiveDesktop")
        item.button?.target = self
        item.button?.action = #selector(toggleLibrary)
        statusItem = item
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: 440, height: 700)
        popover.contentViewController = NSHostingController(rootView: BackgroundLibraryView(controller: WallpaperController.shared))
    }

    @objc private func toggleLibrary() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = statusItem?.button {
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        if CommandLine.arguments.contains("--show-library") {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 700), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "LiveDesktop – Hintergrundauswahl"
            window.contentViewController = NSHostingController(rootView: BackgroundLibraryView(controller: WallpaperController.shared))
            window.isReleasedWhenClosed = false
            window.center()
            libraryWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
        if CommandLine.arguments.contains("--show-menu") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                toggleLibrary()
                if let index = CommandLine.arguments.firstIndex(of: "--report"), CommandLine.arguments.indices.contains(index + 1) {
                    let report = "menuShown=\(popover.isShown) statusButton=\(statusItem?.button != nil) assets=\(WallpaperController.shared.assets.map(\.name))"
                    try? report.write(toFile: CommandLine.arguments[index + 1], atomically: true, encoding: .utf8)
                }
            }
        }
        guard CommandLine.arguments.contains("--probe"), let screen = NSScreen.main else { return }
        let originalFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        let surface = DesktopSurface(screen: screen)
        probe = surface
        if let index = CommandLine.arguments.firstIndex(of: "--video"), CommandLine.arguments.indices.contains(index + 1) {
            surface.load(URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            surface.setPlaying(true)
        } else {
            surface.window.backgroundColor = .systemTeal
            surface.window.orderFrontRegardless()
        }
        var seconds = CommandLine.arguments.contains("--long-probe") ? 30.0 : 8.0
        if let index = CommandLine.arguments.firstIndex(of: "--probe-seconds"), CommandLine.arguments.indices.contains(index + 1), let duration = Double(CommandLine.arguments[index + 1]), duration.isFinite {
            seconds = min(600, max(1, duration))
        }
        if let index = CommandLine.arguments.firstIndex(of: "--report"), CommandLine.arguments.indices.contains(index + 1) {
            let path = CommandLine.arguments[index + 1]
            Task { @MainActor in
                while surface.url != nil {
                    let windows = (CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]) ?? []
                    let relevant = windows.enumerated().compactMap { position, info -> String? in
                        let owner = info[kCGWindowOwnerName as String] as? String ?? ""
                        let number = (info[kCGWindowNumber as String] as? NSNumber)?.intValue ?? 0
                        let level = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
                        guard number == surface.window.windowNumber || (owner == "Finder" && level <= 0) else { return nil }
                        return "stack=\(position) owner=\(owner) window=\(number) level=\(level)"
                    }.joined(separator: "\n")
                    let progress = "ready=\(surface.view.playerLayer.isReadyForDisplay) rate=\(surface.player.rate) loops=\(surface.loopCount) elapsed=\(Date())\n\(relevant)\n"
                    try? progress.write(toFile: path + ".progress", atomically: true, encoding: .utf8)
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            let window = surface.window
            let report = "PROBE level=\(window.level.rawValue) desktop=\(CGWindowLevelForKey(.desktopWindow)) icons=\(CGWindowLevelForKey(.desktopIconWindow)) ignoresMouse=\(window.ignoresMouseEvents) key=\(window.isKeyWindow) canKey=\(window.canBecomeKey) frame=\(window.frame) visible=\(window.isVisible) ready=\(surface.view.playerLayer.isReadyForDisplay) rate=\(surface.player.rate) time=\(surface.player.currentTime().seconds) items=\(surface.player.items().count) loops=\(surface.loopCount) frontmostBefore=\(originalFrontmost) frontmostAfter=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown")"
            print(report)
            if let index = CommandLine.arguments.firstIndex(of: "--report"), CommandLine.arguments.indices.contains(index + 1) {
                try? report.write(toFile: CommandLine.arguments[index + 1], atomically: true, encoding: .utf8)
            }
            surface.stop()
            NSApp.terminate(nil)
        }
    }
}
