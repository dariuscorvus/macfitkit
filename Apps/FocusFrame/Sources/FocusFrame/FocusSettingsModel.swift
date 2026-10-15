import AppKit
import SwiftUI
import UniformTypeIdentifiers
import FocusFrameCore
import MacFitKitPlatform

@MainActor
final class FocusSettingsModel: ObservableObject {
    let store: PreferencesStore
    weak var window: NSWindow?
    var toggleFrame: (() -> Void)?
    var openDiagnostics: (() -> Void)?
    var testFocus: (() -> Void)?
    @Published var frameEnabled = true
    @Published var shortcutRegistered = false
    @Published var shortcutPresses = 0
    @Published var playToken = 0
    @Published var permissionGranted = PrivacyAccess.accessibilityGranted
    init(store: PreferencesStore) { self.store = store }
    func mutate(_ change: (inout Appearance) -> Void) {
        var appearance = store.value.appearance; change(&appearance)
        store.value.appearance = appearance.normalized; objectWillChange.send()
    }
    func configuration<T>(_ key: WritableKeyPath<Configuration, T>) -> Binding<T> {
        Binding(get: { self.store.value[keyPath: key] }, set: {
            self.store.value[keyPath: key] = $0; self.store.value = self.store.value.normalized; self.objectWillChange.send()
        })
    }
    func refresh() { permissionGranted = PrivacyAccess.accessibilityGranted; objectWillChange.send() }
    func saveProfile() {
        let alert = NSAlert(); alert.messageText = "Darstellung speichern"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24)); field.placeholderString = "Profilname"
        alert.accessoryView = field; alert.addButton(withTitle: "Speichern"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = String(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !name.isEmpty else { return }
        if let i = store.profiles.firstIndex(where: { $0.name == name }) { store.profiles[i].appearance = store.value.appearance.normalized }
        else { store.profiles.append(AppearanceProfile(name: name, appearance: store.value.appearance.normalized)) }
        objectWillChange.send()
    }
    func exportPreferences() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "FocusFrame-Einstellungen.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(PortablePreferences(configuration: store.value.normalized, profiles: store.profiles)).write(to: url, options: .atomic)
        } catch { showError(error.localizedDescription) }
    }
    func importPreferences() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url); guard data.count < 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let document = try JSONDecoder().decode(PortablePreferences.self, from: data)
            guard document.version == 1, document.profiles.count <= 100 else { throw CocoaError(.coderReadCorrupt) }
            store.value = document.configuration.normalized
            if !document.profiles.isEmpty { store.profiles = document.profiles.map { AppearanceProfile(name: String($0.name.prefix(80)), appearance: $0.appearance.normalized) } }
            objectWillChange.send()
        } catch { showError(error.localizedDescription) }
    }
    func addExcludedApp() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.applicationBundle]; panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.prompt = "Ausschließen"
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
            self.store.value.excludedApps = Array(Set(self.store.value.excludedApps + [id])).sorted(); self.objectWillChange.send()
        }
    }
    func showError(_ text: String) {
        let alert = NSAlert(); alert.messageText = "Die Einstellung konnte nicht geändert werden."; alert.informativeText = text
        if let window { alert.beginSheetModal(for: window) }
    }
    func resetAppearance() {
        mutate { a in let d = Appearance(); a.red=d.red; a.green=d.green; a.blue=d.blue
            a.opacity=d.opacity; a.width=d.width; a.radius=d.radius; a.gap=d.gap; a.placement=d.placement }
    }
}
