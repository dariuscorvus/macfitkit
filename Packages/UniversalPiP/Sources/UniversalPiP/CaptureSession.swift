import AppKit
@preconcurrency import ScreenCaptureKit
import CoreMedia
import CoreVideo
import IOSurface

// Immutable handoff retains the CVPixelBuffer for the lifetime of the displayed IOSurface.
public struct CapturedFrame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let contentRect: CGRect
    public let contentScale: CGFloat
    public let scaleFactor: CGFloat
    public var surface: IOSurfaceRef? { CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() }
    public var size: CGSize { contentRect.size }
}
public enum CaptureEvent: Sendable { case frame(CapturedFrame), idle, unavailable, ended, failure }

@MainActor public protocol PiPCapturing: AnyObject {
    func start(source: WindowSource, size: CGSize, receive: @escaping @MainActor @Sendable (CaptureEvent) -> Void) async throws
    func resize(_ size: CGSize) async throws
    func stop() async
}

// One pending frame and one queued main-actor delivery, regardless of capture rate.
private final class StreamOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: CaptureEvent?
    private var scheduled = false
    private var active = true
    private let receive: @MainActor @Sendable (CaptureEvent) -> Void
    init(receive: @escaping @MainActor @Sendable (CaptureEvent) -> Void) { self.receive = receive }
    func invalidate() { lock.lock(); active = false; pending = nil; lock.unlock() }
    private func offer(_ event: CaptureEvent) {
        lock.lock()
        guard active else { lock.unlock(); return }
        // Terminal events must not be hidden by a subsequently queued frame.
        if case .failure = pending { lock.unlock(); return }
        if case .ended = pending { lock.unlock(); return }
        if case .idle = event, case .unavailable = pending { lock.unlock(); return }
        // Idle must not replace an as-yet undisplayed valid frame.
        if case .idle = event, case .frame = pending { lock.unlock(); return }
        pending = event
        let enqueue = !scheduled; scheduled = true; lock.unlock()
        if enqueue { Task { @MainActor [weak self] in self?.deliver() } }
    }
    @MainActor private func deliver() {
        lock.lock(); let event = active ? pending : nil; pending = nil; scheduled = false; lock.unlock()
        if let event { receive(event) }
    }
    func stream(_ stream: SCStream, didStopWithError error: any Error) { offer(.failure) }
    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let values = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let info = values.first, let raw = info[.status] as? Int,
              let status = SCFrameStatus(rawValue: raw) else { return }
        switch status {
        case .complete:
            guard let pixel = buffer.imageBuffer,
                  let dict = info[.contentRect] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: dict as CFDictionary), rect.width > 0, rect.height > 0,
                  CVPixelBufferGetIOSurface(pixel) != nil else { return }
            let bounds = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixel), height: CVPixelBufferGetHeight(pixel))
            let scaleFactor = (info[.scaleFactor] as? NSNumber)?.doubleValue ?? 1
            let validRect = PiPGeometry.pixelContentRect(rect, scaleFactor: scaleFactor, pixelSize: bounds.size)
            guard !validRect.isNull, validRect.width > 0, validRect.height > 0 else { return }
            offer(.frame(CapturedFrame(pixelBuffer: pixel, contentRect: validRect,
                contentScale: (info[.contentScale] as? NSNumber)?.doubleValue ?? 1,
                scaleFactor: scaleFactor)))
        case .idle: offer(.idle)
        case .blank, .suspended: offer(.unavailable)
        case .stopped: offer(.ended)
        case .started: break
        @unknown default: break
        }
    }
}

@MainActor public final class CaptureSession: PiPCapturing {
    private var stream: SCStream?
    private var output: StreamOutput?
    private let queue = DispatchQueue(label: "tech.highbyte.macfitkit.UniversalPiP.frames", qos: .userInteractive)
    public init() {}
    private func configuration(_ size: CGSize) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = max(2, Int(size.width)); config.height = max(2, Int(size.height))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30); config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false; config.capturesAudio = false
        config.ignoreShadowsSingleWindow = true
        config.scalesToFit = true; config.preservesAspectRatio = true
        config.colorSpaceName = CGColorSpace.sRGB
        return config
    }
    public func start(source: WindowSource, size: CGSize, receive: @escaping @MainActor @Sendable (CaptureEvent) -> Void) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        guard let window = content.windows.first(where: { $0.windowID == source.id && $0.owningApplication?.processID == source.processID }) else {
            throw CaptureFailure.sourceEnded
        }
        let output = StreamOutput(receive: receive)
        let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration(size), delegate: output)
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: queue)
        self.stream = stream; self.output = output
        do { try await stream.startCapture() } catch { await stop(); throw error }
    }
    public func resize(_ size: CGSize) async throws { try await stream?.updateConfiguration(configuration(size)) }
    public func stop() async {
        output?.invalidate()
        let old = stream; stream = nil; output = nil
        if let old { try? await old.stopCapture() }
    }
}
public enum CaptureFailure: Error { case sourceEnded }
