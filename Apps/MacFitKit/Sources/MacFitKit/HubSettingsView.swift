import SwiftUI
import MacFitKitCore
import MacFitKitPlatform
import MacFitKitUI

struct HubSettingsView: View {
    let controller: HubController
    var body: some View {
        SettingsShell("MacFitKit", pages: [.init("tools", "Tools", "square.grid.2x2"), .general, .info]) { page in
            switch page {
            case "tools":
                if controller.isMenuPreview { StatusMessage("Menü-Test mit getrennten Test-Tools") }
                Text("Installiere die Tools direkt nach ~/Applications und starte sie anschließend hier.")
                    .foregroundStyle(.secondary)
                ForEach(controller.catalog) { tool in
                    SettingsSection(tool.name) {
                        StatusMessage(controller.description(tool))
                        Text(controller.versionDescription(tool)).font(.callout).foregroundStyle(.secondary)
                        if !controller.updateDescription(tool).isEmpty { Text(controller.updateDescription(tool)).font(.callout) }
                        if let release = controller.publishedReleases[tool] {
                            Link("Release öffnen …", destination: release.page)
                            if let current = controller.installedVersions[tool], release.version > current, release.downloadURL == nil {
                                Text("Dieses Release enthält kein prüfbares ZIP-Paket für ein direktes Update.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let version = controller.updateVersion(tool) {
                            Button("Update installieren · " + version.display) { controller.update(tool) }
                                .disabled(!controller.canUpdate(tool))
                            Text("Die alte App und ihre Einstellungen werden vor dem Austausch gesichert. Ein laufendes Tool wird beendet und danach neu gestartet.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if controller.installing == tool { ProgressView(controller.operationDescription).controlSize(.small) }
                        HStack {
                            if !controller.installed(tool) {
                                Button(controller.installing == tool ? "Wird installiert …" : "Installieren") { controller.install(tool) }
                                    .disabled(!controller.canInstall(tool))
                                if controller.installing == tool { ProgressView().controlSize(.small) }
                            } else if controller.running(tool) == nil {
                                Button("Starten") { controller.start(tool) }.disabled(!controller.supported(tool))
                            } else if let status = controller.bridge.statuses[tool] {
                                Button(status.enabled ? "Pausieren" : "Aktivieren") { controller.bridge.send(.setEnabled(!status.enabled), to: tool) }
                                Button("Einstellungen …") { controller.bridge.send(.openSettings, to: tool) }
                                Button("Beenden") { controller.bridge.send(.quit, to: tool) }
                            } else { Button("Status erneut prüfen") { controller.bridge.send(.requestStatus, to: tool) } }
                            if controller.installed(tool) {
                                Button("Deinstallieren …", role: .destructive) { controller.requestUninstall(tool) }
                                    .disabled(controller.installationDisabled)
                            }
                        }.disabled(controller.installing != nil)
                    }
                }
                if !controller.bridge.lastError.isEmpty { StatusMessage(controller.bridge.lastError, error: true) }
                if !controller.message.isEmpty { StatusMessage(controller.message) }
                if let backup = controller.lastBackup { Link("Backup im Finder öffnen", destination: backup) }
                HStack {
                    Button("Erneut suchen", action: controller.refresh)
                    Button(controller.checkingUpdates ? "Updates werden geprüft …" : "Nach Updates suchen", action: controller.checkForUpdates)
                        .disabled(controller.checkingUpdates || controller.installationDisabled)
                    if controller.checkingUpdates { ProgressView().controlSize(.small) }
                }
                StatusMessage(controller.updateCheckMessage, error: controller.updateCheckFailed)
            case "general": SettingsSection("Menüleiste") {
                Text("Während MacFitKit verbunden ist, bleiben die eigenen Symbole der Tools ausgeblendet. Beim Beenden laufen die Tools weiter und zeigen ihre Symbole wieder.")
                LoginItemRow().disabled(CommandLine.arguments.contains("--ui-preview") || controller.isMenuPreview)
            }
            default: AppInfoSection("MacFitKit")
            }
        }.alert("\(controller.pendingRemoval?.name ?? "Tool") deinstallieren?", isPresented: Binding(
            get: { controller.pendingRemoval != nil }, set: { if !$0 { controller.pendingRemoval = nil } })) {
                if let tool = controller.pendingRemoval {
                    Button("In den Papierkorb verschieben", role: .destructive) { controller.uninstall(tool) }
                }
                Button("Abbrechen", role: .cancel) { controller.pendingRemoval = nil }
            } message: { Text(controller.removalDescription) }
    }
}
