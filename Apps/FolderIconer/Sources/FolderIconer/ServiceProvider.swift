import AppKit

/// "Customize Icon…" and "Restore Folder Icon" for folders selected in Finder, declared as `NSServices` in Config/AppInfo.plist.
@MainActor final class ServiceProvider: NSObject {
    let applying: ApplyController
    init(applying: ApplyController) { self.applying = applying }

    @objc func customizeIcon(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        NSApp.activate(); UIPreview.showEditor()
        applying.customize(Self.urls(pasteboard))
    }

    @objc func restoreIcon(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = Self.urls(pasteboard)
        // Restoring needs no window; FolderIconer only comes forward to explain a refusal.
        Task { if await applying.restoreFromFinder(urls) { NSApp.activate(); UIPreview.showEditor() } }
    }

    private static func urls(_ pasteboard: NSPasteboard) -> [URL] {
        pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }
}
