import AppKit
import CryptoKit
import Darwin
import Foundation

/// The classic resource fork of a folder's `Icon\r` file, where `NSWorkspace.setIcon` stores the `icns`.
public enum ResourceFork {
    private static let setIconLock = NSLock()

    /// `NSWorkspace.setIcon`, one call at a time. Parallel calls return true but can leave a 286-byte fork with no `icns` (macOS 27.2).
    public static func setIcon(_ image: NSImage?, on folder: URL) -> Bool {
        setIconLock.lock(); defer { setIconLock.unlock() }
        return NSWorkspace.shared.setIcon(image, forFile: folder.path, options: [])
    }

    public static func iconFile(in folder: URL) -> URL { folder.appendingPathComponent("Icon\r", isDirectory: false) }

    /// Raw fork bytes of `Icon\r`, or nil when the file or its fork is missing or empty.
    public static func read(folder: URL) -> Data? {
        let fork = iconFile(in: folder).appendingPathComponent("..namedfork/rsrc")
        guard let data = try? Data(contentsOf: fork), !data.isEmpty else { return nil }
        return data
    }

    /// Replaces the fork of an existing `Icon\r` with `data`.
    static func write(_ data: Data, folder: URL) -> Bool {
        let path = iconFile(in: folder).path
        _ = removexattr(path, XATTR_RESOURCEFORK_NAME, XATTR_NOFOLLOW)
        return data.withUnsafeBytes { setxattr(path, XATTR_RESOURCEFORK_NAME, $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW) } == 0
    }

    /// SHA-256 hex of the folder's custom `icns`, nil when the folder has none.
    public static func iconHash(folder: URL) -> String? {
        guard let fork = read(folder: folder), let icns = icnsData(fromResourceFork: fork) else { return nil }
        return SHA256.hash(data: icns).map { String(format: "%02x", $0) }.joined()
    }

    /// The first `icns` resource. All offsets are big-endian; nil for truncated or malformed forks.
    public static func icnsData(fromResourceFork fork: Data) -> Data? {
        let bytes = [UInt8](fork)
        func u16(_ at: Int) -> Int? { at >= 0 && at + 2 <= bytes.count ? Int(bytes[at]) << 8 | Int(bytes[at + 1]) : nil }
        func u32(_ at: Int) -> Int? { guard let hi = u16(at), let lo = u16(at + 2) else { return nil }; return hi << 16 | lo }
        guard let dataOffset = u32(0), let mapOffset = u32(4), let typeListOffset = u16(mapOffset + 24) else { return nil }
        let typeList = mapOffset + typeListOffset
        guard let typeCount = u16(typeList).map({ ($0 + 1) & 0xFFFF }) else { return nil }
        for index in 0..<typeCount {
            let entry = typeList + 2 + index * 8
            guard entry + 8 <= bytes.count, let refOffset = u16(entry + 6) else { return nil }
            guard bytes[entry..<entry + 4].elementsEqual("icns".utf8) else { continue }
            guard let packed = u32(typeList + refOffset + 4) else { return nil }
            let start = dataOffset + (packed & 0xFFFFFF)
            guard let length = u32(start), start + 4 + length <= bytes.count, length > 0 else { return nil }
            return Data(bytes[start + 4..<start + 4 + length])
        }
        return nil
    }
}
