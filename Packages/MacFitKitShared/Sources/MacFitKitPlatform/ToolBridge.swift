import AppKit
import MacFitKitCore

public enum BridgeNames {
    public static let hubBundleIdentifier = "tech.highbyte.macfitkit.Menu"
    public static let heartbeat = Notification.Name("tech.highbyte.macfitkit.bridge.v1.heartbeat")
    public static let status = Notification.Name("tech.highbyte.macfitkit.bridge.v1.status")
    public static let disconnect = Notification.Name("tech.highbyte.macfitkit.bridge.v1.disconnect")
    public static func command(_ tool: ToolID) -> Notification.Name { .init("tech.highbyte.macfitkit.bridge.v1.command.\(tool.rawValue)") }
}

/// Separate channels let integration fixtures exercise IPC without addressing installed apps.
public struct BridgeEnvironment: Sendable {
    public let namespace: String
    public let hubBundleIdentifier: String
    public let toolBundleIdentifiers: [ToolID: String]
    public static let production = Self(namespace: "tech.highbyte.macfitkit.bridge.v1", hubBundleIdentifier: BridgeNames.hubBundleIdentifier)
    public init(namespace: String, hubBundleIdentifier: String, toolBundleIdentifiers: [ToolID: String] = [:]) {
        self.namespace = namespace; self.hubBundleIdentifier = hubBundleIdentifier; self.toolBundleIdentifiers = toolBundleIdentifiers
    }
    public func bundleIdentifier(for tool: ToolID) -> String { toolBundleIdentifiers[tool] ?? tool.bundleIdentifier }
    public var heartbeat: Notification.Name { .init(namespace + ".heartbeat") }
    public var status: Notification.Name { .init(namespace + ".status") }
    public var disconnect: Notification.Name { .init(namespace + ".disconnect") }
    public func command(_ tool: ToolID) -> Notification.Name { .init(namespace + ".command." + tool.rawValue) }
}

@MainActor
public enum ToolTransport {
    public static func post<P: Codable & Sendable>(_ payload: P, name: Notification.Name) {
        guard let data = try? BridgeEnvelope(payload).encoded() else { return }
        DistributedNotificationCenter.default().postNotificationName(name, object: nil,
            userInfo: ["payload": data], deliverImmediately: true)
    }
    public static func observe<P: Codable & Sendable>(_ name: Notification.Name, as type: P.Type,
                                                       receive: @escaping @MainActor (P) -> Void) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { notification in
            guard let data = notification.userInfo?["payload"] as? Data,
                  let payload = BridgeEnvelope<P>.decode(data) else { return }
            Task { @MainActor in receive(payload) }
        }
    }
    public static func validProcess(_ pid: Int32, bundle: String) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return false }
        return app.bundleIdentifier == bundle
    }
}

@MainActor
public final class ToolBridgeClient {
    public let instance = UUID()
    private let environment: BridgeEnvironment
    private let tool: ToolID
    private let state: @MainActor () -> (Bool, String)
    private let command: @MainActor (ToolCommand) -> Void
    private let visibility: @MainActor (Bool) -> Void
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var lease = MenuLease()
    private var hub: HubHeartbeat?
    private var hidden = false

    public init(tool: ToolID, environment: BridgeEnvironment = .production, state: @escaping @MainActor () -> (Bool, String),
                command: @escaping @MainActor (ToolCommand) -> Void,
                menuVisible: @escaping @MainActor (Bool) -> Void) {
        self.environment = environment; self.tool = tool; self.state = state; self.command = command; self.visibility = menuVisible
    }
    public func start() {
        guard observers.isEmpty else { return }
        visibility(true)
        observers.append(ToolTransport.observe(environment.heartbeat, as: HubHeartbeat.self) { [weak self] heartbeat in
            guard let self, ToolTransport.validProcess(heartbeat.processID, bundle: self.environment.hubBundleIdentifier) else { return }
            self.hub = heartbeat
            if heartbeat.acknowledged.contains(self.instance) { self.lease.acknowledge(at: ProcessInfo.processInfo.systemUptime) }
            self.updateVisibility(); self.publishStatus()
        })
        observers.append(ToolTransport.observe(environment.disconnect, as: UUID.self) { [weak self] id in
            guard let self, self.hub?.instance == id else { return }
            self.hub = nil; self.lease.clear(); self.updateVisibility()
        })
        observers.append(ToolTransport.observe(environment.command(tool), as: ToolCommand.self) { [weak self] action in
            guard let self else { return }
            // Only connected hubs can control a running tool; discovery is read-only.
            if action != .requestStatus {
                guard let hub = self.hub, self.lease.isConnected(at: ProcessInfo.processInfo.systemUptime),
                      ToolTransport.validProcess(hub.processID, bundle: self.environment.hubBundleIdentifier) else { return }
            }
            if action != .requestStatus { self.command(action) }
            self.publishStatus()
        })
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateVisibility() }
        }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
        publishStatus()
    }
    public func publishStatus() {
        let (enabled, detail) = state()
        ToolTransport.post(ToolStatus(tool: tool, processID: ProcessInfo.processInfo.processIdentifier,
            instance: instance, enabled: enabled, detail: String(detail.prefix(240)), menuManaged: hidden), name: environment.status)
    }
    private func updateVisibility() {
        let connected = lease.isConnected(at: ProcessInfo.processInfo.systemUptime)
        if hidden != connected { hidden = connected; visibility(!connected) }
    }
    public func stop() {
        timer?.invalidate(); timer = nil
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }; observers = []
        lease.clear(); hub = nil; updateVisibility()
    }
}

@MainActor
public enum ToolLocator {
    static func existingApplication(_ url: URL, tool: ToolID) -> Bool {
        FileManager.default.fileExists(atPath: url.path) &&
        !url.path.contains("/.Trash/") && !url.path.contains("/.Trashes/") &&
        !url.path.contains("/Contents/Resources/ToolPayloads/") &&
        Bundle(url: url)?.bundleIdentifier == tool.bundleIdentifier
    }
    public static func running(_ tool: ToolID) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: tool.bundleIdentifier).first { !$0.isTerminated }
    }
    public static func location(_ tool: ToolID) -> URL? {
        if let url = running(tool)?.bundleURL { return url }
        let roots = [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"), URL(fileURLWithPath: "/Applications")]
        for root in roots {
            let url = root.appendingPathComponent(tool.name + ".app")
            if existingApplication(url, tool: tool) { return url }
        }
        // Launch Services also returns build products and extracted backups. Those are
        // not installed tools; use the application folders or an actually running app.
        return nil
    }
}
