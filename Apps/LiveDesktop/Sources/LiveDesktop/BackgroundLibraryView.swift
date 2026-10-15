import AppKit
import SwiftUI
import LiveDesktopCore
import MacFitKitUI

struct BackgroundLibraryView: View {
    @ObservedObject var controller: WallpaperController
    private var filtered: [VideoAsset] {
        let query = controller.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return controller.assets.filter { (!controller.favoritesOnly || controller.favorites.contains($0.url.path)) &&
            (query.isEmpty || $0.name.localizedStandardContains(query) || $0.category.localizedStandardContains(query)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: KitSpacing.group) {
            DisplayPicker(controller: controller)
            SettingsSection("Hintergründe") {
                TextField("Hintergründe suchen", text: $controller.searchQuery).textFieldStyle(.roundedBorder)
                ToggleRow("Nur Favoriten", isOn: $controller.favoritesOnly)
                StatusMessage(controller.status)
                if controller.scanning { ProgressView("Lokale Hintergründe werden gesucht …") }
                if !controller.scanning && filtered.isEmpty {
                    EmptyState("Keine passenden Hintergründe", detail: "Eigenes Video wählen oder einen Apple-Hintergrund in macOS herunterladen und neu suchen.", symbol: "play.rectangle")
                }
                LazyVStack(alignment: .leading, spacing: KitSpacing.small) {
                    ForEach(Array(Set(filtered.map(\.category))).sorted(), id: \.self) { category in
                        Text(category).font(.headline).padding(.top, KitSpacing.small)
                        ForEach(filtered.filter { $0.category == category }) { asset in
                            HStack(spacing: KitSpacing.small) {
                                Button { controller.toggleFavorite(asset.url.path) } label: {
                                    Image(systemName: controller.favorites.contains(asset.url.path) ? "star.fill" : "star")
                                }.buttonStyle(.plain).accessibilityLabel("Favorit: " + asset.name)
                                if controller.rotationEnabled {
                                    Toggle("Zum Wechsel hinzufügen: " + asset.name,
                                        isOn: Binding(get: { controller.rotationPaths.contains(asset.url.path) }, set: { _ in controller.toggleRotationAsset(asset.url.path) }))
                                        .labelsHidden().toggleStyle(.checkbox)
                                }
                                Button { controller.selectForTarget(asset.url.path, target: controller.targetDisplayID) } label: {
                                    HStack(spacing: KitSpacing.medium) {
                                        thumbnail(asset)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(asset.name).font(.body.weight(.medium))
                                            Text(asset.appleID == nil ? "Lokales Video" : "Apple · lokal gespeichert").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if controller.isSelected(asset, target: controller.targetDisplayID) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
                                    }.padding(KitSpacing.small).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel(asset.name)
                                .accessibilityValue(controller.isSelected(asset, target: controller.targetDisplayID) ? "Ausgewählt" : "Nicht ausgewählt")
                            }
                        }
                    }
                }
                HStack {
                    Text("\(controller.assets.count) Videos lokal").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Neu suchen", action: controller.refreshCatalog).disabled(controller.scanning)
                    Button("Erneut versuchen", action: controller.retryTarget)
                }
            }
            SettingsSection("Bibliothek verwalten") {
                Button("Eigenes Video wählen …") { controller.chooseFile(for: controller.screens.first { controller.screenID($0) == controller.targetDisplayID }) }
                Button("Videoordner hinzufügen …", action: controller.chooseFolder)
                Button("Apple-Hintergründe verwalten …", action: controller.openAppleSettings)
                Button("macOS-Hintergrund zeigen") { controller.selectForTarget("", target: controller.targetDisplayID) }
            }
        }
    }
    @ViewBuilder func thumbnail(_ asset: VideoAsset) -> some View {
        if let image = controller.thumbnails[asset.url.path] {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).frame(width: 82, height: 50).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
        } else { RoundedRectangle(cornerRadius: 8).fill(.quaternary).frame(width: 82, height: 50).overlay(Image(systemName: "video")) }
    }
}

struct DisplayPicker: View {
    @ObservedObject var controller: WallpaperController
    var body: some View {
        Picker("Anzeigen auf", selection: $controller.targetDisplayID) {
            Text("Allen Bildschirmen").tag("")
            ForEach(controller.screens, id: \.self) { Text($0.localizedName).tag(controller.screenID($0)) }
        }.onChange(of: controller.screens.count) { _, _ in
            if !controller.targetDisplayID.isEmpty && !controller.screens.contains(where: { controller.screenID($0) == controller.targetDisplayID }) { controller.targetDisplayID = "" }
        }.onChange(of: controller.targetDisplayID) { _, _ in controller.synchronizePlaylistEditor() }
    }
}
