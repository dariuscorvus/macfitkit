import Foundation

public struct VideoAsset: Identifiable, Hashable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let displayName: String?
    public let category: String
    public let thumbnailURL: URL?
    public let appleID: String?
    public var name: String { displayName ?? url.deletingPathExtension().lastPathComponent }
    public init(url: URL, displayName: String? = nil, category: String = "Eigene Videos", thumbnailURL: URL? = nil, appleID: String? = nil) {
        self.url = url; self.displayName = displayName; self.category = category
        self.thumbnailURL = thumbnailURL; self.appleID = appleID
    }
}

public struct CatalogResult: Sendable {
    public let assets: [VideoAsset]
    public let warnings: [String]
}

public enum AssetCatalog {
    // Implementation detail of macOS; deliberately configurable, not an API contract.
    public static let home = FileManager.default.homeDirectoryForCurrentUser
    public static let aerialResources = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions/WallpaperAerialsExtension.appex/Contents/Resources", isDirectory: true)
    public static let defaultRoots = [
        home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/videos", isDirectory: true),
        URL(fileURLWithPath: "/Library/Application Support/com.apple.idleassetsd/Customer", isDirectory: true),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.idleassetsd/Customer", isDirectory: true)
    ]
    public static let extensions: Set<String> = ["mov", "mp4", "m4v"]

    public static var defaultManifests: [URL] {
        [aerialResources.appendingPathComponent("entries.json"),
         URL(fileURLWithPath: "/Library/Application Support/com.apple.idleassetsd/Customer/entries.json"),
         home.appendingPathComponent("Library/Application Support/com.apple.idleassetsd/Customer/entries.json"),
         home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json")]
    }
    public static var defaultThumbnailRoots: [URL] {
        [home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/thumbnails"),
         URL(fileURLWithPath: "/Library/Application Support/com.apple.idleassetsd/Customer/thumbnails")]
    }

    public static func scan(roots: [URL], manifestURLs: [URL] = defaultManifests, thumbnailRoots: [URL] = defaultThumbnailRoots, preferredLanguages: [String] = Locale.preferredLanguages, explicitFiles: [URL] = []) -> CatalogResult {
        let manager = FileManager.default
        var found: Set<URL> = []
        var warnings: [String] = []
        for root in roots {
            var directory: ObjCBool = false
            guard manager.fileExists(atPath: root.path, isDirectory: &directory), directory.boolValue else {
                continue
            }
            guard manager.isReadableFile(atPath: root.path) else {
                warnings.append("Ordner nicht lesbar: \(root.path)")
                continue
            }
            // No symlink traversal and no modification/download of Apple's assets.
            guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles], errorHandler: { url, error in
                warnings.append("\(url.path): \(error.localizedDescription)")
                return true
            }) else { continue }
            for case let url as URL in enumerator {
                guard extensions.contains(url.pathExtension.lowercased()),
                      let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                      values.isRegularFile == true, values.isSymbolicLink != true,
                      manager.isReadableFile(atPath: url.path) else { continue }
                found.insert(url.standardizedFileURL)
            }
        }
        for url in explicitFiles where extensions.contains(url.pathExtension.lowercased()) && manager.isReadableFile(atPath: url.path) {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey])).map({ $0.isRegularFile == true }) == true { found.insert(url.standardizedFileURL) }
        }
        let metadata = AppleCatalog.read(manifestURLs: manifestURLs, preferredLanguages: preferredLanguages)
        let assets = found.map { url -> VideoAsset in
            let stem = url.deletingPathExtension().lastPathComponent.uppercased()
            let item = metadata[stem] ?? metadata[url.lastPathComponent.uppercased()]
            let thumbnail = item.flatMap { entry in
                thumbnailRoots.lazy.map { $0.appendingPathComponent(entry.id + ".png") }.first { manager.isReadableFile(atPath: $0.path) }
            }
            return VideoAsset(url: url, displayName: item?.name, category: item?.category ?? "Eigene Videos", thumbnailURL: thumbnail, appleID: item?.id)
        }.sorted { lhs, rhs in
            if lhs.name == rhs.name { return lhs.url.path < rhs.url.path }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        return CatalogResult(assets: assets, warnings: warnings + metadata.warnings)
    }
}

