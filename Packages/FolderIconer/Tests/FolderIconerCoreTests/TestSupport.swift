import CoreGraphics
import Foundation
@testable import FolderIconerCore

let fixtureRenderer = IconRenderer(options: RenderOptions(folder: FixtureFolderShape()))

func temporaryDirectory(_ name: String) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("FolderIconer\(name)-" + UUID().uuidString)
}

func solidPNG(_ color: RGBAColor, width: Int = 8, height: Int = 8) -> Data {
    let context = Bitmap.context(width: width, height: height)
    context.setFillColor(color.cgColor); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return Bitmap.png(context.makeImage()!)
}

/// A package with the given layers on top of `base`, each image layer backed by a solid asset.
func package(base: FolderBase.Style = .system, _ layers: [(RGBAColor, (inout Layer) -> Void)]) -> DocumentPackage {
    var package = DocumentPackage(document: IconDocument(layers: [Layer(name: "Folder", content: .folderBase(FolderBase(style: base)))]))
    for (color, edit) in layers {
        let asset = package.addAsset(solidPNG(color), pathExtension: "png")
        var layer = Layer(name: "Image", content: .image(ImageContent(asset: asset))); edit(&layer); package.document.layers.append(layer)
    }
    return package
}

struct Pixels {
    let bytes: [UInt8], width: Int, height: Int
    init(_ image: CGImage) { bytes = Bitmap.rgba(image); width = image.width; height = image.height }
    /// x/y from the top-left.
    subscript(x: Int, y: Int) -> [UInt8] { let i = (y * width + x) * 4; return Array(bytes[i..<i + 4]) }
    func alpha(_ x: Int, _ y: Int) -> UInt8 { bytes[(y * width + x) * 4 + 3] }
}

extension RGBAColor { static let red = RGBAColor(r: 1, g: 0, b: 0) }
