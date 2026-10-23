import AppKit

/// "Customize Icon…" for folders selected in Finder, declared as `NSServices` in Config/AppInfo.plist.
@MainActor final class ServiceProvider: NSObject {
    let applying: ApplyController
    init(applying: ApplyController) { self.applying = applying }

    @objc func customizeIcon(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        NSApp.activate(); UIPreview.showEditor()
        applying.customize(urls)
    }
}
