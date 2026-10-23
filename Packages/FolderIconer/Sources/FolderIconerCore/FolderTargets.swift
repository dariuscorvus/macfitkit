import Foundation

/// Folders handed over from Finder that wait for the next apply. Each one gets its own copy of the document.
public struct PendingTargets: Equatable, Sendable {
    public private(set) var folders: [URL] = []

    public init(_ urls: [URL] = []) { add(urls) }

    public var isEmpty: Bool { folders.isEmpty }

    /// Keeps the order of first appearance; skips files, packages and folders already listed.
    public mutating func add(_ urls: [URL]) {
        for url in Self.plainFolders(urls) where !folders.contains(where: { FolderRegistry.canonicalPath($0) == FolderRegistry.canonicalPath(url) }) {
            folders.append(url)
        }
    }

    public mutating func remove(_ url: URL) { folders.removeAll { $0 == url } }
    public mutating func removeAll() { folders = [] }

    /// Directories that are not packages such as `.app` bundles.
    public static func plainFolders(_ urls: [URL]) -> [URL] {
        urls.filter { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return values?.isDirectory == true && values?.isPackage != true
        }
    }
}

/// What "Customize Icon…" in Finder does with the selection.
public enum ServiceRequest: Equatable, Sendable {
    /// The only selected folder already carries a FolderIconer icon: reopen its document.
    case edit(RegistryEntry.ID)
    /// Keep the open icon and queue these folders for the next apply.
    case target([URL])

    /// `nil` when the selection holds no folder.
    public init?(selection: [URL], entry: (URL) -> RegistryEntry.ID?) {
        let folders = PendingTargets(selection).folders
        if folders.count == 1, let id = entry(folders[0]) { self = .edit(id) }
        else if folders.isEmpty { return nil }
        else { self = .target(folders) }
    }
}

/// What "Restore Folder Icon" in Finder does: folders with a FolderIconer icon get their previous icon back. The others are only reported;
/// FolderIconer has no backup of an icon it did not set.
public struct RestoreRequest: Equatable, Sendable {
    public let entries: [RegistryEntry.ID]
    public let unknown: [URL]

    public init(selection: [URL], entry: (URL) -> RegistryEntry.ID?) {
        var entries: [RegistryEntry.ID] = [], unknown: [URL] = []
        for folder in PendingTargets(selection).folders { if let id = entry(folder) { entries.append(id) } else { unknown.append(folder) } }
        self.entries = entries; self.unknown = unknown
    }
}
