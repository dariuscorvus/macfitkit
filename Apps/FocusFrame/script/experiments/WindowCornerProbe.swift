import AppKit
import ScreenCaptureKit
import CoreVideo

/// Read-only feasibility probe. Captures at most one on-screen window per named
/// app; evaluates only alpha values and retains neither screenshots nor titles.
@main
@MainActor
struct WindowCornerProbe {
    static func main() async {
        NSApplication.shared.setActivationPolicy(.prohibited)
        guard CGPreflightScreenCaptureAccess() else {
            print("Screen recording permission is missing. No capture attempted.")
            exit(2)
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let bundles = CommandLine.arguments.dropFirst().isEmpty
                ? ["com.apple.finder", "com.google.Chrome", "com.apple.systempreferences", "de.highbytetech.FocusFrame"]
                : Array(CommandLine.arguments.dropFirst())
            for bundle in bundles {
                guard let window = content.windows.first(where: {
                    $0.owningApplication?.bundleIdentifier == bundle && $0.windowLayer == 0 &&
                    $0.frame.width > 200 && $0.frame.height > 200
                }) else { print("\(bundle): no eligible on-screen window"); continue }
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let scale = Double(filter.pointPixelScale)
                let config = SCStreamConfiguration()
                config.width = Int(window.frame.width * scale)
                config.height = Int(window.frame.height * scale)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false
                config.ignoreShadowsSingleWindow = true
                config.shouldBeOpaque = false
                let start = ProcessInfo.processInfo.systemUptime
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let measurement = try measure(image, scale: scale)
                let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
                print("\(bundle): \(image.width)x\(image.height) at \(scale)x; \(String(format: "%.1f", milliseconds)) ms; \(measurement)")
            }
        } catch { print("Probe failed: \(error)"); exit(1) }
    }

    static func measure(_ image: CGImage, scale: Double) throws -> String {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw CocoaError(.coderInvalidValue) }
        let limit = min(Int(80 * scale), min(width, height) / 3)
        var estimates: [String] = []
        for corner in 0..<4 {
            var samples: [(x: Double, y: Double)] = []
            for y in 0..<limit {
                let row = corner < 2 ? y : height - 1 - y
                let fromLeft = corner % 2 == 0
                var boundary: Int?
                for x in 0..<limit {
                    let column = fromLeft ? x : width - 1 - x
                    if bytes[(row * width + column) * 4 + 3] >= 128 { boundary = x; break }
                }
                if let boundary, boundary > 0 { samples.append((Double(boundary) / scale, (Double(y) + 0.5) / scale)) }
            }
            guard !samples.isEmpty else { estimates.append("corner \(corner + 1): square/opaque (no measurable arc)"); continue }
            var bestRadius = 0.0, bestError = Double.infinity
            for step in 1...320 {
                let radius = Double(step) / 4
                var error = 0.0
                for sample in samples {
                    let predicted = sample.y >= radius ? 0 : radius - sqrt(max(0, radius * radius - pow(radius - sample.y, 2)))
                    error += pow(predicted - sample.x, 2)
                }
                error = sqrt(error / Double(samples.count))
                if error < bestError { bestError = error; bestRadius = radius }
            }
            estimates.append(String(format: "corner %d: ~%.2f pt, circle-fit RMS %.2f pt (%d arc rows)", corner + 1, bestRadius, bestError, samples.count))
        }
        return estimates.joined(separator: "; ")
    }
}

