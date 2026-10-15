import AppKit
import SwiftUI
import FocusFrameCore
@MainActor
final class AnimationPreview: EffectCanvas {
    var previewStyle = Appearance() { didSet { needsLayout = true } }
    override func layout() {
        super.layout()
        guard bounds.width > 0 && bounds.height > 0 else { return }
        let target = CGRect(x: 0,y: 0,width: 500,height: 260)
        let outer = EffectGeometry.alignedOverlayRect(for: target, appearance: previewStyle)
        let ratio = min((bounds.width-16)/outer.width,(bounds.height-16)/outer.height)
        renderer.update(bounds: CGRect(origin: .zero,size: outer.size), target: target.offsetBy(dx: -outer.minX,dy: -outer.minY), style: previewStyle, scale: 1)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        renderer.root.anchorPoint = .zero
        renderer.root.position = CGPoint(x: (bounds.width-outer.width*ratio)/2,y: (bounds.height-outer.height*ratio)/2)
        renderer.root.transform = CATransform3DMakeScale(ratio,ratio,1)
        CATransaction.commit()
        renderer.setVisible(window?.isVisible == true)
    }
    func play() { layoutSubtreeIfNeeded(); renderer.setVisible(true, focusChanged: true) }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { renderer.setVisible(false) }; needsLayout = true }
}

struct FocusAnimationPreview: NSViewRepresentable {
    let appearance: Appearance
    let playToken: Int
    func makeNSView(context: Context) -> AnimationPreview { AnimationPreview(frame: .zero) }
    func updateNSView(_ view: AnimationPreview, context: Context) {
        view.previewStyle = appearance
        if context.coordinator.token != playToken { context.coordinator.token = playToken; view.play() }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var token = 0 }
    static func dismantleNSView(_ view: AnimationPreview, coordinator: Coordinator) { view.renderer.setVisible(false) }
}
