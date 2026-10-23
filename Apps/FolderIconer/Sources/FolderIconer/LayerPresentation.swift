import CoreGraphics
import FolderIconerCore
import SwiftUI

/// Typed access to a layer's content for inspector bindings. Setters ignore a different kind, so a stale binding cannot change the layer type.
extension Layer {
    var folderBase: FolderBase {
        get { if case .folderBase(let value) = content { value } else { FolderBase() } }
        set { if case .folderBase = content { content = .folderBase(newValue) } }
    }
    var image: ImageContent {
        get { if case .image(let value) = content { value } else { ImageContent(asset: "") } }
        set { if case .image = content { content = .image(newValue) } }
    }
    var text: TextContent {
        get { if case .text(let value) = content { value } else { TextContent(string: "") } }
        set { if case .text = content { content = .text(newValue) } }
    }
    var emoji: EmojiContent {
        get { if case .emoji(let value) = content { value } else { EmojiContent(character: "") } }
        set { if case .emoji = content { content = .emoji(newValue) } }
    }
}

extension LayerContent {
    var symbolName: String {
        switch self { case .folderBase: "folder"; case .image: "photo"; case .text: "textformat"; case .emoji: "face.smiling" }
    }
    var kindTitle: LocalizedStringResource {
        switch self { case .folderBase: "Folder Base"; case .image: "Image"; case .text: "Text"; case .emoji: "Emoji" }
    }
}

extension FolderBase.Style {
    var title: LocalizedStringResource { switch self { case .system: "System Folder"; case .color: "Colored Folder"; case .none: "No Folder" } }
}

extension ImageContent.Fit {
    var title: LocalizedStringResource { switch self { case .fill: "Fill"; case .fit: "Fit"; case .crop: "Crop" } }
}

extension FontWeight {
    var title: LocalizedStringResource {
        switch self {
        case .ultraLight: "Ultra Light"; case .thin: "Thin"; case .light: "Light"; case .regular: "Regular"; case .medium: "Medium"
        case .semibold: "Semibold"; case .bold: "Bold"; case .heavy: "Heavy"; case .black: "Black"
        }
    }
}

extension LayerBlendMode {
    var title: LocalizedStringResource {
        switch self {
        case .normal: "Normal"; case .multiply: "Multiply"; case .screen: "Screen"; case .overlay: "Overlay"; case .darken: "Darken"; case .lighten: "Lighten"
        case .colorDodge: "Color Dodge"; case .colorBurn: "Color Burn"; case .softLight: "Soft Light"; case .hardLight: "Hard Light"; case .difference: "Difference"
        case .exclusion: "Exclusion"; case .hue: "Hue"; case .saturation: "Saturation"; case .color: "Color"; case .luminosity: "Luminosity"
        }
    }
}

extension RGBAColor {
    var cgColor: CGColor { CGColor(colorSpace: Bitmap.sRGB, components: [r, g, b, a].map { CGFloat($0) })! }
    init(_ color: CGColor) {
        let c = color.converted(to: Bitmap.sRGB, intent: .defaultIntent, options: nil)?.components ?? [0, 0, 0, 1]
        self.init(r: Double(c[0]), g: Double(c[min(1, c.count - 1)]), b: Double(c[min(2, c.count - 1)]), a: Double(c.count > 3 ? c[3] : 1))
    }
}

extension Binding where Value == RGBAColor {
    var cgColor: Binding<CGColor> { Binding<CGColor>(get: { wrappedValue.cgColor }, set: { wrappedValue = RGBAColor($0) }) }
}

extension Binding where Value == Double {
    /// Shows a stored value multiplied by `factor`, e.g. canvas units as percent.
    func scaled(_ factor: Double) -> Binding<Double> { Binding(get: { wrappedValue * factor }, set: { wrappedValue = $0 / factor }) }
}
