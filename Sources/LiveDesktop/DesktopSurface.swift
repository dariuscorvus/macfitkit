import AppKit
import AVFoundation
import QuartzCore

@MainActor
final class DesktopWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func isAccessibilityElement() -> Bool { false }
    override func accessibilityChildren() -> [Any]? { [] }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Above the wallpaper level, below the declared icon level. This does not
        // promise ordering relative to Finder's implementation on every OS.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        becomesKeyOnlyIfNeeded = true
        isFloatingPanel = false
        isMovable = false
        isMovableByWindowBackground = false
        // Decorative content must not become a window target for AX-based tools.
        setAccessibilityElement(false)
        setAccessibilityChildren([])
        hasShadow = false
        isOpaque = true
        backgroundColor = .black
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        // Keep the normal sharing behavior so wallpaper is not deliberately
        // excluded from screen sharing and diagnostic captures.
        title = "LiveDesktop – Wallpaper"
    }
}

@MainActor
final class VideoView: NSView {
    let playerLayer = AVPlayerLayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}

@MainActor
final class DesktopSurface {
    let window: DesktopWindow
    let player = AVQueuePlayer()
    let view: VideoView
    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?
    private var layerObservation: NSKeyValueObservation?
    private var generation = UUID()
    private var failed = false
    private(set) var url: URL?
    var loopCount: Int { looper?.loopCount ?? 0 }
    var onFailure: ((String) -> Void)?

    init(screen: NSScreen) {
        window = DesktopWindow(screen: screen)
        view = VideoView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = view
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        view.playerLayer.player = player
    }

    func load(_ url: URL) {
        stop()
        self.url = url
        failed = false
        let currentGeneration = generation
        let item = AVPlayerItem(url: url)
        // One queue/looper per screen. Decode and compositing cost scales with screens.
        looper = AVPlayerLooper(player: player, templateItem: item)
        statusObservation = looper?.observe(\.status, options: [.new]) { [weak self] looper, _ in
            if looper.status == .failed {
                let message = looper.error?.localizedDescription ?? "Videowiedergabe fehlgeschlagen"
                Task { @MainActor [weak self] in
                    guard let self, generation == currentGeneration else { return }
                    failed = true
                    window.orderOut(nil)
                    player.pause()
                    onFailure?(message)
                }
            }
        }
        layerObservation = view.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            if layer.isReadyForDisplay {
                Task { @MainActor [weak self] in
                    guard let self, generation == currentGeneration, !failed else { return }
                    window.orderFrontRegardless()
                }
            }
        }
    }

    func setPlaying(_ playing: Bool) { (playing && !failed) ? player.play() : player.pause() }
    func stop() {
        generation = UUID()
        player.pause()
        layerObservation = nil
        statusObservation = nil
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        url = nil
        window.orderOut(nil)
    }
}
