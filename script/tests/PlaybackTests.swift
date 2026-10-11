import AppKit
import AVFoundation
import LiveDesktopCore
@main struct PlaybackTests {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        Task { @MainActor in
            guard let screen = NSScreen.main, CommandLine.arguments.count == 3 else { fatalError("Two local videos required") }
            let surface = DesktopSurface(screen: screen)
            var errors: [String] = []
            func check(_ condition: Bool, _ text: String) { if !condition { errors.append(text) } }
            @MainActor func settle() async { for _ in 0..<100 { if surface.state == .playing { return }; try? await Task.sleep(for: .milliseconds(100)) } }
            let first = URL(fileURLWithPath: CommandLine.arguments[1]); let second = URL(fileURLWithPath: CommandLine.arguments[2])
            surface.load(first); await settle()
            check(surface.state == .playing && surface.view.playerLayer.isReadyForDisplay, "First video not ready/playing")
            check(surface.window.ignoresMouseEvents && !surface.window.canBecomeKey && !surface.window.isKeyWindow, "Desktop window captures input/focus")
            check(surface.window.level.rawValue < CGWindowLevelForKey(.desktopIconWindow), "Video not below icon level: actual=\(surface.window.level.rawValue) desktop=\(CGWindowLevelForKey(.desktopWindow)) icons=\(CGWindowLevelForKey(.desktopIconWindow))")
            let firstPlayer = surface.player
            surface.setPlaying(false); try? await Task.sleep(for: .milliseconds(200)); check(surface.player.rate == 0 && surface.state == .paused, "Manual pause failed")
            surface.setPlaying(true); await settle()
            let invalid = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try! Data("invalid video".utf8).write(to: invalid)
            surface.load(invalid)
            for _ in 0..<160 { if case .failed = surface.state { break }; try? await Task.sleep(for: .milliseconds(100)) }
            if case .failed = surface.state {} else { errors.append("Invalid video did not report failure") }
            check(surface.player === firstPlayer && surface.window.isVisible, "Failure discarded previous video")
            surface.load(second); await settle(); try? await Task.sleep(for: .milliseconds(500))
            check(surface.player !== firstPlayer && surface.view.playerLayer.isReadyForDisplay && surface.state == .playing, "Retry/transition failed")
            check(firstPlayer.items().isEmpty, "Previous decoder not released")
            surface.stop(); check(!surface.window.isVisible && surface.player.items().isEmpty, "Stop leaked video/window")
            try? FileManager.default.removeItem(at: invalid)
            print(errors.isEmpty ? "PASS: real Apple playback, first-frame transition, failure retention, retry, pause, input/focus flags, desktop level and decoder release" : "FAIL: " + errors.joined(separator: "; "))
            app.terminate(nil)
        }
        app.run()
    }
}
