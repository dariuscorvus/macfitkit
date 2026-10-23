import CoreGraphics

public extension LayerTransform {
    /// Maps local content units (centred at the origin, y up) to pixels of an N×N CG canvas (y up).
    func affine(pixels: Int) -> CGAffineTransform {
        let n = CGFloat(pixels)
        return CGAffineTransform(translationX: x * n, y: (1 - y) * n)
            .rotated(by: -rotation * .pi / 180)
            .scaledBy(x: scale * (flipX ? -1 : 1) * n, y: scale * (flipY ? -1 : 1) * n)
    }

    /// Same mapping into a y-down view space of `side` points, for the editor canvas.
    func viewAffine(side: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: x * side, y: y * side)
            .rotated(by: rotation * .pi / 180)
            .scaledBy(x: scale * (flipX ? -1 : 1) * side, y: -scale * (flipY ? -1 : 1) * side)
    }
}

public extension CGSize {
    /// The content box `(−w/2, −h/2, w, h)` in local units.
    var centeredBox: CGRect { CGRect(x: -width / 2, y: -height / 2, width: width, height: height) }
}
