import SwiftUI

struct ContentView: View {
    @Bindable var controller: DockPreviewController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "macwindow.on.rectangle").font(.system(size: 32)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("DockPreview").font(.title.bold())
                    Text("Deine Fenster direkt am Dock.").foregroundStyle(.secondary)
                }
            }
            Text("Bewege den Zeiger kurz über ein App-Symbol im Dock. Klicke auf eine Vorschau, um genau dieses Fenster zu öffnen.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                permissionRow("Bedienungshilfen", detail: "Erkennt Dock-Symbole und aktiviert Fenster.",
                              granted: controller.accessibilityGranted, action: controller.requestAccessibility)
                Divider()
                permissionRow("Bildschirmaufnahme", detail: "Erstellt die Fensterminiaturen lokal auf deinem Mac.",
                              granted: controller.screenRecordingGranted, action: controller.requestScreenRecording)
            }.padding(16).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            Text("Falls macOS nach einer Freigabe einen Neustart verlangt, DockPreview beenden und erneut öffnen.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle("Fenstervorschauen aktiv", isOn: $controller.enabled)
            Text(controller.status).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !controller.lastAction.isEmpty { Text(controller.lastAction).font(.caption).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Text("DockPreview bleibt in der Menüleiste aktiv.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Erneut prüfen", action: controller.refreshPermissions)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func permissionRow(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .accessibilityLabel(granted ? "Freigegeben" : "Freigabe fehlt")
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted { Button("Freigeben …", action: action) }
        }
    }
}
