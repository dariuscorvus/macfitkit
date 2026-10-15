# MacFitKit

Vier eigenständige native macOS-Tools mit gemeinsamer Codebasis und Designsprache. Eine optionale fünfte App bündelt ihre Menüleisteneinträge.

| App | Aufgabe | Mindestversion |
|---|---|---|
| FocusFrame | Das aktive Fenster mit einem anpassbaren Rahmen hervorheben | macOS 14 |
| LiveDesktop | Lokale Videohintergründe, Favoriten und Wechsellisten pro Bildschirm | macOS 26 |
| DockPreview | Fenster am Dock voranzeigen und gezielt aktivieren | macOS 14 |
| UniversalPiP | Ein ausgewähltes Fenster als proportionale Live-Vorschau im Vordergrund anzeigen | macOS 14 |
| MacFitKit (optional) | Installierte Tools anzeigen, starten und steuern | macOS 14 |

## Entwicklung

`MacFitKit.xcworkspace` öffnen und das gewünschte gemeinsame Scheme auswählen. Jede App hat weiterhin ein eigenes Xcode-Projekt und eine eigene App-Identität. Swift 6 und ein Xcode mit macOS-26-SDK oder neuer werden für den gesamten Workspace benötigt.

```sh
./script/build.sh all Debug
./script/build.sh all Release
./script/check.sh
```

Die Builds liegen unter `~/Library/Caches/MacFitKit/Monorepo/Build/Products/Debug` bzw. `Release`. `MACFITKIT_BUILD_DIR` überschreibt den DerivedData-Pfad. Die Skripte verwenden ein vorhandenes Apple-Development-Zertifikat oder Ad-hoc-Signierung; `MACFITKIT_SIGNING_IDENTITY` setzt die Identität explizit. Für eine verteilbare Veröffentlichung bleiben Developer-ID-Signierung und Notarisierung ein eigener Schritt.

Nur bauen oder eine bestimmte Entwicklungsversion öffnen:

```sh
./script/build_and_run.sh FocusFrame --build-only
./script/build_and_run.sh LiveDesktop --settings
./script/build_and_run.sh DockPreview --verify
./script/build_and_run.sh MacFitKit
```

Der Run-Befehl beendet oder ersetzt keine installierte App. Bei bereits laufendem gleichnamigem Prozess bricht der Start mit einem Hinweis ab. Reine Builds ändern keine installierten Apps. `--debug`, `--logs` und `--telemetry` unterstützen die lokale Diagnose. Bestehende app-interne Skripte sind mit dem Import erhalten; die Root-Skripte sind die gemeinsame Build-Basis.

## Gemeinsame Oberfläche

`Packages/MacFitKitShared` enthält drei lokale Module ohne externe Abhängigkeiten:

- **MacFitKitCore:** Tool-Kennungen, Status, feste Steuerbefehle und Validierung.
- **MacFitKitPlatform:** Datenschutzfreigaben, Autostart, App-Suche und lokale Menüleistenkommunikation.
- **MacFitKitUI:** gemeinsamer Einstellungsrahmen, native Seitenleiste, Gruppen, Regler, Auswahl-, Schalter-, Freigabe- und Statuszeilen.

Alle Apps verwenden Systemfarben, Systemschrift, native Materialien und ein gemeinsames Abstandsraster. App-spezifische Ansichten und Engines bleiben bei den jeweiligen Apps. Die Stores bleiben die einzige Quelle der Einstellungen; Profile, Hintergrundlisten, App-Ausnahmen und bisherige UserDefaults-Formate werden nicht in einen gemeinsamen Store verschoben.

## Optionales MacFitKit-Menü

MacFitKit listet bekannte installierte oder bereits laufende Tools. Verbundene Versionen lassen sich aktivieren/pausieren, öffnen und beenden. Der manuelle Aktiv-Schalter hebt automatische Wiedergabepausen durch Stromsparmodus, Schlafzustand oder thermische Belastung nicht auf.

Die eigenen Menüleistensymbole der Tools verschwinden erst nach bestätigter Verbindung. MacFitKit sendet jede Sekunde ein Lebenszeichen. Beim regulären Beenden werden die Symbole wiederhergestellt; nach einem Absturz spätestens nach Ablauf der drei Sekunden langen Lease. Die Tools laufen dabei weiter. Ohne MacFitKit bleiben sie vollständig eigenständig. Ältere Versionen behalten ihr eigenes Symbol und werden als nicht verbunden angezeigt; für die zentrale Steuerung benötigen sie die integrierte Version.

Die Kommunikation verwendet einen versionierten lokalen `DistributedNotificationCenter`-Kanal mit festen Befehlen. Keine Fenstertitel, Screenshots, Videodateipfade oder vollständigen Einstellungen werden übertragen. Dieser Benutzer-Sitzungskanal ist keine Authentifizierungsgrenze für feindliche Prozesse desselben Benutzers.

## Datenschutz und Bestand

Bundle-Identifier und vorhandene Speicherformate bleiben erhalten. Freigaben und Autostart gehören weiter zur jeweiligen App. DockPreview benötigt Bedienungshilfen und für Miniaturen Bildschirmaufnahme; FocusFrame benötigt Bedienungshilfen. Freigaben werden über die nativen Systemeinstellungen angefragt und nicht zurückgesetzt. Ein Wechsel der lokalen Signatur kann eine erneute manuelle Freigabe erfordern.

Die Migration veröffentlicht keine Releases, archiviert keine alten Repositories und installiert keine Apps. Vor einem späteren Austausch installierter Apps: vorhandene Bundles und Konfiguration sichern, das neue Bundle prüfen und einen Rückweg behalten.

## Abnahme und Prüfhilfen

```sh
./script/check_bridge.sh
./Apps/FocusFrame/script/test_settings_window.sh
./script/preview_ui.sh FocusFrame
./script/preview_ui.sh DockPreview --dark
```

Die Bridge-Prüfung verwendet eigene Bundle-IDs und einen zufälligen Kanal; sie steuert keine installierten Tools. UI-Vorschauen verwenden ebenfalls eigene Bundle-IDs, deaktivierte Engines bzw. getrennte Testeinstellungen und kopieren nur Build-Artefakte. Systemfreigaben und Autostart sind im Vorschaumodus nicht zum Verändern vorgesehen. Nach der Prüfung diese Vorschau-Instanzen beenden; ihre temporären Bundles befinden sich im Library-Cache.

- [Migration und Herkunft](docs/migration.md)
- [Aktuelle Nachweise und offene Abnahmen](docs/validation-monorepo.md)
- [Architektur und Komponenten](docs/architecture.md)
- [Historische DockPreview-Laufzeittests](docs/dock-preview-validation.md)

## UniversalPiP

Die neue eigenständige App **UniversalPiP** (macOS 14+) ergänzt eine frei skalierbare Live-Vorschau eines ausgewählten Fensters. Sie verwendet ScreenCaptureKit/SCStream und eine standardmäßig rahmenlose Vorschau mit Hover-HUD. Titelleiste, Größenwahl und weitere Aktionen sind innerhalb der Vorschau erreichbar. Die App bleibt unabhängig von DockPreview und bindet das gemeinsame Menü ein. Das eigene Aufnahme-Recht wird separat geprüft; gezielter Original-Fokus benötigt optional Bedienungshilfen. Eine erste UTM-Live-Prüfung ist erfolgt; vollständige Plattform- und Leistungsabnahme bleiben offen.

```sh
./script/build_and_run.sh UniversalPiP --build-only
./script/run_pip_fixture.sh
```

[Architektur, Bedienung, Testmatrix und Auslieferung](docs/universal-pip.md)
