import AppKit
import FolderIconerCore
import SwiftUI

/// One inspector section per content kind. New kinds add a case here.
struct ContentInspector: View {
    let model: EditorModel, layer: Layer

    var body: some View {
        switch layer.content {
        case .folderBase: FolderBaseInspector(model: model, layer: layer)
        case .image: ImageInspector(model: model, layer: layer)
        case .text: TextInspector(model: model, layer: layer)
        case .emoji: EmojiInspector(model: model, layer: layer)
        }
    }
}

struct FolderBaseInspector: View {
    let model: EditorModel, layer: Layer

    var body: some View {
        Section("Folder") {
            Picker("Style", selection: model.binding(layer, \.folderBase.style, "Change Folder Style")) {
                ForEach(FolderBase.Style.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            if layer.folderBase.style == .color {
                ColorPicker("Color", selection: model.binding(layer, \.folderBase.color, "Change Folder Color", coalesce: true).cgColor, supportsOpacity: false)
            }
        }
    }
}

struct ImageInspector: View {
    let model: EditorModel, layer: Layer
    private var image: ImageContent { layer.image }

    var body: some View {
        Section("Image") {
            LabeledContent("Source") { Button("Replace…") { model.chooseImage(replacing: layer.id) } }
            Picker("Fit", selection: model.binding(layer, \.image.fit, "Change Fit")) {
                ForEach(ImageContent.Fit.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            NumberRow(title: "Width", value: model.binding(layer, \.image.size.width, "Resize Image").scaled(100), unit: "%")
            NumberRow(title: "Height", value: model.binding(layer, \.image.size.height, "Resize Image").scaled(100), unit: "%")
        }
        if image.fit == .crop {
            let crop = model.binding(layer, \.image.cropRect, "Change Crop")
            Section("Crop") {
                NumberRow(title: "X", value: crop.x.scaled(100), unit: "%")
                NumberRow(title: "Y", value: crop.y.scaled(100), unit: "%")
                NumberRow(title: "Width", value: crop.width.scaled(100), unit: "%")
                NumberRow(title: "Height", value: crop.height.scaled(100), unit: "%")
            }
        }
        Section("Adjustments") {
            SliderRow(title: "Hue", value: model.binding(layer, \.image.adjust.hue, "Change Hue"), range: -180...180,
                      format: .number.precision(.fractionLength(0)), editingChanged: model.editingChanged("Change Hue"))
            SliderRow(title: "Saturation", value: model.binding(layer, \.image.adjust.saturation, "Change Saturation"), range: 0...2, editingChanged: model.editingChanged("Change Saturation"))
            SliderRow(title: "Brightness", value: model.binding(layer, \.image.adjust.brightness, "Change Brightness"), range: -1...1, editingChanged: model.editingChanged("Change Brightness"))
            SliderRow(title: "Blur", value: model.binding(layer, \.image.adjust.blur, "Change Blur").scaled(100), range: 0...5, editingChanged: model.editingChanged("Change Blur"))
            Toggle("Colorize", isOn: model.binding(layer, \.image.colorizeEnabled, "Colorize"))
            if image.adjust.colorize != nil {
                ColorPicker("Color", selection: model.binding(layer, \.image.colorizeColor, "Change Colorize Color", coalesce: true).cgColor, supportsOpacity: false)
                SliderRow(title: "Intensity", value: model.binding(layer, \.image.colorizeIntensity, "Change Intensity"), range: 0...1, editingChanged: model.editingChanged("Change Intensity"))
            }
        }
    }
}

struct EmojiInspector: View {
    let model: EditorModel, layer: Layer
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        Section {
            HStack {
                TextField(text: $draft) { Text("Emoji") }.focused($focused).font(.title2).frame(width: 64)
                Button("Emoji & Symbols") { focused = true; NSApp.orderFrontCharacterPalette(nil) }
            }
            SliderRow(title: "Size", value: model.binding(layer, \.emoji.size, "Resize Emoji").scaled(100), range: 5...100,
                      format: .number.precision(.fractionLength(0)), editingChanged: model.editingChanged("Resize Emoji"))
        } header: { Text("Emoji") } footer: {
            Text("Apple Color Emoji is a bitmap font. Emoji larger than about 15 % of the canvas look soft in the 1024 px icon.").foregroundStyle(.secondary)
        }
        .onAppear { draft = layer.emoji.character; openPickerIfRequested() }
        .onChange(of: model.pendingEmojiPicker) { openPickerIfRequested() }
        .onChange(of: layer.emoji.character) { if !focused { draft = layer.emoji.character } }
        .onChange(of: draft) {
            let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            // The character palette appends, so the last grapheme is the new pick.
            let pick = EmojiContent.accepts(text) ? text : text.last.map(String.init) ?? ""
            guard EmojiContent.accepts(pick), pick != layer.emoji.character else { return }
            model.edit("Change Emoji") { $0[layer: layer.id]?.emoji.character = pick }
            draft = pick
        }
        .onChange(of: focused) { if !focused { draft = layer.emoji.character } }
    }

    /// A canvas double-click on this emoji focuses the field and opens the character palette.
    private func openPickerIfRequested() {
        guard model.pendingEmojiPicker == layer.id else { return }
        model.pendingEmojiPicker = nil; focused = true; NSApp.orderFrontCharacterPalette(nil)
    }
}

extension ImageContent {
    var cropRect: NormalizedRect {
        get { crop ?? NormalizedRect(x: 0, y: 0, width: 1, height: 1) }
        set { crop = newValue }
    }
    var colorizeEnabled: Bool {
        get { adjust.colorize != nil }
        set { adjust.colorize = newValue ? (adjust.colorize ?? Colorize(color: RGBAColor(r: 0.36, g: 0.74, b: 0.92))) : nil }
    }
    var colorizeColor: RGBAColor {
        get { adjust.colorize?.color ?? .white }
        set { adjust.colorize?.color = newValue }
    }
    var colorizeIntensity: Double {
        get { adjust.colorize?.intensity ?? 1 }
        set { adjust.colorize?.intensity = newValue }
    }
}
