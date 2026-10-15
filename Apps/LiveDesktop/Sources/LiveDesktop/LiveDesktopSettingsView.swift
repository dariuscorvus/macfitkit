import AppKit
import SwiftUI
import MacFitKitUI

struct LiveDesktopSettingsView: View {
    @ObservedObject var controller: WallpaperController
    var body: some View {
        SettingsShell("LiveDesktop", pages: [.init("library", "Hintergründe", "play.rectangle"), .init("playlists", "Wechsellisten", "list.bullet"), .general, .info]) { page in
            switch page {
            case "library": BackgroundLibraryView(controller: controller)
            case "playlists": playlists
            case "general": SettingsSection("Wiedergabe") {
                ToggleRow("Wiedergabe aktiv", isOn: Binding(get: { !controller.manualPause }, set: { controller.manualPause = !$0 }))
                ToggleRow("Im Stromsparmodus pausieren", isOn: $controller.pauseOnLowPower)
                ToggleRow("Bei Akkubetrieb pausieren", isOn: $controller.pauseOnBattery)
                ToggleRow("Sanfter Videoübergang", isOn: $controller.crossfade)
                StatusMessage(controller.status)
                LoginItemRow().disabled(CommandLine.arguments.contains("--ui-preview"))
            }
            default:
                AppInfoSection("LiveDesktop")
                ForEach(Array(controller.warnings.suffix(5).enumerated()), id: \.offset) { _, warning in StatusMessage(warning, error: true) }
            }
        }
    }
    private var playlists: some View {
        VStack(alignment: .leading, spacing: KitSpacing.group) {
            DisplayPicker(controller: controller)
            SettingsSection("Wechsellisten") {
                Picker("Wechselliste", selection: Binding(get: { controller.selectedPlaylistID }, set: controller.choosePlaylist)) {
                    ForEach(controller.playlists) { Text($0.name).tag($0.id) }
                }
                HStack {
                    TextField("Neue Liste", text: $controller.playlistName)
                    Button("Speichern", action: controller.saveNamedPlaylist).disabled(controller.playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Löschen", action: controller.deletePlaylist).disabled(controller.playlists.count < 2)
                }
                ToggleRow("Hintergründe automatisch wechseln", isOn: $controller.rotationEnabled)
                if controller.rotationEnabled {
                    ChoiceRow("Alle", selection: $controller.rotationMinutes, options: [1, 5, 15, 30, 60].map { ($0 == 1 ? "1 Minute" : "\($0) Minuten", $0) })
                    ToggleRow("Zufällige Reihenfolge", isOn: $controller.shuffle)
                    Button("Jetzt wechseln", action: controller.advanceRotation).disabled(controller.availableRotationCount < 2)
                    StatusMessage("\(controller.availableRotationCount) verfügbar · mindestens zwei unter Hintergründe markieren.")
                    if let next = controller.nextChange { Text(next, style: .relative).font(.caption) }
                }
                Button("Listen und Einstellungen exportieren …", action: controller.exportLibrary)
                Button("Listen und Einstellungen importieren …", action: controller.importLibrary)
            }
        }
    }
}

struct LiveDesktopQuickView: View {
    @ObservedObject var controller: WallpaperController
    let openSettings: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: KitSpacing.group) {
            AppHeader(title: "LiveDesktop", subtitle: "Hintergründe in Bewegung", symbol: "play.rectangle")
            ToggleRow("Wiedergabe aktiv", isOn: Binding(get: { !controller.manualPause }, set: { controller.manualPause = !$0 }))
            StatusMessage(controller.status)
            Text(controller.currentName(target: controller.targetDisplayID)).lineLimit(2)
            Button("Jetzt wechseln", action: controller.advanceRotation).disabled(controller.availableRotationCount < 2)
            Button("Einstellungen …", action: openSettings)
            Button("LiveDesktop beenden") { controller.shutdown(); NSApp.terminate(nil) }
        }.padding(KitSpacing.page).frame(width: 400)
    }
}
