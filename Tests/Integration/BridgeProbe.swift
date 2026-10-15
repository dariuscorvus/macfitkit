import AppKit
import MacFitKitCore
import MacFitKitPlatform

@main struct BridgeProbe {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = ProbeDelegate()
        app.delegate = delegate; app.setActivationPolicy(.accessory); app.run()
    }
}

@MainActor final class ProbeDelegate: NSObject, NSApplicationDelegate {
    let role = CommandLine.arguments[1]
    let channel = CommandLine.arguments[2]
    let directory = URL(fileURLWithPath: CommandLine.arguments[3])
    var client: ToolBridgeClient?
    var host: ToolBridgeHost?
    var item: NSStatusItem?
    var enabled = true
    var settingsCount = 0
    var lastSequence = ""
    var timer: Timer?
    var environment: BridgeEnvironment {
        BridgeEnvironment(namespace: channel, hubBundleIdentifier: channel + ".hub",
            toolBundleIdentifiers: Dictionary(uniqueKeysWithValues: ToolID.allCases.map { ($0, channel + "." + $0.rawValue) }))
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if role == "hub" {
            host = ToolBridgeHost(environment: environment); host?.start()
        } else if let tool = ToolID(rawValue: role) {
            let item = NSStatusBar.system.statusItem(withLength: 24); item.button?.title = "T"; self.item = item
            client = ToolBridgeClient(tool: tool, environment: environment, state: { [weak self] in
                (self?.enabled ?? false, "Fixture")
            }, command: { [weak self] command in
                guard let self else { return }
                switch command {
                case .setEnabled(let enabled): self.enabled = enabled
                case .openSettings: self.settingsCount += 1
                case .quit: NSApp.terminate(nil)
                case .requestStatus: break
                }
            }, menuVisible: { [weak self] visible in self?.item?.isVisible = visible })
            client?.start()
        } else { item = NSStatusBar.system.statusItem(withLength: 24); item?.button?.title = "L"; item?.isVisible = true }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer; tick()
    }
    func tick() {
        if let host,
           let data = try? Data(contentsOf: directory.appendingPathComponent("command.json")),
           let command = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let sequence = command["sequence"], sequence != lastSequence {
            lastSequence = sequence
            if command["action"] == "stop" { host.stop(); NSApp.terminate(nil); return }
            if let tool = command["tool"].flatMap(ToolID.init(rawValue:)) {
                switch command["action"] {
                case "disable": host.send(.setEnabled(false), to: tool)
                case "enable": host.send(.setEnabled(true), to: tool)
                case "settings": host.send(.openSettings, to: tool)
                case "quit": host.send(.quit, to: tool)
                default: host.send(.requestStatus, to: tool)
                }
            }
        }
        var report: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier, "enabled": enabled,
                                   "visible": item?.isVisible ?? true, "settingsCount": settingsCount]
        if let host {
            report["tools"] = Dictionary(uniqueKeysWithValues: host.statuses.map { ($0.key.rawValue, ["enabled": $0.value.enabled, "managed": $0.value.menuManaged]) })
            report["error"] = host.lastError
        }
        if let data = try? JSONSerialization.data(withJSONObject: report) {
            try? data.write(to: directory.appendingPathComponent(role + ".json"), options: .atomic)
        }
    }
    func applicationWillTerminate(_ notification: Notification) { client?.stop(); host?.stop(); timer?.invalidate() }
}
