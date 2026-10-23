import Foundation

/// Finds the enclosing git repository and keeps `Icon?` in its root `.gitignore`. No `git` process: `/usr/bin/git` can pop the CLT installer.
/// Nested `.gitignore` files and global excludes are not considered.
public enum GitIgnore {
    public static let rule = "Icon?"
    static let spellings: Set<String> = ["Icon?", "Icon[\\r]", "Icon\\r", "Icon\r", "Icon\r\r"]

    /// Walks up from `url` itself; `.git` may be a directory or a file (worktrees, submodules).
    public static func repositoryRoot(containing url: URL) -> URL? {
        var current = url.standardizedFileURL
        while true {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent(".git").path) { return current }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path || current.path == "/" { return nil }
            current = parent
        }
    }

    public static func ignoresIconFiles(root: URL) -> Bool {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(".gitignore")) else { return false }
        // NSString splitting keeps a trailing "\r" on the line; Swift's Character view would fuse "\r\n".
        return String(decoding: data, as: UTF8.self).components(separatedBy: "\n").contains { line in
            var rule = line; while rule.hasSuffix(" ") || rule.hasSuffix("\t") { rule.removeLast() }
            for prefix in ["/", "**/"] where rule.hasPrefix(prefix) { rule.removeFirst(prefix.count) }
            return spellings.contains(rule)
        }
    }

    /// Appends `Icon?` unless an equivalent rule exists. Returns whether the file changed.
    @discardableResult public static func addIconRule(root: URL) throws -> Bool {
        guard !ignoresIconFiles(root: root) else { return false }
        let file = root.appendingPathComponent(".gitignore")
        var data = (try? Data(contentsOf: file)) ?? Data()
        if let last = data.last, last != UInt8(ascii: "\n") { data.append(UInt8(ascii: "\n")) }
        data.append(contentsOf: Array((rule + "\n").utf8))
        try data.write(to: file, options: .atomic)
        return true
    }
}
