import CryptoKit
import Foundation

/// "<sha256-hex>.<ext>", the file name inside the package's `assets` directory.
public typealias AssetID = String

/// A `.foldericon` directory: `document.json` plus `assets/<sha256>.<ext>` copies of every imported file.
public struct DocumentPackage: Sendable, Equatable {
    public static let pathExtension = "foldericon"
    public var document: IconDocument
    public var assets: [AssetID: Data]
    public init(document: IconDocument = .newDocument(), assets: [AssetID: Data] = [:]) { self.document = document; self.assets = assets }

    public static func read(from url: URL) throws -> DocumentPackage {
        let document = try IconDocument.decode(Data(contentsOf: url.appendingPathComponent("document.json")))
        let folder = url.appendingPathComponent("assets")
        var assets: [AssetID: Data] = [:]
        for id in document.assetIDs {
            let file = folder.appendingPathComponent(id)
            guard FileManager.default.fileExists(atPath: file.path) else { throw DocumentError.missingAsset(id) }
            assets[id] = try Data(contentsOf: file)
        }
        return DocumentPackage(document: document, assets: assets)
    }

    /// Builds the package in a temporary directory and swaps it in, so a failed write leaves the old package intact.
    /// Writes only assets that a layer references.
    public func write(to url: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let scratch = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url.deletingLastPathComponent(), create: true)
        defer { try? fileManager.removeItem(at: scratch) }
        let staged = scratch.appendingPathComponent(url.lastPathComponent), folder = staged.appendingPathComponent("assets")
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        for id in document.assetIDs {
            guard let data = assets[id] else { throw DocumentError.missingAsset(id) }
            try data.write(to: folder.appendingPathComponent(id))
        }
        try document.encoded().write(to: staged.appendingPathComponent("document.json"))
        if fileManager.fileExists(atPath: url.path) { _ = try fileManager.replaceItemAt(url, withItemAt: staged) }
        else { try fileManager.moveItem(at: staged, to: url) }
    }

    /// Copies the file's bytes into the package. The same bytes always yield the same ID.
    public mutating func importAsset(from file: URL) throws -> AssetID {
        try addAsset(Data(contentsOf: file), pathExtension: file.pathExtension)
    }

    @discardableResult public mutating func addAsset(_ data: Data, pathExtension: String) -> AssetID {
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let ext = pathExtension.lowercased()
        let id = ext.isEmpty ? hash : hash + "." + ext
        assets[id] = data; return id
    }

    /// Drops assets no layer references.
    public mutating func pruneAssets() { let used = Set(document.assetIDs); assets = assets.filter { used.contains($0.key) } }
}
