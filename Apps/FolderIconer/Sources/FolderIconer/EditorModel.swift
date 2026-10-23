import AppKit
import FolderIconerCore
import Observation
import OSLog
import SwiftUI

/// The open document, its selection and renders. Every change goes through `history`, so each one is a single undo step.
@MainActor @Observable final class EditorModel {
    static let canvasPoints = 512
    private(set) var package: DocumentPackage
    var selection: Layer.ID?
    private(set) var canvasImage: CGImage?
    private(set) var previews: [Int: CGImage] = [:]
    var alert: LocalizedStringResource?
    let isPreview: Bool
    @ObservationIgnored private(set) var history: SnapshotHistory<IconDocument>!
    @ObservationIgnored let renders = RenderService()
    @ObservationIgnored let storage: FolderIconerStorage
    @ObservationIgnored private let measurer = IconRenderer()
    @ObservationIgnored private var pendingCanvas: DocumentPackage?
    @ObservationIgnored private var canvasRendering = false
    @ObservationIgnored private var stripTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "tech.highbyte.macfitkit.FolderIconer", category: "editor")

    var document: IconDocument { package.document }
    var selectedLayer: Layer? { selection.flatMap { document[layer: $0] } }
    var undoManager: UndoManager? { get { history.undoManager } set { history.undoManager = newValue } }

    /// `--ui-preview` opens a fixture and never touches the draft on disk.
    init(isPreview: Bool = CommandLine.arguments.contains("--ui-preview"), storage: FolderIconerStorage = .default) {
        self.isPreview = isPreview; self.storage = storage
        if isPreview, let fixture = IconFixtures.package(named: "issue-14-example") {
            package = fixture; selection = fixture.document.layers.first { $0.name == "Label" }?.id
        } else { package = (try? DocumentPackage.read(from: storage.draft)) ?? DocumentPackage() }
        history = SnapshotHistory(read: { [unowned self] in package.document }, write: { [unowned self] in package.document = $0; documentChanged() })
        renderNow()
    }

    // MARK: Editing

    func edit(_ name: LocalizedStringResource, coalesceKey: String? = nil, _ change: (inout IconDocument) -> Void) {
        history.edit(String(localized: name), coalesceKey: coalesceKey, change)
    }
    func beginInteraction() { history.begin() }
    func interact(_ change: (inout IconDocument) -> Void) { history.interact(change) }
    func endInteraction(_ name: LocalizedStringResource) { history.end(String(localized: name)) }

    /// A binding into one layer. Inside an interaction (slider drag) changes coalesce; otherwise each set is one undo step.
    func binding<T: Equatable>(_ layer: Layer, _ keyPath: WritableKeyPath<Layer, T>, _ name: LocalizedStringResource, coalesce: Bool = false) -> Binding<T> {
        let id = layer.id, fallback = layer[keyPath: keyPath], key = coalesce ? "\(id)\(keyPath)" : nil
        return Binding(get: { [weak self] in self?.document[layer: id]?[keyPath: keyPath] ?? fallback }, set: { [weak self] value in
            guard let self else { return }
            if history.isInteracting { interact { $0[layer: id]?[keyPath: keyPath] = value } }
            else { edit(name, coalesceKey: key) { $0[layer: id]?[keyPath: keyPath] = value } }
        })
    }

    /// For `Slider(onEditingChanged:)`: the whole drag becomes one undo step.
    func editingChanged(_ name: LocalizedStringResource) -> (Bool) -> Void {
        { [weak self] editing in if editing { self?.beginInteraction() } else { self?.endInteraction(name) } }
    }

    func newIcon() { endTextEditing(); edit("New Icon") { $0 = .newDocument() }; selection = nil }

    func add(_ layer: Layer, _ name: LocalizedStringResource) {
        edit(name) { document in
            let above = selection.flatMap { document.index(of: $0) }.map { $0 + 1 } ?? document.layers.count
            document.layers.insert(layer, at: above)
        }
        selection = layer.id
    }

    func addText() { add(Layer(name: String(localized: "Text"), content: .text(TextContent(string: String(localized: "Text")))), "Add Text") }
    func addEmoji(_ character: String = "📁") { add(Layer(name: String(localized: "Emoji"), content: .emoji(EmojiContent(character: character))), "Add Emoji") }

    var canDuplicate: Bool { selectedLayer.map { !$0.content.isFolderBase } ?? false }
    func duplicateSelection() {
        guard let id = selection else { return }
        var copy: Layer.ID?
        edit("Duplicate Layer") { copy = $0.duplicate(id) }
        if let copy { selection = copy }
    }

    func deleteSelection() {
        guard let id = selection, let index = document.index(of: id) else { return }
        edit("Delete Layer") { $0.remove(id) }
        let layers = document.layers
        selection = layers.isEmpty ? nil : layers[min(max(index - 1, 0), layers.count - 1)].id
    }

    func moveDisplayed(_ source: IndexSet, _ destination: Int) { edit("Move Layer") { $0.moveDisplayed(fromOffsets: source, toOffset: destination) } }

    func nudge(dx: Int, dy: Int, large: Bool) {
        guard let layer = selectedLayer, !layer.locked else { return }
        edit("Nudge Layer") { $0[layer: layer.id]?.transform = CanvasGeometry.nudge(layer.transform, dx: dx, dy: dy, large: large) }
    }

    // MARK: Inline editing

    /// The text layer being edited on the canvas. Typing changes the document live; the whole edit is one undo step.
    private(set) var editingText: Layer.ID?
    /// An emoji layer whose inspector field should take focus and open the character palette.
    var pendingEmojiPicker: Layer.ID?
    @ObservationIgnored private var textBeforeEditing = ""

    /// Double-click on the canvas: text layers edit in place, emoji layers open the picker.
    func editInPlace(_ id: Layer.ID) {
        guard let layer = document[layer: id], !layer.locked else { return }
        selection = id
        switch layer.content {
        case .text(let text): endTextEditing(); textBeforeEditing = text.string; beginInteraction(); editingText = id
        case .emoji: pendingEmojiPicker = id
        default: break
        }
    }
    func editText(_ string: String) {
        guard let id = editingText else { return }
        interact { $0[layer: id]?.text.string = string }
    }
    func endTextEditing(cancel: Bool = false) {
        guard let id = editingText else { return }
        guard let current = document[layer: id]?.text.string else { editingText = nil; endInteraction("Change Text"); return }
        let final = cancel ? textBeforeEditing : CanvasGeometry.committedText(current, original: textBeforeEditing)
        if final != current { interact { $0[layer: id]?.text.string = final } }
        editingText = nil; endInteraction("Change Text")
    }

    // MARK: Images

    func chooseImage(replacing id: Layer.ID? = nil) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]; panel.allowsMultipleSelection = id == nil
        guard panel.runModal() == .OK else { return }
        if let id, let url = panel.url { replaceImage(id, with: url) } else { importImages(panel.urls) }
    }

    @discardableResult func importImages(_ urls: [URL]) -> Bool {
        var added = false
        for url in urls {
            guard let (asset, size) = importAsset(url) else { continue }
            add(Layer(name: url.deletingPathExtension().lastPathComponent, content: .image(ImageContent(asset: asset, size: size))), "Add Image"); added = true
        }
        return added
    }

    func replaceImage(_ id: Layer.ID, with url: URL) {
        guard let (asset, size) = importAsset(url), let old = document[layer: id]?.image.size else { return }
        edit("Replace Image") { $0[layer: id]?.image.asset = asset; $0[layer: id]?.image.size = CanvasSize(width: old.width, height: old.width * size.height / size.width) }
    }

    /// Assets are append-only and outside undo; writing the package drops unreferenced ones.
    private func importAsset(_ url: URL) -> (AssetID, CanvasSize)? {
        guard let data = try? Data(contentsOf: url), let pixels = ImageMetrics.orientedSize(data) else { alert = "The file is not an image FolderIconer can read."; return nil }
        let long = 0.6, aspect = pixels.width / pixels.height
        return (package.addAsset(data, pathExtension: url.pathExtension), aspect >= 1 ? CanvasSize(width: long, height: long / aspect) : CanvasSize(width: long * aspect, height: long))
    }


    // MARK: Geometry

    func contentSize(of layer: Layer) -> CGSize { measurer.contentSize(of: layer, in: package) }
    func contentSizes() -> [Layer.ID: CGSize] { Dictionary(uniqueKeysWithValues: document.layers.map { ($0.id, contentSize(of: $0)) }) }

    // MARK: Rendering and autosave

    private func documentChanged() {
        if let id = selection, document.index(of: id) == nil { selection = nil }
        renderNow(); scheduleDraftSave()
    }

    /// The canvas always renders the newest document; requests that arrive during a render collapse into one. The strip waits for a pause.
    private func renderNow() {
        pendingCanvas = package
        if !canvasRendering {
            canvasRendering = true
            Task { [renders] in
                while let next = pendingCanvas {
                    pendingCanvas = nil
                    let image = await renders.render(next, points: Self.canvasPoints)
                    canvasImage = image; previews[Self.canvasPoints] = image
                }
                canvasRendering = false
            }
        }
        stripTask?.cancel()
        let package = package, sizes = PreviewStrip.sizes.filter { $0 != Self.canvasPoints }
        stripTask = Task { [renders] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let images = await renders.render(package, sizes: sizes)
            guard !Task.isCancelled else { return }
            previews.merge(images) { $1 }
        }
    }

    private func scheduleDraftSave() {
        guard !isPreview else { return }
        saveTask?.cancel()
        saveTask = Task { try? await Task.sleep(for: .seconds(1)); if !Task.isCancelled { saveDraft() } }
    }

    func saveDraft() {
        guard !isPreview else { return }
        saveTask?.cancel()
        do { try package.write(to: storage.draft) } catch { log.error("Draft save failed: \(error.localizedDescription, privacy: .public)") }
    }
}

enum ImageMetrics {
    /// Pixel size after EXIF orientation, or nil when ImageIO cannot decode the data.
    static func orientedSize(_ data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                                                          kCGImageSourceThumbnailMaxPixelSize: 256] as CFDictionary),
              image.width > 0, image.height > 0 else { return nil }
        return CGSize(width: image.width, height: image.height)
    }
}
