import Foundation
import MacFitKitCore

public struct PublishedToolRelease: Sendable {
    public let version: ToolVersion
    public let page: URL
    public let tag: String
    public let prerelease: Bool
    public let downloadURL: URL?
    public let archiveSHA256: String?
}

public enum ToolReleaseChecker {
    public static let releasesURL = URL(string: "https://api.github.com/repos/dariuscorvus/macfitkit/releases?per_page=100")!
    public static func check() async throws -> [ToolID: PublishedToolRelease] {
        try await check { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw InstallError("GitHub konnte nicht erreicht werden oder hat die Anfrage begrenzt. Bitte später erneut prüfen.")
            }
            return data
        }
    }
    // Injectable transport keeps release selection and manifest validation testable without a network.
    static func check(load: @Sendable (URLRequest) async throws -> Data) async throws -> [ToolID: PublishedToolRelease] {
        var request = URLRequest(url: releasesURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MacFitKit", forHTTPHeaderField: "User-Agent")
        let releases = try JSONDecoder().decode([Release].self, from: await load(request))
        var result: [ToolID: PublishedToolRelease] = [:]
        for tool in ToolID.allCases {
            guard let release = releases.filter({ !$0.draft && $0.tag_name.hasPrefix(tool.name.lowercased() + "-v") })
                .sorted(by: { ($0.published_at ?? "") > ($1.published_at ?? "") }).first,
                  let asset = release.assets.first(where: { $0.name == "Release-info.json" }) else { continue }
            guard asset.url.scheme == "https", asset.url.host == "api.github.com",
                  asset.url.path.hasPrefix("/repos/dariuscorvus/macfitkit/releases/assets/"),
                  release.html_url.scheme == "https", release.html_url.host == "github.com",
                  release.html_url.path.hasPrefix("/dariuscorvus/macfitkit/releases/tag/") else {
                throw InstallError("Die Releasequelle für \(tool.name) ist ungültig.")
            }
            var manifestRequest = URLRequest(url: asset.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            manifestRequest.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            manifestRequest.setValue("MacFitKit", forHTTPHeaderField: "User-Agent")
            let manifest = try JSONDecoder().decode(Manifest.self, from: await load(manifestRequest))
            guard manifest.bundleIdentifier == tool.bundleIdentifier, manifest.app == tool.name,
                  !manifest.version.isEmpty, !manifest.build.isEmpty else {
                throw InstallError("Die Versionsangaben für \(tool.name) passen nicht zum Tool.")
            }
            let archive = release.assets.first { $0.name.hasPrefix(tool.name + "-") && $0.name.hasSuffix(".zip") && manifest.files?[$0.name] != nil }
            let checksum = archive.flatMap { manifest.files?[$0.name] }
            let validArchive = archive.flatMap { asset -> URL? in
                guard let hash = checksum, hash.count == 64, hash.allSatisfy({ $0.isHexDigit }),
                      let url = asset.browser_download_url, url.scheme == "https", url.host == "github.com",
                      url.path.hasPrefix("/dariuscorvus/macfitkit/releases/download/") else { return nil }
                return url
            }
            result[tool] = PublishedToolRelease(version: .init(version: manifest.version, build: manifest.build),
                page: release.html_url, tag: release.tag_name, prerelease: release.prerelease,
                downloadURL: validArchive, archiveSHA256: validArchive == nil ? nil : checksum?.lowercased())
        }
        return result
    }
    private struct Release: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let published_at: String?
        let html_url: URL
        let assets: [Asset]
    }
    private struct Asset: Decodable { let name: String; let url: URL; let browser_download_url: URL? }
    private struct Manifest: Decodable { let app: String; let version: String; let build: String; let bundleIdentifier: String; let files: [String: String]? }
}
