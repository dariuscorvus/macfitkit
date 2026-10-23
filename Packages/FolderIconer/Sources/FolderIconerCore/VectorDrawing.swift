import AppKit

/// SVG through `NSImage` (the private `_NSSVGImageRep`), PDF page 1 through `CGPDFDocument`. A new `NSImage` per call keeps renders thread-safe.
public enum VectorSupport {
    /// SVG rendering relies on a private AppKit rep. Probed once: a red 10×10 SVG must come out red at 4 px.
    public static let svgAvailable: Bool = {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10"><rect width="10" height="10" fill="red"/></svg>"#
        guard let image = NSImage(data: Data(svg.utf8)) else { return false }
        let context = Bitmap.context(width: 4, height: 4)
        NSGraphics.draw(in: context) { image.draw(in: CGRect(x: 0, y: 0, width: 4, height: 4)) }
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return false }
        let i = 2 * context.bytesPerRow + 2 * 4
        return data[i] > 200 && data[i + 1] < 50 && data[i + 3] > 200
    }()

    /// Intrinsic size in points, or nil when the data is not a readable SVG or PDF.
    public static func intrinsicSize(_ data: Data, format: VectorContent.Format) -> CGSize? {
        let size: CGSize? = switch format {
        case .svg: svgAvailable ? NSImage(data: data)?.size : nil
        case .pdf: pdfPage(data).map { $0.getBoxRect(.cropBox).size }
        }
        guard let size, size.width > 0, size.height > 0 else { return nil }
        return size
    }

    static func pdfPage(_ data: Data) -> CGPDFPage? {
        CGDataProvider(data: data as CFData).flatMap(CGPDFDocument.init)?.page(at: 1)
    }

    /// The context is in pixels, y up, centred on the layer origin.
    static func draw(_ content: VectorContent, data: Data, pixelsPerUnit unit: CGFloat, in context: CGContext) {
        guard let format = content.format, let intrinsic = intrinsicSize(data, format: format) else { return }
        let box = CGSize(width: content.size.width * unit, height: content.size.height * unit)
        let ratio = min(box.width / intrinsic.width, box.height / intrinsic.height)
        let target = CGSize(width: intrinsic.width * ratio, height: intrinsic.height * ratio).centeredBox
        switch format {
        case .svg:
            guard let image = NSImage(data: data) else { return }
            NSGraphics.draw(in: context) { image.draw(in: target) }
        case .pdf:
            guard let page = pdfPage(data) else { return }
            let crop = page.getBoxRect(.cropBox)
            context.translateBy(x: target.minX, y: target.minY); context.scaleBy(x: ratio, y: ratio); context.translateBy(x: -crop.minX, y: -crop.minY)
            context.clip(to: crop); context.drawPDFPage(page)
        }
    }
}