public enum PlaybackPolicy {
    public static func shouldPlay(manualPause: Bool, sleeping: Bool, lowPower: Bool, thermalBlocked: Bool) -> Bool {
        !manualPause && !sleeping && !lowPower && !thermalBlocked
    }
}


// Read-only adapter for Apple's local, undocumented catalog formats.
// URLs in entries.json are used only to match basenames, never fetched.
enum AppleCatalog {
    struct Entry { let id: String; let name: String; let category: String }
    struct Result {
        var entries: [String: Entry] = [:]
        var warnings: [String] = []
        subscript(_ key: String) -> Entry? { entries[key] }
    }
    static func read(manifestURLs: [URL], preferredLanguages: [String]) -> Result {
        var result = Result()
        for manifest in manifestURLs where FileManager.default.fileExists(atPath: manifest.path) {
            do {
                let data = try Data(contentsOf: manifest)
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let assets = object["assets"] as? [[String: Any]] else {
                    result.warnings.append("Apple-Katalog nicht erkannt: \(manifest.path)")
                    continue
                }
                let strings = localizedStrings(beside: manifest, preferredLanguages: preferredLanguages)
                let categories = Dictionary((object["categories"] as? [[String: Any]] ?? []).compactMap { category -> (String, String)? in
                    guard let id = category["id"] as? String else { return nil }
                    let key = category["localizedNameKey"] as? String ?? ""
                    return (id, strings[key] ?? "Apple-Hintergründe")
                }, uniquingKeysWith: { _, new in new })
                for asset in assets {
                    guard let id = asset["id"] as? String, UUID(uuidString: id) != nil else { continue }
                    let key = asset["localizedNameKey"] as? String ?? ""
                    let name = strings[key] ?? (asset["accessibilityLabel"] as? String) ?? id
                    let categoryID = (asset["categories"] as? [String])?.first ?? ""
                    let entry = Entry(id: id, name: name, category: categories[categoryID] ?? "Apple-Hintergründe")
                    result.entries[id.uppercased()] = entry
                    for (key, value) in asset where key.hasPrefix("url-") {
                        guard let text = value as? String, let url = URL(string: text) else { continue }
                        result.entries[url.lastPathComponent.uppercased()] = entry
                    }
                }
            } catch {
                result.warnings.append("Apple-Katalog nicht lesbar: \(manifest.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return result
    }
    static func localizedStrings(beside manifest: URL, preferredLanguages: [String]) -> [String: String] {
        let resources = manifest.deletingLastPathComponent().appendingPathComponent("TVIdleScreenStrings.bundle/Contents/Resources")
        var languageCodes: [String] = []
        for preferred in preferredLanguages {
            let normalized = preferred.replacingOccurrences(of: "-", with: "_")
            languageCodes.append(normalized)
            languageCodes.append(normalized.components(separatedBy: "_")[0])
        }
        languageCodes.append("en")
        var strings: [String: String] = [:]
        // Reverse order so preferred exact language wins over base / English.
        for table in ["Localizable.loctable", "Localizable.nocache.loctable"] {
            guard let data = try? Data(contentsOf: resources.appendingPathComponent(table)),
                  let object = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }
            for language in languageCodes.reversed() {
                if let values = object[language] as? [String: String] { strings.merge(values) { _, new in new } }
            }
        }
        for language in languageCodes.reversed() {
            let file = resources.appendingPathComponent(language + ".lproj/Localizable.strings")
            if let data = try? Data(contentsOf: file), let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] {
                strings.merge(values) { _, new in new }
            }
        }
        return strings
    }
}

public enum RotationSequence {
    /// Caller supplies only currently available local candidates.
    public static func next(current: String, paths: [String]) -> String? {
        var seen = Set<String>()
        let unique = paths.filter { seen.insert($0).inserted }
        guard unique.count >= 2 else { return nil }
        guard let index = unique.firstIndex(of: current) else { return unique.first }
        return unique[(index + 1) % unique.count]
    }
}
