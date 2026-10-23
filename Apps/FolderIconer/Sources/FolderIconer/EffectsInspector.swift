import FolderIconerCore
import SwiftUI

/// Five fixed effect rows, one per kind. Sizes are shown as percent of the canvas edge.
struct EffectsInspector: View {
    let model: EditorModel, layer: Layer

    var body: some View {
        Section("Effects") {
            Toggle("Outline", isOn: model.binding(layer, \.outlineEffect.enabled, "Change Outline"))
            if layer.outlineEffect.enabled {
                ColorPicker("Color", selection: model.binding(layer, \.outlineEffect.color, "Change Outline", coalesce: true).cgColor)
                EffectSlider(model: model, layer: layer, title: "Width", path: \.outlineEffect.width, range: 0...5, undo: "Change Outline")
            }
            ShadowRows(model: model, layer: layer, title: "Drop Shadow", effect: \.dropShadowEffect, undo: "Change Drop Shadow")
            GlowRows(model: model, layer: layer, title: "Outer Glow", effect: \.outerGlowEffect, undo: "Change Outer Glow", spread: true)
            ShadowRows(model: model, layer: layer, title: "Inner Shadow", effect: \.innerShadowEffect, undo: "Change Inner Shadow")
            GlowRows(model: model, layer: layer, title: "Inner Glow", effect: \.innerGlowEffect, undo: "Change Inner Glow", spread: false)
        }
    }
}

private struct EffectSlider: View {
    let model: EditorModel, layer: Layer, title: LocalizedStringResource, path: WritableKeyPath<Layer, Double>, range: ClosedRange<Double>, undo: LocalizedStringResource
    var body: some View {
        SliderRow(title: title, value: model.binding(layer, path, undo).scaled(100), range: range, format: .number.precision(.fractionLength(0...1)), editingChanged: model.editingChanged(undo))
    }
}

private struct ShadowRows: View {
    let model: EditorModel, layer: Layer, title: LocalizedStringResource, effect: WritableKeyPath<Layer, LayerEffect.Shadow>, undo: LocalizedStringResource
    var body: some View {
        Toggle(isOn: model.binding(layer, effect.appending(path: \.enabled), undo)) { Text(title) }
        if layer[keyPath: effect].enabled {
            ColorPicker("Color", selection: model.binding(layer, effect.appending(path: \.color), undo, coalesce: true).cgColor)
            EffectSlider(model: model, layer: layer, title: "Offset X", path: effect.appending(path: \.dx), range: -10...10, undo: undo)
            EffectSlider(model: model, layer: layer, title: "Offset Y", path: effect.appending(path: \.dy), range: -10...10, undo: undo)
            EffectSlider(model: model, layer: layer, title: "Blur", path: effect.appending(path: \.blur), range: 0...10, undo: undo)
        }
    }
}

private struct GlowRows: View {
    let model: EditorModel, layer: Layer, title: LocalizedStringResource, effect: WritableKeyPath<Layer, LayerEffect.Glow>, undo: LocalizedStringResource, spread: Bool
    var body: some View {
        Toggle(isOn: model.binding(layer, effect.appending(path: \.enabled), undo)) { Text(title) }
        if layer[keyPath: effect].enabled {
            ColorPicker("Color", selection: model.binding(layer, effect.appending(path: \.color), undo, coalesce: true).cgColor)
            EffectSlider(model: model, layer: layer, title: "Blur", path: effect.appending(path: \.blur), range: 0...10, undo: undo)
            if spread { EffectSlider(model: model, layer: layer, title: "Spread", path: effect.appending(path: \.spread), range: 0...5, undo: undo) }
        }
    }
}

/// One effect of each kind. Reading a missing kind gives a disabled default; writing replaces the first of that kind or appends.
extension Layer {
    var outlineEffect: LayerEffect.Outline {
        get { effects.lazy.compactMap { if case .outline(let e) = $0 { e } else { nil } }.first ?? .init(enabled: false, color: .black, width: 0.01) }
        set { setEffect(.outline(newValue)) }
    }
    var dropShadowEffect: LayerEffect.Shadow {
        get { effects.lazy.compactMap { if case .dropShadow(let e) = $0 { e } else { nil } }.first ?? .init(enabled: false, color: RGBAColor(r: 0, g: 0, b: 0, a: 0.5), dx: 0.01, dy: 0.02, blur: 0.02) }
        set { setEffect(.dropShadow(newValue)) }
    }
    var innerShadowEffect: LayerEffect.Shadow {
        get { effects.lazy.compactMap { if case .innerShadow(let e) = $0 { e } else { nil } }.first ?? .init(enabled: false, color: RGBAColor(r: 0, g: 0, b: 0, a: 0.5), dx: 0.005, dy: 0.01, blur: 0.01) }
        set { setEffect(.innerShadow(newValue)) }
    }
    var outerGlowEffect: LayerEffect.Glow {
        get { effects.lazy.compactMap { if case .outerGlow(let e) = $0 { e } else { nil } }.first ?? .init(enabled: false, color: .white, blur: 0.03) }
        set { setEffect(.outerGlow(newValue)) }
    }
    var innerGlowEffect: LayerEffect.Glow {
        get { effects.lazy.compactMap { if case .innerGlow(let e) = $0 { e } else { nil } }.first ?? .init(enabled: false, color: .white, blur: 0.02) }
        set { setEffect(.innerGlow(newValue)) }
    }

    private mutating func setEffect(_ effect: LayerEffect) {
        if let index = effects.firstIndex(where: { $0.typeName == effect.typeName }) { effects[index] = effect } else { effects.append(effect) }
    }
}
