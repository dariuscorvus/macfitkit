import AppKit
import Observation
import MacFitKitCore

@MainActor @Observable
public final class ToolBridgeHost {
    public private(set) var statuses: [ToolID: ToolStatus] = [:]
    public private(set) var lastError = ""
    public var onChange: (@MainActor () -> Void)?
    @ObservationIgnored private let environment: BridgeEnvironment
    @ObservationIgnored private let instance = UUID()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var seen: [ToolID: TimeInterval] = [:]
    @ObservationIgnored private var pending: [ToolID: (ToolCommand, TimeInterval)] = [:]
    public init(environment: BridgeEnvironment = .production) { self.environment = environment }
    public func start() {
        guard observer == nil else { return }
        observer = ToolTransport.observe(environment.status, as: ToolStatus.self) { [weak self] status in
            guard let self, ToolTransport.validProcess(status.processID, bundle: self.environment.bundleIdentifier(for: status.tool)) else { return }
            self.statuses[status.tool] = status; self.seen[status.tool] = ProcessInfo.processInfo.systemUptime
            if status.menuManaged, let (command, _) = self.pending.removeValue(forKey: status.tool) {
                ToolTransport.post(command, name: environment.command(status.tool))
            }
            self.onChange?()
        }
        for tool in ToolID.allCases { ToolTransport.post(ToolCommand.requestStatus, name: environment.command(tool)) }
        beat()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.beat() } }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    private func beat() {
        let now = ProcessInfo.processInfo.systemUptime
        for (tool, status) in statuses {
            if !ToolTransport.validProcess(status.processID, bundle: environment.bundleIdentifier(for: tool)) || now - (seen[tool] ?? 0) > 3 {
                statuses.removeValue(forKey: tool); seen.removeValue(forKey: tool)
            }
        }
        for (tool, request) in pending where now - request.1 > 5 {
            pending.removeValue(forKey: tool)
            lastError = "\(tool.name) antwortet nicht. Bitte die App aktualisieren oder erneut starten."
        }
        ToolTransport.post(HubHeartbeat(processID: ProcessInfo.processInfo.processIdentifier, instance: instance,
            acknowledged: statuses.values.map(\.instance)), name: environment.heartbeat)
        onChange?()
    }
    public func send(_ command: ToolCommand, to tool: ToolID) {
        lastError = ""
        if let status = statuses[tool], status.menuManaged,
           ToolTransport.validProcess(status.processID, bundle: environment.bundleIdentifier(for: tool)) {
            ToolTransport.post(command, name: environment.command(tool))
        } else {
            pending[tool] = (command, ProcessInfo.processInfo.systemUptime)
            ToolTransport.post(ToolCommand.requestStatus, name: environment.command(tool))
            beat()
        }
    }
    public func stop() {
        ToolTransport.post(instance, name: environment.disconnect)
        timer?.invalidate(); timer = nil
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }; observer = nil
        statuses = [:]; seen = [:]; pending = [:]
    }
}
