import AppKit
import FolderIconerCore
import UniformTypeIdentifiers

/// Adding and replacing symbol, vector and shape layers.
extension EditorModel {
    static let vectorTypes: [UTType] = [.svg, .pdf]

    func addSymbol() { add(Layer(name: String(localized: "Symbol"), content: .symbol(SymbolContent(name: "star.fill"))), "Add Symbol") }
    func addShape() { add(Layer(name: String(localized: "Shape"), content: .shape(ShapeContent())), "Add Shape") }

    func chooseVector(replacing id: Layer.ID? = nil) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = VectorSupport.svgAvailable ? Self.vectorTypes : [.pdf]; panel.allowsMultipleSelection = id == nil
        guard panel.runModal() == .OK else { return }
        if let id, let url = panel.url { replaceVector(id, with: url) } else { for url in panel.urls { importVector(url) } }
    }

    @discardableResult func importVector(_ url: URL) -> Bool {
        guard let (asset, size) = vectorAsset(url) else { return false }
        add(Layer(name: url.deletingPathExtension().lastPathComponent, content: .vector(VectorContent(asset: asset, size: size))), "Add Vector"); return true
    }

    func replaceVector(_ id: Layer.ID, with url: URL) {
        guard let (asset, size) = vectorAsset(url), let old = document[layer: id]?.vector.size else { return }
        edit("Replace Vector") { $0[layer: id]?.vector.asset = asset; $0[layer: id]?.vector.size = CanvasSize(width: old.width, height: old.width * size.height / size.width) }
    }

    /// The box starts with the file's aspect ratio, so aspect-fit fills it.
    private func vectorAsset(_ url: URL) -> (AssetID, CanvasSize)? {
        guard let format = VectorContent(asset: url.lastPathComponent).format else { alert = "The file is not an SVG or PDF FolderIconer can read."; return nil }
        if format == .svg && !VectorSupport.svgAvailable { alert = "This version of macOS cannot render SVG files in FolderIconer. Use a PDF instead."; return nil }
        guard let data = try? Data(contentsOf: url), let size = VectorSupport.intrinsicSize(data, format: format) else { alert = "The file is not an SVG or PDF FolderIconer can read."; return nil }
        let long = 0.6, aspect = size.width / size.height
        return (addAsset(data, pathExtension: url.pathExtension), aspect >= 1 ? CanvasSize(width: long, height: long / aspect) : CanvasSize(width: long * aspect, height: long))
    }
}
