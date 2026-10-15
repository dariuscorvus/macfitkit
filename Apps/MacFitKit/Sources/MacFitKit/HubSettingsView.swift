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
                if controller.available.isEmpty { EmptyState("Keine Tools gefunden", detail: "Installiere FocusFrame, LiveDesktop, DockPreview oder UniversalPiP.") }
                ForEach(controller.available) { tool in
                    SettingsSection(tool.name) {
                        StatusMessage(controller.description(tool))
                        HStack {
                            if controller.running(tool) == nil {
                                Button("Starten") { controller.start(tool) }.disabled(!controller.supported(tool))
                            } else if let status = controller.bridge.statuses[tool] {
                                Button(status.enabled ? "Pausieren" : "Aktivieren") { controller.bridge.send(.setEnabled(!status.enabled), to: tool) }
                                Button("Einstellungen …") { controller.bridge.send(.openSettings, to: tool) }
                                Button("Beenden") { controller.bridge.send(.quit, to: tool) }
                            } else { Button("Status erneut prüfen") { controller.bridge.send(.requestStatus, to: tool) } }
                        }
                    }
                }
                if !controller.bridge.lastError.isEmpty { StatusMessage(controller.bridge.lastError, error: true) }
                if !controller.message.isEmpty { StatusMessage(controller.message, error: true) }
                Button("Erneut suchen", action: controller.refresh)
            case "general": SettingsSection("Menüleiste") {
                Text("Während MacFitKit verbunden ist, bleiben die eigenen Symbole der Tools ausgeblendet. Beim Beenden laufen die Tools weiter und zeigen ihre Symbole wieder.")
                LoginItemRow().disabled(CommandLine.arguments.contains("--ui-preview") || controller.isMenuPreview)
            }
            default: AppInfoSection("MacFitKit")
            }
        }
    }
}
