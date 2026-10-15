import SwiftUI
import MacFitKitUI

struct ContentView: View {
    @Bindable var controller: DockPreviewController
    var body: some View {
        SettingsShell("DockPreview", pages: [.general, .permissions, .info]) { page in
            switch page {
            case "general":
                SettingsSection("Fenstervorschauen") {
                    ToggleRow("Fenstervorschauen aktiv", isOn: $controller.enabled)
                    Text("Bewege den Zeiger kurz über ein App-Symbol im Dock. Klicke auf eine Vorschau, um genau dieses Fenster zu öffnen.")
                    StatusMessage(controller.status)
                    if !controller.lastAction.isEmpty { StatusMessage(controller.lastAction) }
                    Text("DockPreview bleibt in der Menüleiste aktiv.").font(.caption).foregroundStyle(.secondary)
                }
                SettingsSection("Anmeldestart") { LoginItemRow().disabled(CommandLine.arguments.contains("--ui-preview")) }
            case "permissions":
                SettingsSection("Fensterzugriff") {
                    PermissionRow("Bedienungshilfen", detail: "Erkennt Dock-Symbole und aktiviert Fenster.", granted: controller.accessibilityGranted, action: controller.requestAccessibility).disabled(CommandLine.arguments.contains("--ui-preview"))
                    PermissionRow("Bildschirmaufnahme", detail: "Erstellt die Fensterminiaturen lokal auf deinem Mac.", granted: controller.screenRecordingGranted, action: controller.requestScreenRecording)
                        .disabled(controller.requestingScreenRecording || CommandLine.arguments.contains("--ui-preview"))
                    if !controller.screenRecordingMessage.isEmpty { StatusMessage(controller.screenRecordingMessage) }
                    if !controller.screenRecordingGranted {
                        HStack {
                            Button("Aufnahme-Einstellungen", action: controller.showScreenRecordingSettings)
                            Button("App im Finder zeigen", action: controller.showCurrentApp)
                        }
                    }
                    StatusMessage("Falls macOS nach einer Freigabe einen Neustart verlangt, DockPreview beenden und erneut öffnen.")
                    Button("Erneut prüfen", action: controller.refreshPermissions)
                }
            default: AppInfoSection("DockPreview")
            }
        }
    }
}
