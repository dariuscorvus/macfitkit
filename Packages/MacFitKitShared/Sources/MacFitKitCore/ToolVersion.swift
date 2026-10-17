import Foundation

public struct ToolVersion: Codable, Equatable, Sendable, Comparable {
    public let version: String
    public let build: String
    public init(version: String, build: String) { self.version = version; self.build = build }
    public var display: String { "\(version) (Build \(build))" }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        let order = compare(lhs.version, rhs.version)
        if order != .orderedSame { return order == .orderedAscending }
        return compare(lhs.build, rhs.build) == .orderedAscending
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        compare(lhs.version, rhs.version) == .orderedSame && compare(lhs.build, rhs.build) == .orderedSame
    }
    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let right = rhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let locale = Locale(identifier: "en_US_POSIX")
        if (left + right).allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
            for index in 0..<max(left.count, right.count) {
                let a = index < left.count ? left[index] : "0"
                let b = index < right.count ? right[index] : "0"
                let order = a.compare(b, options: .numeric, locale: locale)
                if order != .orderedSame { return order }
            }
            return .orderedSame
        }
        return lhs.compare(rhs, options: [.numeric, .caseInsensitive], locale: locale)
    }
    /// Read the plist afresh: Bundle caches can otherwise retain the version from before an update.
    public static func read(appURL: URL) -> Self? {
        guard let data = try? Data(contentsOf: appURL.appendingPathComponent("Contents/Info.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let version = plist["CFBundleShortVersionString"] as? String, !version.isEmpty,
              let build = plist["CFBundleVersion"] as? String, !build.isEmpty else { return nil }
        return Self(version: version, build: build)
    }
}
