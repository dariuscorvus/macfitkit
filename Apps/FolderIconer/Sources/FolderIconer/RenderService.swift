import CoreGraphics
import FolderIconerCore

/// Renders off the main thread with one shared renderer, so decoded assets stay cached between edits.
actor RenderService {
    private let renderer = IconRenderer()

    func render(_ package: DocumentPackage, points: Int, scale: Int = 2) -> CGImage { renderer.render(package, points: points, scale: scale) }

    func render(_ package: DocumentPackage, sizes: [Int], scale: Int = 2) -> [Int: CGImage] {
        Dictionary(uniqueKeysWithValues: sizes.map { ($0, renderer.render(package, points: $0, scale: scale)) })
    }
}
