import AppKit
import SwiftUI
import UniversalPiP
import MacFitKitPlatform
import MacFitKitUI

struct PiPSettingsView: View {
    @Bindable var controller: PiPAppController
    var body: some View {
        SettingsShell("UniversalPiP", pages: [.init("source", "Fenster auswählen", "pip"), .permissions, .general, .info]) { page in
            switch page {
            case "source":
                SettingsSection("Live-Vorschau neben dem Original") {
                    Text("Wähle ein Fenster für eine frei platzierbare Vorschau. Das gesamte Bild wird proportional verkleinert. Das Original bleibt unabhängig bedienbar.")
                    Text("UTM-Fenster stehen zuerst. Bediene die VM weiterhin im Originalfenster.").foregroundStyle(.secondary)
                    StatusMessage(controller.session.state.label)
                    if !controller.session.message.isEmpty { StatusMessage(controller.session.message, error: true) }
                }
                if controller.isPreview { StatusMessage("Oberflächenvorschau – Aufnahme und Freigabeänderungen sind deaktiviert.") }
                else if !controller.permissionGranted {
                    SettingsSection("Bildschirmaufnahme erforderlich") {
                        Text("UniversalPiP benötigt eine eigene Freigabe, um das ausgewählte Fenster lokal anzuzeigen. Es werden keine Aufnahmen gespeichert oder übertragen.")
                        Button("Bildschirmaufnahme freigeben …", action: controller.requestPermission)
                        Button("Erneut prüfen", action: controller.refresh)
                    }
                } else {
                    SettingsSection("Quellfenster") {
                        if controller.loading { ProgressView("Fenster werden gesucht …") }
                        if controller.sources.isEmpty && !controller.loading {
                            Text("Keine erfassbaren Fenster gefunden. Öffne das Originalfenster und aktualisiere die Liste.")
                        }
                        ForEach(controller.sources) { source in
                            Button { controller.selectedID = source.id } label: {
                                HStack {
                                    Image(systemName: controller.selectedID == source.id ? "checkmark.circle.fill" : "circle")
                                    VStack(alignment: .leading) {
                                        Text(source.appName).fontWeight(.medium)
                                        Text(source.title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(source.appName + ": " + source.title)
                                .accessibilityValue(controller.selectedID == source.id ? "Ausgewählt" : "Nicht ausgewählt")
                        }
                        HStack {
                            Button("Fensterliste aktualisieren", action: controller.refresh)
                            Button("Vorschau starten", action: controller.startSelected).buttonStyle(.borderedProminent)
                                .disabled(controller.selectedID == nil || controller.loading)
                        }
                    }
                }
            case "permissions":
                SettingsSection("Bildschirmaufnahme") {
                    PermissionRow("Ausgewähltes Fenster anzeigen", detail: "Nur lokale Live-Vorschau. Kein Audio oder Mikrofon. Die Live-Vorschau benötigt keine Bedienungshilfen.", granted: controller.permissionGranted, action: controller.requestPermission)
                        .disabled(controller.isPreview)
                    Button("Datenschutzeinstellungen öffnen …") { PrivacyAccess.openSettings("Privacy_ScreenCapture") }.disabled(controller.isPreview)
                    Button("Erneut prüfen", action: controller.refresh)
                    PermissionRow("Originalfenster fokussieren", detail: "Optional, nur für die Fokus-Taste im Hover-HUD. Keine Weiterleitung von Maus oder Tastatur.", granted: controller.focusPermissionGranted, action: controller.requestFocusPermission)
                        .disabled(controller.isPreview)
                    Text("Falls die Aufnahme nach einer neuen Freigabe noch nicht startet, UniversalPiP beenden und neu öffnen.").foregroundStyle(.secondary)
                }
            case "general":
                SettingsSection("Verhalten") {
                    Text("Hover-HUD im Bild · ausblendbare Titelleiste · eine Vorschau gleichzeitig · bis zu 30 Bilder pro Sekunde · vollständiges Bild ohne Zuschnitt")
                    Text("Position und Größe werden gespeichert. Nach dem Start beginnt keine automatische Aufnahme. Minimierte Quellen können vorübergehend kein Live-Bild liefern.")
                    LoginItemRow().disabled(controller.isPreview)
                }
            default: AppInfoSection("UniversalPiP")
            }
            if !controller.message.isEmpty { StatusMessage(controller.message, error: true) }
        }.onAppear { controller.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in controller.refresh() }
    }
}
