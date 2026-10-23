import CoreGraphics
import CoreImage
import ImageIO

enum ImageLoading {
    /// Applies EXIF orientation and caps memory at 2048 px on the long edge.
    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 2048, kCGImageSourceShouldCacheImmediately: true]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Where the (possibly cropped) image lands in the content box, and the source rect it draws from.
    static func placement(_ content: ImageContent, image: CGImage) -> (source: CGRect, destination: CGRect, clip: Bool) {
        let box = CGSize(width: content.size.width, height: content.size.height).centeredBox
        let (iw, ih) = (CGFloat(image.width), CGFloat(image.height))
        let full = CGRect(x: 0, y: 0, width: iw, height: ih)
        switch content.fit {
        case .crop:
            let crop = content.crop ?? NormalizedRect(x: 0, y: 0, width: 1, height: 1)
            let source = CGRect(x: crop.x * iw, y: crop.y * ih, width: crop.width * iw, height: crop.height * ih).integral.intersection(full)
            return (source.isEmpty ? full : source, box, false)
        case .fill, .fit:
            let ratio = content.fit == .fill ? max(box.width / iw, box.height / ih) : min(box.width / iw, box.height / ih)
            let size = CGSize(width: iw * ratio, height: ih * ratio)
            return (full, size.centeredBox, content.fit == .fill)
        }
    }

    /// The adjustment chain at output resolution. Filters at identity values are skipped so plain images stay byte-stable.
    static func adjusted(_ image: CGImage, _ adjust: ImageAdjustments, pixels: CGSize, canvasPixels: CGFloat, context: CIContext) -> CGImage? {
        let width = max(1, pixels.width.rounded()), height = max(1, pixels.height.rounded())
        var output = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: width / CGFloat(image.width), y: height / CGFloat(image.height)))
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        if adjust.hue != 0 { output = output.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: adjust.hue * .pi / 180]) }
        if adjust.saturation != 1 || adjust.brightness != 0 {
            output = output.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: adjust.saturation, kCIInputBrightnessKey: adjust.brightness, kCIInputContrastKey: 1])
        }
        if adjust.blur > 0 { output = output.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: adjust.blur * canvasPixels]).cropped(to: extent) }
        if let colorize = adjust.colorize {
            let color = CIColor(red: colorize.color.r, green: colorize.color.g, blue: colorize.color.b, alpha: colorize.color.a, colorSpace: Bitmap.sRGB)!
            output = output.applyingFilter("CIColorMonochrome", parameters: [kCIInputColorKey: color, kCIInputIntensityKey: colorize.intensity])
        }
        return context.createCGImage(output.cropped(to: extent), from: extent, format: .RGBA8, colorSpace: Bitmap.sRGB)
    }
}
