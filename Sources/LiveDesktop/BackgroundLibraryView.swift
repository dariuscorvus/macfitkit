import AppKit
import SwiftUI
import LiveDesktopCore

struct BackgroundLibraryView: View {
    @ObservedObject var controller: WallpaperController

    private var filtered: [VideoAsset] {
        let search = controller.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return controller.assets.filter { (!controller.favoritesOnly || controller.favorites.contains($0.url.path)) && (search.isEmpty || $0.name.localizedStandardContains(search) || $0.category.localizedStandardContains(search)) }
    }
    static var panelHeight: CGFloat { min(760, max(460, (NSScreen.main?.visibleFrame.height ?? 840) - 80)) }
    private var categories: [String] { Array(Set(filtered.map(\.category))).sorted() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LiveDesktop").font(.title2.bold())
                    Text("Apple-Hintergründe in Bewegung").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { controller.manualPause.toggle() } label: {
                    Image(systemName: controller.manualPause ? "play.fill" : "pause.fill")
                }
                .help(controller.manualPause ? "Wiedergabe fortsetzen" : "Wiedergabe pausieren")
                .accessibilityLabel(controller.manualPause ? "Fortsetzen" : "Pausieren")
            }
            Picker("Anzeigen auf", selection: $controller.targetDisplayID) {
                Text("Allen Bildschirmen").tag("")
                ForEach(controller.screens, id: \.self) { screen in
                    Text(screen.localizedName).tag(controller.screenID(screen))
                }
            }
            .onChange(of: controller.screens.count) { _, _ in
                if !controller.targetDisplayID.isEmpty && !controller.screens.contains(where: { controller.screenID($0) == controller.targetDisplayID }) { controller.targetDisplayID = "" }
            }
            Picker("Wechselliste", selection: Binding(get: { controller.selectedPlaylistID }, set: { controller.choosePlaylist($0) })) {
                ForEach(controller.playlists) { Text($0.name).tag($0.id) }
            }
            .onChange(of: controller.targetDisplayID) { _, _ in controller.synchronizePlaylistEditor() }
            HStack {
                TextField("Neue Liste", text: $controller.playlistName)
                Button("Speichern") { controller.saveNamedPlaylist() }.disabled(controller.playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Toggle("Favoriten", isOn: $controller.favoritesOnly).toggleStyle(.checkbox)
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Hintergründe suchen", text: $controller.searchQuery).textFieldStyle(.plain)
                if !controller.searchQuery.isEmpty { Button { controller.searchQuery = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("Suche leeren") }
            }
            .padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 5) {
                Image(systemName: "play.circle")
                Text(controller.currentName(target: controller.targetDisplayID)).lineLimit(1)
            }.font(.callout)
            Text(controller.status).font(.caption).foregroundStyle(.secondary)
            if controller.surfaceStates.values.contains(where: { if case .failed = $0 { return true }; return false }) {
                Button("Erneut versuchen") { controller.retryTarget() }
            }
            Toggle("Beim Anmelden starten", isOn: Binding(get: { controller.loginEnabled || controller.loginNeedsApproval }, set: { controller.setLoginEnabled($0) }))
            if controller.loginNeedsApproval {
                Button("Autostart in Systemeinstellungen erlauben …") { controller.openLoginSettings() }
            }
            if !controller.loginMessage.isEmpty { Text(controller.loginMessage).font(.caption).foregroundStyle(.red) }
            Toggle("Hintergründe automatisch wechseln", isOn: $controller.rotationEnabled)
            if controller.rotationEnabled {
                HStack {
                    Picker("Alle", selection: $controller.rotationMinutes) {
                        ForEach([1, 5, 15, 30, 60], id: \.self) { Text($0 == 1 ? "1 Minute" : "\($0) Minuten").tag($0) }
                    }
                    Button("Jetzt wechseln") { controller.advanceRotation() }.disabled(controller.availableRotationCount < 2)
                }
                HStack {
                    Toggle("Zufällige Reihenfolge", isOn: $controller.shuffle).toggleStyle(.checkbox)
                    Spacer()
                    if let next = controller.nextChange { Text(next, style: .relative).font(.caption).foregroundStyle(.secondary) }
                }
                Text("\(controller.availableRotationCount) verfügbar · mindestens zwei markieren.").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if controller.scanning { ProgressView("Lokale Hintergründe werden gesucht …") }
                    else if filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(controller.assets.isEmpty ? "Noch keine lokalen Videos gefunden" : "Keine passenden Hintergründe").font(.headline)
                            Text(controller.assets.isEmpty ? "Wähle in den macOS-Hintergrundbild-Einstellungen einen animierten Apple-Hintergrund und warte auf dessen Download. Anschließend hier neu suchen." : "Versuche einen anderen Suchbegriff.")
                                .font(.callout).foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    }
                    ForEach(categories, id: \.self) { category in
                        Text(category).font(.caption.bold()).foregroundStyle(.secondary).padding(.top, 4)
                        ForEach(filtered.filter { $0.category == category }) { asset in
                            HStack(spacing: 4) {
                            Button { controller.toggleFavorite(asset.url.path) } label: { Image(systemName: controller.favorites.contains(asset.url.path) ? "star.fill" : "star") }.buttonStyle(.plain).help("Favorit umschalten").accessibilityLabel("Favorit: \(asset.name)")
                            if controller.rotationEnabled {
                                Toggle("Zum Wechsel hinzufügen: \(asset.name)", isOn: Binding(get: { controller.rotationPaths.contains(asset.url.path) }, set: { _ in controller.toggleRotationAsset(asset.url.path) })).labelsHidden().toggleStyle(.checkbox)
                            }
                            Button { controller.selectForTarget(asset.url.path, target: controller.targetDisplayID) } label: {
                                HStack(spacing: 10) {
                                    thumbnail(asset)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(asset.name).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                                        Text(asset.appleID == nil ? "Lokales Video" : "Apple · lokal gespeichert").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    if controller.isSelected(asset, target: controller.targetDisplayID) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(controller.isSelected(asset, target: controller.targetDisplayID) ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(asset.name)
                            .accessibilityValue(controller.isSelected(asset, target: controller.targetDisplayID) ? "Ausgewählt" : "Nicht ausgewählt")
                            }
                        }
                    }
                }
            }.frame(maxHeight: .infinity)
            Divider()
            HStack {
                Text("\(controller.assets.filter { $0.appleID != nil }.count) Apple-Videos lokal").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { controller.refreshCatalog() } label: { Image(systemName: "arrow.clockwise") }.disabled(controller.scanning).help("Lokale Hintergründe neu suchen").accessibilityLabel("Neu suchen")
            }
            HStack {
                Button("macOS-Hintergrund zeigen") { controller.selectForTarget("", target: controller.targetDisplayID) }
                Spacer()
                Menu {
                    Button("Apple-Hintergründe verwalten …") { controller.openAppleSettings() }
                    Button("Eigenes Video wählen …") {
                        controller.chooseFile(for: controller.screens.first { controller.screenID($0) == controller.targetDisplayID })
                    }
                    Button("Videoordner hinzufügen …") { controller.chooseFolder() }
                    Toggle("Im Stromsparmodus pausieren", isOn: $controller.pauseOnLowPower)
                    Toggle("Bei Akkubetrieb pausieren", isOn: $controller.pauseOnBattery)
                    Toggle("Sanfter Videoübergang", isOn: $controller.crossfade)
                    Button("Aktuelle Wechselliste löschen") { controller.deletePlaylist() }.disabled(controller.playlists.count < 2)
                    Divider()
                    Button("Listen und Einstellungen exportieren …") { controller.exportLibrary() }
                    Button("Listen und Einstellungen importieren …") { controller.importLibrary() }
                    Button("Downloads auf GitHub …") { controller.openReleases() }
                    Text("Version " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"))
                    if !controller.warnings.isEmpty {
                        Divider()
                        ForEach(Array(controller.warnings.suffix(5).enumerated()), id: \.offset) { _, warning in Text(warning) }
                    }
                    Divider()
                    Button("LiveDesktop beenden") { controller.shutdown(); NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Weitere Optionen")
            }
        }
        .padding(16)
        .frame(width: 440, height: Self.panelHeight)
        .onAppear { controller.refreshLoginStatus() }
    }
    @ViewBuilder private func thumbnail(_ asset: VideoAsset) -> some View {
        if let image = controller.thumbnails[asset.url.path] {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                .frame(width: 82, height: 50).clipped().clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                .frame(width: 82, height: 50).overlay(Image(systemName: "video").foregroundStyle(.secondary))
        }
    }
}
