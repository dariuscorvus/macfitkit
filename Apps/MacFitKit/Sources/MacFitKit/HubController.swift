import AppKit
import Observation
import MacFitKitCore
import MacFitKitPlatform

@MainActor @Observable
final class HubController {
    let bridge: ToolBridgeHost
    private let previewDirectory: URL?
    private let previewNamespace: String?
    var isMenuPreview: Bool { previewDirectory != nil }
    init() {
        var directory: URL?
        var namespace: String?
        #if DEBUG
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--menu-preview"), args.indices.contains(index + 2),
           args[index + 2].hasPrefix("tech.highbyte.macfitkit.preview.") {
            directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            namespace = args[index + 2]
        }
        #endif
        previewDirectory = directory; previewNamespace = namespace
        if let namespace {
            bridge = ToolBridgeHost(environment: BridgeEnvironment(namespace: namespace,
                hubBundleIdentifier: namespace + ".hub",
                toolBundleIdentifiers: Dictionary(uniqueKeysWithValues: ToolID.allCases.map { ($0, namespace + "." + $0.rawValue) })))
        } else { bridge = ToolBridgeHost() }
    }
    func running(_ tool: ToolID) -> NSRunningApplication? {
        guard let previewNamespace else { return ToolLocator.running(tool) }
        return NSRunningApplication.runningApplications(withBundleIdentifier: previewNamespace + "." + tool.rawValue).first
    }
    private func location(_ tool: ToolID) -> URL? {
        guard let previewDirectory else { return ToolLocator.location(tool) }
        let url = previewDirectory.appendingPathComponent(tool.rawValue + ".app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    var available: [ToolID] = []
    var message = ""
    func refresh() { available = ToolID.allCases.filter { location($0) != nil } }
    func supported(_ tool: ToolID) -> Bool { ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= tool.minimumSystemMajor }
    func description(_ tool: ToolID) -> String {
        guard supported(tool) else { return "Benötigt macOS \(tool.minimumSystemMajor)" }
        if let status = bridge.statuses[tool] { return status.detail }
        return running(tool) == nil ? "Nicht gestartet" : "Nicht verbunden · ggf. Update nötig"
    }
    func start(_ tool: ToolID, openSettings: Bool = false) {
        guard supported(tool), let url = location(tool) else { return }
        if running(tool) != nil {
            if openSettings { bridge.send(.openSettings, to: tool) }
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        if let previewDirectory, let previewNamespace {
            configuration.arguments = [tool.rawValue, previewNamespace, previewDirectory.path]
        }
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] app, error in
            let errorMessage = error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                if let errorMessage { self.message = errorMessage }
                else if openSettings { self.bridge.send(.openSettings, to: tool) }
                self.refresh()
            }
        }
    }
}
