import Foundation

public extension IconDocument {
    /// One system folder base named "Folder".
    static func newDocument() -> IconDocument { IconDocument(layers: [Layer(name: "Folder", content: .folderBase(FolderBase()))]) }

    var hasFolderBase: Bool { layers.contains { $0.content.isFolderBase } }
    func index(of id: Layer.ID) -> Int? { layers.firstIndex { $0.id == id } }
    subscript(layer id: Layer.ID) -> Layer? {
        get { index(of: id).map { layers[$0] } }
        set { if let i = index(of: id) { if let newValue { layers[i] = newValue } else { layers.remove(at: i) } } }
    }

    /// Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`.
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { layers[$0] }
        var rest = layers.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        rest.insert(contentsOf: moving, at: min(rest.count, destination - source.count { $0 < destination }))
        layers = rest
    }

    /// Inserts a copy above the original with new IDs. Refused for the folder base.
    @discardableResult mutating func duplicate(_ id: Layer.ID) -> Layer.ID? {
        guard let i = index(of: id), !layers[i].content.isFolderBase else { return nil }
        var copy = layers[i]; copy.id = UUID(); copy.name += " copy"
        layers.insert(copy, at: i + 1); return copy.id
    }

    mutating func remove(_ id: Layer.ID) { layers.removeAll { $0.id == id } }

    /// Assets referenced by any layer, in first-use order.
    var assetIDs: [AssetID] {
        var seen = Set<AssetID>(); return layers.flatMap(\.content.assetIDs).filter { seen.insert($0).inserted }
    }
}
