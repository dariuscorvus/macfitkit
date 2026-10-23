import AppKit
import SwiftUI
import FocusFrameCore
import MacFitKitUI

/// The list of animation entries: add, switch on and off, preview one, duplicate, reorder and remove.
/// Order matters for colors: the lower entry wins.
struct AnimationEntryList: View {
    let entries: [AnimationEntry]
    let set: ([AnimationEntry]) -> Void
    let preview: (AnimationEntry) -> Void
    @State private var expanded: UUID?

    init(entries: [AnimationEntry], expanded: UUID? = nil, set: @escaping ([AnimationEntry]) -> Void, preview: @escaping (AnimationEntry) -> Void) {
        self.entries = entries; self.set = set; self.preview = preview; _expanded = State(initialValue: expanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KitSpacing.small) {
            HStack {
                Menu("Animation hinzufügen") {
                    ForEach(AnimationKind.allCases, id: \.self) { kind in
                        Button(kind.title) { let e = AnimationEntry(kind); set(entries + [e]); expanded = e.id }
                    }
                }
                .fixedSize()
                Spacer()
            }
            if entries.isEmpty { StatusMessage("Keine Animationen. Füge eine hinzu oder wähle oben ein Preset.") }
            if entries.count > AnimationEntry.softLimit {
                StatusMessage("Mehr als \(AnimationEntry.softLimit) Animationen kosten spürbar Rechenzeit, besonders bei großen Fenstern.", error: true)
            }
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                AnimationEntryRow(entry: entry, expanded: expanded == entry.id, isFirst: index == 0, isLast: index == entries.count - 1,
                    toggle: { expanded = expanded == entry.id ? nil : entry.id },
                    change: { changed in var all = entries; all[index] = changed; set(all) },
                    action: { perform($0, at: index) },
                    preview: { preview(entry) })
            }
            if entries.count > 1 { StatusMessage("Deckkraft und Stärke multiplizieren sich, Rotation addiert sich. Bei Farben gilt die untere Animation.") }
        }
    }

    enum Action { case duplicate, remove, up, down }
    private func perform(_ action: Action, at index: Int) {
        var all = entries
        switch action {
        case .duplicate: var copy = all[index]; copy.id = UUID(); all.insert(copy, at: index + 1); expanded = copy.id
        case .remove: all.remove(at: index)
        case .up where index > 0: all.swapAt(index, index - 1)
        case .down where index < all.count - 1: all.swapAt(index, index + 1)
        default: return
        }
        set(all)
    }
}

private struct AnimationEntryRow: View {
    let entry: AnimationEntry, expanded: Bool, isFirst: Bool, isLast: Bool
    let toggle: () -> Void, change: (AnimationEntry) -> Void, action: (AnimationEntryList.Action) -> Void, preview: () -> Void
    @State private var editingCurve = false

