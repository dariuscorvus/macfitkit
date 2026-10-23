import FolderIconerCore
import Foundation

// Renders a document to PNGs so the output can be inspected without the app.
let usage = """
usage: foldericoner-render <doc.foldericon | --fixture NAME> <out-dir> [--fixture-folder]
fixtures: \(IconFixtures.names.joined(separator: ", "))

"""
func fail(_ message: String) -> Never { FileHandle.standardError.write(Data((message + "\n").utf8)); exit(2) }

var arguments = Array(CommandLine.arguments.dropFirst())
let fixtureFolder = arguments.contains("--fixture-folder"); arguments.removeAll { $0 == "--fixture-folder" }
let package: DocumentPackage, output: URL
switch arguments.count {
case 3 where arguments[0] == "--fixture":
    guard let fixture = IconFixtures.package(named: arguments[1]) else { fail("unknown fixture \(arguments[1])\n" + usage) }
    package = fixture; output = URL(fileURLWithPath: arguments[2])
case 2:
    do { package = try DocumentPackage.read(from: URL(fileURLWithPath: arguments[0])) } catch { fail("cannot read \(arguments[0]): \(error.localizedDescription)") }
    output = URL(fileURLWithPath: arguments[1])
default: fail(usage)
}

let renderer = IconRenderer(options: RenderOptions(folder: fixtureFolder ? FixtureFolderShape() : SystemFolderShape.shared))
do {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for size in IconSize.iconset + [IconSize(points: 64, scale: 2)] {
        let file = output.appendingPathComponent("\(size).png")
        try Bitmap.png(renderer.render(package, size: size)).write(to: file); print(file.path)
    }
} catch { fail("cannot write: \(error.localizedDescription)") }
