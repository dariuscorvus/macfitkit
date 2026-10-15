import Foundation

public enum ToolID: String, Codable, CaseIterable, Identifiable, Sendable {
    case focusFrame, liveDesktop, dockPreview, universalPiP
    public var id: String { rawValue }
    public var name: String {
        switch self { case .focusFrame: "FocusFrame"; case .liveDesktop: "LiveDesktop"; case .dockPreview: "DockPreview"; case .universalPiP: "UniversalPiP" }
    }
    public var bundleIdentifier: String {
        switch self {
        case .focusFrame: "de.highbytetech.FocusFrame"
        case .liveDesktop: "tech.highbyte.LiveDesktop.prototype"
        case .dockPreview: "tech.highbyte.macfitkit.DockPreview"
        case .universalPiP: "tech.highbyte.macfitkit.UniversalPiP"
        }
    }
    public var symbol: String {
        switch self { case .focusFrame: "viewfinder"; case .liveDesktop: "play.rectangle"; case .dockPreview: "macwindow.on.rectangle"; case .universalPiP: "pip" }
    }
    public var minimumSystemMajor: Int { self == .liveDesktop ? 26 : 14 }
}

public enum ToolCommand: Codable, Equatable, Sendable {
    case requestStatus, openSettings, setEnabled(Bool), quit
}

public struct ToolStatus: Codable, Equatable, Sendable {
    public let tool: ToolID
    public let processID: Int32
    public let instance: UUID
    public var enabled: Bool
    public var menuManaged: Bool
    public var detail: String
    public init(tool: ToolID, processID: Int32, instance: UUID, enabled: Bool, detail: String, menuManaged: Bool = false) {
        self.tool = tool; self.processID = processID; self.instance = instance
        self.enabled = enabled; self.detail = detail; self.menuManaged = menuManaged
    }
}

public struct BridgeEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public var version: Int
    public var payload: Payload
    public init(_ payload: Payload, version: Int = 1) { self.version = version; self.payload = payload }
    public func encoded() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(_ data: Data) -> Payload? {
        guard data.count < 65_536, let envelope = try? JSONDecoder().decode(Self.self, from: data), envelope.version == 1 else { return nil }
        return envelope.payload
    }
}

public struct HubHeartbeat: Codable, Sendable {
    public var processID: Int32
    public var instance: UUID
    public var acknowledged: [UUID]
    public init(processID: Int32, instance: UUID, acknowledged: [UUID]) {
        self.processID = processID; self.instance = instance; self.acknowledged = acknowledged
    }
}

/// In-memory lease: hiding a tool icon is never a persisted preference.
public struct MenuLease: Sendable {
    private var lastAcknowledgement: TimeInterval?
    public init() {}
    public mutating func acknowledge(at time: TimeInterval) { lastAcknowledgement = time }
    public mutating func clear() { lastAcknowledgement = nil }
    public func isConnected(at time: TimeInterval) -> Bool {
        guard let lastAcknowledgement else { return false }
        return time >= lastAcknowledgement && time - lastAcknowledgement < 3
    }
}