    var body: some View {
        VStack(alignment: .leading, spacing: KitSpacing.small) {
            HStack(spacing: KitSpacing.small) {
                Toggle(entry.kind.title, isOn: bind(\.enabled)).toggleStyle(.checkbox).labelsHidden()
                Button(action: toggle) {
                    HStack(spacing: 4) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(.secondary)
                        Text(entry.kind.title).fontWeight(.medium)
                        Text(entry.summary).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityHint(expanded ? "Einstellungen ausblenden" : "Einstellungen anzeigen")
                Spacer()
                Button(action: preview) { Image(systemName: "play.fill") }.help("Nur diese Animation abspielen").accessibilityLabel("Vorschau")
                Menu {
                    Button("Duplizieren") { action(.duplicate) }
                    Button("Nach oben") { action(.up) }.disabled(isFirst)
                    Button("Nach unten") { action(.down) }.disabled(isLast)
                    Divider()
                    Button("Entfernen", role: .destructive) { action(.remove) }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Aktionen")
            }
            .opacity(entry.enabled ? 1 : 0.55)
            if expanded { editor.padding(.leading, 24) }
        }
        .padding(KitSpacing.small)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }

    @ViewBuilder private var editor: some View {
        VStack(alignment: .leading, spacing: KitSpacing.small) {
            ChoiceRow("Effekt", selection: Binding(get: { entry.kind }, set: { kind in var e = AnimationEntry(kind, trigger: entry.trigger); e.id = entry.id; e.enabled = entry.enabled; change(e) }),
                      options: AnimationKind.allCases.map { ($0.title, $0) })
            ChoiceRow("Auslöser", selection: bind(\.trigger), options: [("Beim Fokuswechsel", .focus), ("Dauerhaft", .continuous)])
            SliderRow(entry.kind.durationTitle, value: bind(\.duration), in: 0.2...30, unit: "s")
            SliderRow("Verzögerung", value: bind(\.delay), in: 0...10, unit: "s")
            if entry.trigger == .focus { SliderRow("Durchläufe", value: bind(\.repeats), in: 0.05...10) }
            if entry.kind.hasTarget {
                ChoiceRow("Wirkt auf", selection: bind(\.target), options: [("Alles", .all), ("Rahmen", .frame), ("Leuchten", .light), ("Schatten", .shadow)])
            }
            if entry.kind.hasStrength { SliderRow("Stärke", value: percent(\.strength), in: 0...100, unit: "%") }
            if entry.kind == .opacityPulse || entry.kind == .opacityBlink {
                SliderRow("Minimum", value: percent(\.minimum), in: 0...100, unit: "%")
                SliderRow("Maximum", value: percent(\.maximum), in: 0...100, unit: "%")
            }
            if entry.kind == .gradientRotation { ToggleRow("Im Uhrzeigersinn", isOn: bind(\.clockwise)) }
            if entry.kind == .focusPulse { ToggleRow("Nachschwingen", isOn: bind(\.bounce)) }
            HStack {
                Text("Bewegungsverlauf"); Spacer()
                Button(entry.curve.title) { editingCurve = true }
                    .popover(isPresented: $editingCurve) { TimingCurveEditor(curve: entry.curve) { curve in var e = entry; e.curve = curve; change(e) }.padding(KitSpacing.medium) }
            }
            if let requirement = entry.kind.requirement { StatusMessage(requirement) }
        }
    }

    private func bind<T>(_ key: WritableKeyPath<AnimationEntry, T>) -> Binding<T> {
        Binding(get: { entry[keyPath: key] }, set: { var e = entry; e[keyPath: key] = $0; change(e) })
    }
    private func percent(_ key: WritableKeyPath<AnimationEntry, Double>) -> Binding<Double> {
        Binding(get: { entry[keyPath: key] * 100 }, set: { var e = entry; e[keyPath: key] = $0 / 100; change(e) })
    }
}

extension AnimationKind {
    var title: String {
        switch self {
        case .focusPulse: "Fokusimpuls"; case .runner: "Lichtläufer"; case .draw: "Rahmen zeichnen"; case .breathe: "Atmen"
        case .colorFlow: "Farbfluss"; case .gradientRotation: "Verlaufsrotation"; case .opacityPulse: "Deckkraft pulsieren"
        case .opacityBlink: "Deckkraft blinken"; case .metalReflection: "Metall-Lichtreflex"
        }
    }
    var durationTitle: String {
        switch self { case .gradientRotation: "Umlaufdauer"; case .opacityPulse, .opacityBlink: "Zyklusdauer"; default: "Dauer je Durchlauf" }
    }
    /// What else must be switched on for the entry to show anything.
    var requirement: String? {
        switch self {
        case .colorFlow, .gradientRotation: "Braucht einen eingeschalteten Farbverlauf und die Oberfläche ‘Farbe / Farbverlauf’."
        case .metalReflection: "Braucht die Oberfläche Gold oder Chrom."
        case .breathe, .opacityPulse, .opacityBlink: "Wirkt auf Leuchten oder Schatten nur, wenn sie eingeschaltet sind."
        default: nil
        }
    }
}

extension AnimationEntry {
    var summary: String {
        let trigger = self.trigger == .focus ? "Fokuswechsel" : "dauerhaft"
        return "· \(trigger), \(duration.formatted(.number.precision(.fractionLength(0...1)))) s" + (delay > 0 ? ", +\(delay.formatted(.number.precision(.fractionLength(0...1)))) s" : "")
    }
}
