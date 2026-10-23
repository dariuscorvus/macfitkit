import Foundation

/// One applied folder: where it is, its document and the backup of the icon it replaced.
public struct RegistryEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    /// Plain bookmark (no security scope; the app is not sandboxed). Follows renames and moves.
    public var folderBookmark: Data
    /// Last known path, shown when the bookmark no longer resolves.
    public var folderPath: String
    /// Relative to `FolderIconerStorage.root`.
    public var document: String
    /// Raw `Icon\r` resource fork of the replaced custom icon, relative to the storage root. nil: the folder had no custom icon.
    public var backup: String?
    public var appliedIconSHA256: String
    public var appliedAt: Date
}

/// `Registry.json`. A value type; `FolderIconApplier` owns the live copy and saves it after every change.
public struct FolderRegistry: Codable, Equatable, Sendable {
    public static let format = 1
    public var format = FolderRegistry.format
    public private(set) var entries: [RegistryEntry]
    public init(entries: [RegistryEntry] = []) { self.entries = entries }

    public subscript(id: UUID) -> RegistryEntry? { entries.first { $0.id == id } }

    /// A missing file is an empty registry.
    public static func load(from url: URL) throws -> FolderRegistry {
        guard FileManager.default.fileExists(atPath: url.path) else { return FolderRegistry() }
        let registry = try decoder.decode(FolderRegistry.self, from: Data(contentsOf: url))
        guard registry.format <= format else { throw CocoaError(.fileReadCorruptFile) }
        return registry
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(self).write(to: url, options: .atomic)
    }

    public mutating func upsert(_ entry: RegistryEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = entry } else { entries.append(entry) }
    }

    public mutating func remove(_ id: UUID) { entries.removeAll { $0.id == id } }

    /// Resolves the bookmark. A stale bookmark is refreshed and `folderPath` updated. nil when the folder is gone.
    public mutating func resolve(_ id: UUID) -> URL? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: entries[index].folderBookmark, options: [.withoutUI, .withoutMounting],
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: []) { entries[index].folderBookmark = fresh }
        entries[index].folderPath = url.path
        return url
    }

    /// The entry whose bookmark resolves to the same folder.
    public mutating func entry(forFolder folder: URL) -> RegistryEntry? {
        let target = Self.canonicalPath(folder)
        for entry in entries { if let url = resolve(entry.id), Self.canonicalPath(url) == target { return self[entry.id] } }
        return nil
    }

    static func canonicalPath(_ url: URL) -> String { url.standardizedFileURL.resolvingSymlinksInPath().path }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601; return encoder
    }()
    static let decoder: JSONDecoder = { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }()
}
