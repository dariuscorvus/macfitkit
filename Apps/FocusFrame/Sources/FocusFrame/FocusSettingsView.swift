import AppKit
import SwiftUI
import FocusFrameCore
import MacFitKitUI
import MacFitKitPlatform

struct FocusSettingsView: View {
    @ObservedObject var model: FocusSettingsModel
    var store: PreferencesStore { model.store }
    static let pages: [SettingsPage] = [
        .init("appearance", "Darstellung", "viewfinder"), .init("light", "Leuchten", "lightbulb"),
        .init("shadow", "Schatten", "square.on.square"), .init("gradient", "Farbverlauf", "paintpalette"),
        .init("animation", "Animationen", "waveform.path"), .general,
        .init("exclusions", "App-Ausnahmen", "app.badge"), .permissions, .info
    ]
    var body: some View {
        SettingsShell("FocusFrame", pages: Self.pages) { page in
            switch page {
            case "appearance": appearancePage()
            case "light": lightPage()
            case "shadow": shadowPage()
            case "gradient": gradientPage()
            case "animation": animationPage()
            case "general": behaviorPage
            case "exclusions": exclusionsPage
            case "permissions": SettingsSection("Bedienungshilfen") {
                PermissionRow("Bedienungshilfen", detail: "Erkennt das aktive Fenster und folgt seiner Position.", granted: model.permissionGranted,
                    action: PrivacyAccess.requestAccessibility)
                Button("Erneut prüfen", action: model.refresh)
            }
            default: AppInfoSection("FocusFrame")
            }
        }.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refresh() }
    }
    var behaviorPage: some View {
        VStack(spacing: KitSpacing.group) {
            SettingsSection("Rahmen") {
                ToggleRow("Rahmen aktiv", isOn: Binding(get: { model.frameEnabled }, set: { if $0 != model.frameEnabled { model.toggleFrame?() } }))
                ToggleRow("Rahmen im Vollbild ausblenden", isOn: model.configuration(\.hideInFullScreen))
                ToggleRow("Animationen im Stromsparmodus aussetzen", isOn: model.configuration(\.savePower))
                Button("Diagnose …") { model.openDiagnostics?() }
            }
            SettingsSection("Tastenkürzel") {
                ToggleRow("Tastenkürzel aktivieren", isOn: model.configuration(\.shortcutEnabled))
                ForEach(Array(zip(["Control", "Option", "Command", "Shift"], [UInt32(4096), 2048, 256, 512])), id: \.0) { label, mask in
                    ToggleRow(label, isOn: Binding(get: { store.value.shortcutModifiers & mask != 0 }, set: { enabled in
                        let next = enabled ? store.value.shortcutModifiers | mask : store.value.shortcutModifiers & ~mask
                        if next != 0 { store.value.shortcutModifiers = next; model.objectWillChange.send() }
                    }))
                }
                ChoiceRow("Taste", selection: model.configuration(\.shortcutKeyCode), options: Self.keys)
                StatusMessage(model.shortcutRegistered ? "Registriert · Tastendrücke: \(model.shortcutPresses) · Rahmen: \(model.frameEnabled ? "aktiv" : "pausiert")" : "Tastenkürzel ist ausgeschaltet.")
            }
            SettingsSection("Anmeldestart") { LoginItemRow() }
        }
    }
    var exclusionsPage: some View {
        SettingsSection("Ausgeschlossene Apps") {
            if store.value.excludedApps.isEmpty { StatusMessage("Für alle Apps aktiviert.") }
            ForEach(store.value.excludedApps, id: \.self) { id in
                SettingRow(NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { FileManager.default.displayName(atPath: $0.path) } ?? id) {
                    Button("Entfernen") { store.value.excludedApps.removeAll { $0 == id }; model.objectWillChange.send() }
                }
            }
            Button("App hinzufügen …", action: model.addExcludedApp)
        }
    }
    static let keys: [(String, UInt32)] = [("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),("H",4),("I",34),("J",38),("K",40),("L",37),("M",46),("N",45),("O",31),("P",35),("Q",12),("R",15),("S",1),("T",17),("U",32),("V",9),("W",13),("X",7),("Y",16),("Z",6),("0",29),("1",18),("2",19),("3",20),("4",21),("5",23),("6",22),("7",26),("8",28),("9",25)]
}
