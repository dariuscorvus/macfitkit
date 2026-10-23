import CoreGraphics
import Foundation

/// Fixed documents for snapshot tests, the perf test and `foldericoner-render --fixture`. Images are generated, so no binary assets ship.
public enum IconFixtures {
    public static let names = ["base-system", "base-color-green", "image-fill-clipped-rotated", "text-gradient", "emoji-rotated-half-opacity", "issue-14-example", "six-layers"] + kindNames

    public static func package(named name: String) -> DocumentPackage? {
        var package = DocumentPackage(document: IconDocument(id: id(0), layers: [Layer(id: id(1), name: "Folder", content: .folderBase(FolderBase()))]))
        func add(_ name: String, _ content: LayerContent, _ edit: (inout Layer) -> Void = { _ in }) {
            var layer = Layer(id: id(package.document.layers.count + 1), name: name, content: content); edit(&layer); package.document.layers.append(layer)
        }
        let tree = EmojiContent(character: "🌲", size: 0.3)
        let sunset = Fill.linear(stops: [GradientStop(color: RGBAColor(r: 1, g: 0.85, b: 0.2), location: 0), GradientStop(color: RGBAColor(r: 0.9, g: 0.2, b: 0.5), location: 1)], angle: 0)
        switch name {
        case "base-system": break
        case "base-color-green": package.document.layers[0].content = .folderBase(FolderBase(style: .color, color: RGBAColor(r: 0.2, g: 0.6, b: 0.3)))
        case "image-fill-clipped-rotated":
            let asset = package.addAsset(gradientPNG(), pathExtension: "png")
            add("Gradient", .image(ImageContent(asset: asset, size: CanvasSize(width: 0.9, height: 0.6)))) { $0.transform.rotation = 30; $0.clipToFolder = true }
        case "text-gradient":
            add("Label", .text(TextContent(string: "Projects", size: 0.16, fill: sunset))) { $0.transform.y = 0.55 }
        case "emoji-rotated-half-opacity":
            add("Tree", .emoji(tree)) { $0.transform = LayerTransform(x: 0.74, y: 0.3, rotation: 45); $0.opacity = 0.5 }
        case "issue-14-example":
            let forest = package.addAsset(forestPNG(), pathExtension: "png")
            add("Forest", .image(ImageContent(asset: forest))) { $0.clipToFolder = true }
            add("Label", .text(TextContent(string: "Forest", size: 0.13))) {
                $0.transform.y = 0.62
                $0.effects = [.outline(.init(color: RGBAColor(r: 0.05, g: 0.2, b: 0.1), width: 0.01)), .outerGlow(.init(color: .white, blur: 0.03))]
            }
            add("Tree", .emoji(tree)) { $0.transform = LayerTransform(x: 0.76, y: 0.28, rotation: 45); $0.opacity = 0.5 }
        case "six-layers":
            package.document.layers[0].content = .folderBase(FolderBase(style: .color, color: RGBAColor(r: 0.85, g: 0.45, b: 0.2)))
            let forest = package.addAsset(forestPNG(), pathExtension: "png"), gradient = package.addAsset(gradientPNG(), pathExtension: "png")
            add("Forest", .image(ImageContent(asset: forest, adjust: ImageAdjustments(hue: 20, saturation: 1.3, brightness: 0.05, blur: 0.004)))) { $0.clipToFolder = true; $0.blendMode = .multiply }
            add("Badge", .image(ImageContent(asset: gradient, size: CanvasSize(width: 0.3, height: 0.3), fit: .fit))) { $0.transform = LayerTransform(x: 0.25, y: 0.72, rotation: -15) }
            add("Title", .text(TextContent(string: "Six", size: 0.18, fill: sunset))) { $0.transform.y = 0.5 }
            add("Caption", .text(TextContent(string: "layers\nfixture", weight: .medium, size: 0.06))) { $0.transform.y = 0.68; $0.hideBelowSize = 32 }
            add("Tree", .emoji(tree)) { $0.transform = LayerTransform(x: 0.76, y: 0.28, rotation: 45); $0.opacity = 0.5 }
        default: guard addKindFixture(name, to: &package) else { return nil }
        }
        return package
    }

    static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))! }

    /// 64×64 diagonal orange → violet gradient.
    public static func gradientPNG() -> Data {
        let context = Bitmap.context(width: 64, height: 64)
        let colors = [RGBAColor(r: 1, g: 0.55, b: 0.1).cgColor, RGBAColor(r: 0.35, g: 0.15, b: 0.8).cgColor] as CFArray
        context.drawLinearGradient(CGGradient(colorsSpace: Bitmap.sRGB, colors: colors, locations: [0, 1])!, start: .zero, end: CGPoint(x: 64, y: 64), options: [])
        return Bitmap.png(context.makeImage()!)
    }

    /// 320×240 stylised forest: sky, hills and rows of conifers from a fixed seed.
    public static func forestPNG() -> Data {
        let (w, h) = (320.0, 240.0), context = Bitmap.context(width: Int(w), height: Int(h))
        let sky = [RGBAColor(r: 0.95, g: 0.85, b: 0.65).cgColor, RGBAColor(r: 0.45, g: 0.7, b: 0.9).cgColor] as CFArray
        context.drawLinearGradient(CGGradient(colorsSpace: Bitmap.sRGB, colors: sky, locations: [0, 1])!, start: CGPoint(x: 0, y: h * 0.4), end: CGPoint(x: 0, y: h), options: [])
        var seed: UInt64 = 14
        func random() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
        for (row, shade) in [(0, 0.42), (1, 0.32), (2, 0.22), (3, 0.13)] {
            let base = h * (0.55 - Double(row) * 0.16)
            context.setFillColor(RGBAColor(r: shade * 0.35, g: shade + 0.1, b: shade * 0.55).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: w, height: base + 4))
            var x = -10.0
            while x < w + 10 {
                let height = h * (0.18 + 0.14 * random()), width = height * (0.42 + 0.1 * random())
                context.move(to: CGPoint(x: x - width / 2, y: base)); context.addLine(to: CGPoint(x: x, y: base + height)); context.addLine(to: CGPoint(x: x + width / 2, y: base))
                context.closePath(); context.fillPath(); x += width * (0.45 + 0.4 * random())
            }
        }
        return Bitmap.png(context.makeImage()!)
    }
}
