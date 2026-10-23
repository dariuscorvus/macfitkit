import FolderIconerCore
import SwiftUI

/// The icon at Finder sizes, rendered @2x, each on a light and a dark tile. 512 pt is the canvas render, shown at 128 pt.
struct PreviewStrip: View {
    static let sizes = [16, 32, 64, 128, 512]
    private static let maxShown = 128
    let model: EditorModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(Self.sizes, id: \.self) { points in
                    VStack(spacing: 6) {
                        HStack(spacing: 0) {
                            tile(points, background: Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF5 / 255))
                            tile(points, background: Color(red: 0x1E / 255, green: 0x1E / 255, blue: 0x1E / 255))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("\(points) pt").font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Preview at \(points) points, light and dark"))
                }
            }
            .padding(16)
        }
    }

    private func tile(_ points: Int, background: Color) -> some View {
        let shown = CGFloat(min(points, Self.maxShown))
        return ZStack {
            background
            if let image = model.previews[points] { Image(decorative: image, scale: 2 * CGFloat(points) / shown).interpolation(.high) }
        }
        .frame(width: shown + 16, height: shown + 16)
    }
}
