import AppKit
import Observation
import MacFitKitCore
import MacFitKitPlatform

@MainActor @Observable
final class HubController {
    let bridge = ToolBridgeHost()
    var available: [ToolID] = []
    var message = ""
    func refresh() { available = ToolID.allCases.filter { ToolLocator.location($0) != nil } }
    func supported(_ tool: ToolID) -> Bool { ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= tool.minimumSystemMajor }
    func description(_ tool: ToolID) -> String {
        guard supported(tool) else { return "Benötigt macOS \(tool.minimumSystemMajor)" }
        if let status = bridge.statuses[tool] { return status.detail }
        return ToolLocator.running(tool) == nil ? "Nicht gestartet" : "Nicht verbunden · ggf. Update nötig"
    }
    func start(_ tool: ToolID, openSettings: Bool = false) {
        guard supported(tool), let url = ToolLocator.location(tool) else { return }
        if ToolLocator.running(tool) != nil {
            if openSettings { bridge.send(.openSettings, to: tool) }
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] app, error in
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
