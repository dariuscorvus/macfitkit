import AppKit
import ScreenCaptureKit

@MainActor public protocol WindowSourceProviding {
    func windows() async throws -> [WindowSource]
}

@MainActor public final class WindowSourceProvider: WindowSourceProviding {
    public init() {}
    public func windows() async throws -> [WindowSource] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        return content.windows.compactMap { window -> WindowSource? in
            guard let app = window.owningApplication, window.windowLayer == 0,
                  window.frame.width > 1, window.frame.height > 1,
                  app.processID != ProcessInfo.processInfo.processIdentifier,
                  !Self.excluded(app.bundleIdentifier) else { return nil }
            return WindowSource(id: window.windowID, processID: app.processID, appName: app.applicationName,
                                title: window.title ?? "Fenster ohne Titel", frame: window.frame,
                                pixelScale: CGFloat(SCContentFilter(desktopIndependentWindow: window).pointPixelScale))
        }.sorted {
            let a = $0.appName.localizedCaseInsensitiveContains("UTM"), b = $1.appName.localizedCaseInsensitiveContains("UTM")
            if a != b { return a }
            if $0.appName != $1.appName { return $0.appName.localizedStandardCompare($1.appName) == .orderedAscending }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
    private static func excluded(_ id: String) -> Bool {
        id.hasPrefix("tech.highbyte.macfitkit.") || id == "de.highbytetech.FocusFrame" || id == "tech.highbyte.LiveDesktop.prototype"
    }
}
