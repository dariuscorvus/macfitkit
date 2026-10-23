import Foundation

/// `~/Library/Application Support/FolderIconer`: the registry, one document per applied folder, and backups of replaced icons.
public struct FolderIconerStorage: Sendable, Equatable {
    public let root: URL
    public init(root: URL) { self.root = root }

    public static var `default`: FolderIconerStorage {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FolderIconerStorage(root: support.appendingPathComponent("FolderIconer", isDirectory: true))
    }

    public var registry: URL { root.appendingPathComponent("Registry.json") }
    /// Editor autosave of the unapplied document.
    public var draft: URL { root.appendingPathComponent("Draft." + DocumentPackage.pathExtension, isDirectory: true) }
    public func document(_ id: UUID) -> URL { root.appendingPathComponent(Self.documentPath(id), isDirectory: true) }
    public func backup(_ id: UUID) -> URL { root.appendingPathComponent(Self.backupPath(id)) }
    /// Paths relative to `root`, as stored in the registry.
    static func documentPath(_ id: UUID) -> String { "Documents/\(id.uuidString).\(DocumentPackage.pathExtension)" }
    static func backupPath(_ id: UUID) -> String { "Backups/\(id.uuidString).rsrc" }
}
