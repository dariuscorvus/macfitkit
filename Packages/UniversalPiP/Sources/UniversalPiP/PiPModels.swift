import Foundation
import CoreGraphics

public struct WindowSource: Identifiable, Equatable, Sendable {
    public let id: UInt32
    public let processID: Int32
    public let appName: String
    public let title: String
    public let frame: CGRect
    public let pixelScale: CGFloat
    public init(id: UInt32, processID: Int32, appName: String, title: String, frame: CGRect, pixelScale: CGFloat = 1) {
        self.id = id; self.processID = processID; self.appName = appName; self.title = title; self.frame = frame; self.pixelScale = pixelScale
    }
}

public enum PiPState: Equatable, Sendable {
    case ready, permissionRequired, starting, live, paused, unavailable, ended, failed
    public var label: String {
        switch self {
        case .ready: "Bereit – Fenster auswählen"
        case .permissionRequired: "Bildschirmaufnahme freigeben"
        case .starting: "Vorschau startet …"
        case .live: "Live"
        case .paused: "Pausiert"
        case .unavailable: "Kein Live-Bild – Originalfenster wiederherstellen"
        case .ended: "Quelle nicht verfügbar – Original wiederherstellen oder neu auswählen"
        case .failed: "Vorschau unterbrochen – erneut versuchen"
        }
    }
}

public enum PiPGeometry {
    public static func aspectFit(_ source: CGSize, in bounds: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / source.width, bounds.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }
    public static func outputSize(source: CGSize, target: CGSize, scale: CGFloat) -> CGSize {
        guard source.width > 0, source.height > 0 else { return CGSize(width: 2, height: 2) }
        let factor = min(1, max(0.001, min(target.width * scale / source.width, target.height * scale / source.height)))
        return CGSize(width: max(2, floor(source.width * factor)), height: max(2, floor(source.height * factor)))
    }
    // ScreenCaptureKit contentRect is expressed in points; scaleFactor maps it to buffer pixels.
    public static func pixelContentRect(_ rect: CGRect, scaleFactor: CGFloat, pixelSize: CGSize) -> CGRect {
        guard scaleFactor.isFinite, scaleFactor > 0, rect.width > 0, rect.height > 0 else { return .zero }
        return rect.applying(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
            .intersection(CGRect(origin: .zero, size: pixelSize))
    }
    public static func visibleFrame(_ frame: CGRect, screens: [CGRect]) -> CGRect {
        guard let screen = screens.max(by: { intersectionArea(frame, $0) < intersectionArea(frame, $1) }) else { return frame }
        let width = min(max(240, frame.width), screen.width)
        let height = min(max(160, frame.height), screen.height)
        return CGRect(x: min(max(frame.minX, screen.minX), screen.maxX - width),
                      y: min(max(frame.minY, screen.minY), screen.maxY - height), width: width, height: height)
    }
    private static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let r = a.intersection(b); return r.isNull ? 0 : r.width * r.height
    }
    public static func initialFrame(source: CGRect, screens: [CGRect]) -> CGRect {
        let height = max(160, 400 * source.height / max(1, source.width) + 72)
        return visibleFrame(CGRect(x: source.maxX + 12, y: source.maxY - height, width: 400, height: height), screens: screens)
    }
}

public struct WindowFocusCandidate: Equatable, Sendable {
    public let title: String
    public let frame: CGRect
    public init(title: String, frame: CGRect) { self.title = title; self.frame = frame }
    public static func uniqueMatch(source: WindowSource, candidates: [Self]) -> Int? {
        func close(_ rect: CGRect) -> Bool {
            abs(rect.minX - source.frame.minX) <= 2 && abs(rect.minY - source.frame.minY) <= 2 &&
            abs(rect.width - source.frame.width) <= 2 && abs(rect.height - source.frame.height) <= 2
        }
        let titled = candidates.indices.filter { candidates[$0].title == source.title && !source.title.isEmpty }
        let exact = titled.filter { close(candidates[$0].frame) }
        if exact.count == 1 { return exact[0] }
        if titled.count == 1 { return titled[0] }
        if !titled.isEmpty { return nil }
        guard source.title.isEmpty || source.title == "Fenster ohne Titel" else { return nil }
        let byFrame = candidates.indices.filter { close(candidates[$0].frame) }
        return byFrame.count == 1 ? byFrame[0] : nil
    }
}
