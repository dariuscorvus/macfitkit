import AppKit
import Darwin
import Foundation
@testable import FolderIconerCore

/// A temp root with `Storage/` for the applier and any number of plain folders next to it.
struct ApplyFixture {
    let root = temporaryDirectory("Apply")
    var storage: FolderIconerStorage { FolderIconerStorage(root: root.appendingPathComponent("Storage")) }
    func applier(setIcon: (@Sendable (NSImage?, URL) -> Bool)? = nil) throws -> FolderIconApplier {
        try FolderIconApplier(storage: storage, renderer: fixtureRenderer, setIcon: setIcon ?? ResourceFork.setIcon)
    }
    func folder(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    func clean() {
        if let items = FileManager.default.enumerator(atPath: root.path) {
            for case let item as String in items { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.appendingPathComponent(item).path) }
        }
        try? FileManager.default.removeItem(at: root)
    }
}

/// One sRGB rep per iconset size, all one colour.
func solidIcon(_ color: RGBAColor) -> NSImage {
    let image = NSImage(size: NSSize(width: 512, height: 512))
    for size in IconSize.iconset {
        let context = Bitmap.context(width: size.pixels, height: size.pixels)
        context.setFillColor(color.cgColor); context.fill(CGRect(x: 0, y: 0, width: size.pixels, height: size.pixels))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!); rep.size = NSSize(width: size.points, height: size.points); image.addRepresentation(rep)
    }
    return image
}

/// FinderInfo byte 8, bit 0x04: kHasCustomIcon.
func hasCustomIconFlag(_ folder: URL) -> Bool {
    var info = [UInt8](repeating: 0, count: 32)
    let read = getxattr(folder.path, XATTR_FINDERINFO_NAME, &info, 32, 0, 0)
    return read >= 9 && info[8] & 0x04 != 0
}

func iconFileExists(_ folder: URL) -> Bool { FileManager.default.fileExists(atPath: ResourceFork.iconFile(in: folder).path) }

func icns(_ folder: URL) -> Data? { ResourceFork.read(folder: folder).flatMap(ResourceFork.icnsData) }

/// The four-character types inside an `icns` container.
func icnsTypes(_ icns: Data) -> [String] {
    let bytes = [UInt8](icns); var types: [String] = [], offset = 8
    while offset + 8 <= bytes.count {
        types.append(String(decoding: bytes[offset..<offset + 4], as: UTF8.self))
        let length = bytes[offset + 4..<offset + 8].reduce(0) { $0 << 8 | Int($1) }
        guard length >= 8 else { break }; offset += length
    }
    return types
}

/// Mean colour of the 128 pt @1x representation of the folder's custom icon.
func customIconColor(_ folder: URL) -> [Int]? {
    guard let data = icns(folder), let image = NSImage(data: data),
          let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first(where: { $0.pixelsWide == 128 }) ?? image.representations.first,
          let cg = rep.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let pixels = Pixels(cg); return Array(pixels[pixels.width / 2, pixels.height / 2].prefix(3)).map(Int.init)
}

/// Fails the first `setIcon` call, then passes through. Exercises the rollback path.
final class FailFirstSetIcon: @unchecked Sendable {
    private let lock = NSLock(); private var calls = 0
    func callAsFunction(_ image: NSImage?, _ folder: URL) -> Bool {
        lock.lock(); calls += 1; let first = calls == 1; lock.unlock()
        return first ? false : ResourceFork.setIcon(image, on: folder)
    }
}

/// Status equality up to /var → /private/var and trailing slashes.
func same(_ status: FolderStatus?, _ expected: FolderStatus) -> Bool {
    func canonical(_ url: URL) -> URL { URL(fileURLWithPath: url.resolvingSymlinksInPath().path) }
    switch (status, expected) {
    case (.applied(let a)?, .applied(let b)), (.changedExternally(let a)?, .changedExternally(let b)): return canonical(a) == canonical(b)
    default: return status == expected
    }
}
