import AppKit
import AVFoundation
import QuartzCore
import LiveDesktopCore

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
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        becomesKeyOnlyIfNeeded = true
        isFloatingPanel = false
        // NSPanel resets its level when floating behavior changes; assign last.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
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
    var playerLayer = AVPlayerLayer()
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
private final class PlaybackUnit {
    let player = AVQueuePlayer()
    let layer = AVPlayerLayer()
    let looper: AVPlayerLooper
    var observations: [NSKeyValueObservation] = []
    init(url: URL, bounds: CGRect) {
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        layer.player = player; layer.videoGravity = .resizeAspectFill; layer.frame = bounds
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }
    func stop() {
        observations.removeAll(); player.pause(); looper.disableLooping(); player.removeAllItems()
        layer.removeFromSuperlayer()
    }
}

@MainActor
final class DesktopSurface {
    let window: DesktopWindow
    let view: VideoView
    private var active: PlaybackUnit?
    private var pending: PlaybackUnit?
    private var retiring: PlaybackUnit?
    private let idlePlayer = AVQueuePlayer()
    private var wantsPlayback = true
    private var generation = UUID()
    private var timeout: Task<Void, Never>?
    private(set) var url: URL?
    private(set) var state = SurfaceState.idle { didSet { if oldValue != state { onStateChange?(state) } } }
    var onStateChange: ((SurfaceState) -> Void)?
    var onFailure: ((String) -> Void)?
    var onReady: ((URL) -> Void)?
    var crossfade = true
    var player: AVQueuePlayer { active?.player ?? pending?.player ?? idlePlayer }
    var loopCount: Int { active?.looper.loopCount ?? pending?.looper.loopCount ?? 0 }

    init(screen: NSScreen) {
        window = DesktopWindow(screen: screen)
        view = VideoView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = view
    }

    func load(_ url: URL) {
        generation = UUID(); let token = generation
        timeout?.cancel(); pending?.stop(); retiring?.stop(); retiring = nil
        self.url = url; state = .loading
        let unit = PlaybackUnit(url: url, bounds: view.bounds)
        pending = unit
        unit.layer.opacity = 0
        view.layer?.addSublayer(unit.layer)
        unit.observations.append(unit.layer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self, weak unit] layer, _ in
            guard layer.isReadyForDisplay else { return }
            Task { @MainActor [weak self, weak unit] in
                guard let self, let unit, generation == token, pending === unit else { return }
                promote(unit, url: url)
            }
        })
        unit.observations.append(unit.looper.observe(\.status, options: [.initial, .new]) { [weak self] looper, _ in
            guard looper.status == .failed else { return }
            let message = looper.error?.localizedDescription ?? "Video kann nicht abgespielt werden"
            Task { @MainActor [weak self] in self?.fail(message, token: token) }
        })
        unit.observations.append(unit.player.observe(\.timeControlStatus, options: [.new]) { [weak self, weak unit] _, _ in
            Task { @MainActor [weak self, weak unit] in
                guard let self, let unit, active === unit, generation == token else { return }
                refreshState()
            }
        })
        unit.player.play() // Decode one first frame while the old surface remains visible.
        timeout = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self, generation == token, pending != nil else { return }
            fail("Das Video liefert kein darstellbares Bild", token: token)
        }
    }

    private func promote(_ unit: PlaybackUnit, url: URL) {
        timeout?.cancel(); timeout = nil
        let old = active; pending = nil; active = unit; retiring = old
        view.playerLayer = unit.layer
        window.orderFrontRegardless()
        CATransaction.begin(); CATransaction.setAnimationDuration(crossfade && old != nil ? 0.3 : 0)
        unit.layer.opacity = 1
        CATransaction.commit()
        if !wantsPlayback { unit.player.pause() }
        refreshState(); onReady?(url)
        Task { @MainActor [weak self, weak old] in
            try? await Task.sleep(for: .milliseconds(350))
            old?.stop()
            if self?.retiring === old { self?.retiring = nil }
        }
    }

    private func fail(_ message: String, token: UUID) {
        guard generation == token else { return }
        timeout?.cancel(); timeout = nil
        pending?.stop(); pending = nil
        if active == nil { window.orderOut(nil) }
        state = .failed(message); onFailure?(message)
    }

    private func refreshState() {
        guard url != nil else { return }
        if pending != nil { state = .loading; return }
        if case .failed = state { return }
        state = !wantsPlayback ? .paused : (active?.player.timeControlStatus == .playing ? .playing : .loading)
    }

    func resize(to screen: NSScreen) {
        window.setFrame(screen.frame, display: true)
        for unit in [active, pending, retiring].compactMap({ $0 }) {
            CATransaction.begin(); CATransaction.setDisableActions(true); unit.layer.frame = view.bounds; CATransaction.commit()
        }
    }

    func setPlaying(_ playing: Bool) {
        wantsPlayback = playing
        playing ? active?.player.play() : active?.player.pause()
        refreshState()
    }

    func stop() {
        generation = UUID(); timeout?.cancel(); timeout = nil
        pending?.stop(); active?.stop(); retiring?.stop()
        pending = nil; active = nil; retiring = nil; url = nil; state = .idle
        window.orderOut(nil)
    }
}
