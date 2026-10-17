# MacFitKit

Native macOS-Tools für Fenstermarkierung, Videohintergründe, Dock-Vorschauen und Bild-in-Bild. Jede App funktioniert eigenständig. Das optionale MacFitKit-Menü bündelt ihre Menüleistensymbole und Bedienelemente.

## Downloads

Die aktuellen **Preview-3-Pakete** sind mit Developer ID signiert und von Apple notarisiert. DMG und ZIP enthalten dieselbe Universal-App für Apple Silicon und Intel, die MIT-Lizenz und Installationshinweise. Prüfsummen stehen jeweils im Release.

| App | Wofür? | Mindestversion | Download |
|---|---|---|---|
| **FocusFrame** | Das aktive Fenster mit einem anpassbaren Rahmen hervorheben | macOS 14 | [FocusFrame 0.9.0 Preview 3](https://github.com/dariuscorvus/macfitkit/releases/tag/focusframe-v0.9.0-preview.3) |
| **LiveDesktop** | Lokale Videos als Hintergrund, Favoriten und Wechsellisten | macOS 26 | [LiveDesktop 0.4.0 Preview 3](https://github.com/dariuscorvus/macfitkit/releases/tag/livedesktop-v0.4.0-preview.3) |
| **DockPreview** | Beim Dock-Hover Fenstervorschauen anzeigen und Fenster auswählen | macOS 14 | [DockPreview 0.2.0 Preview 3](https://github.com/dariuscorvus/macfitkit/releases/tag/dockpreview-v0.2.0-preview.3) |
| **UniversalPiP** | Ein ausgewähltes Fenster als skalierbare Live-Vorschau im Vordergrund behalten | macOS 14 | [UniversalPiP 0.1.0 Preview 3](https://github.com/dariuscorvus/macfitkit/releases/tag/universalpip-v0.1.0-preview.3) |
| **MacFitKit** (optional) | Die installierten Tools gemeinsam starten, pausieren und öffnen | macOS 14 | [MacFitKit 0.1.0 Preview 3](https://github.com/dariuscorvus/macfitkit/releases/tag/macfitkit-v0.1.0-preview.3) |

[Alle Releases und ältere Versionen](https://github.com/dariuscorvus/macfitkit/releases)

Die angegebenen Mindestversionen entsprechen den Builds. Echte Intel- und Mindestversionsläufe sind noch nicht vollständig abgenommen. Die Apps bleiben Vorabversionen; insbesondere UniversalPiP hat noch offene Langzeit- und Plattformtests.

## Installieren und aktualisieren

1. Lade das **DMG** oder **ZIP** der gewünschten App herunter und öffne beziehungsweise entpacke es.
2. Kopiere die `.app` nach **Programme** oder in deinen persönlichen Programme-Ordner. Zum Testen oder Nutzen ist Xcode nicht erforderlich.
3. Starte die kopierte App. macOS kann beim ersten Öffnen die übliche Bestätigung für einen Download verlangen.
4. Die Apps sind über die **Menüleiste oben am Bildschirm** erreichbar. Klicke auf das jeweilige Symbol, um die Einstellungen zu öffnen.

**Bei einem Update:** Beende die App zuerst, sichere ihre bisherige Version und ersetze sie am bisherigen Installationsort. Lege keine zweite Kopie in einem anderen Programme-Ordner an. Die bestehenden Einstellungen bleiben in ihrem bisherigen Store. Beim Wechsel von einer anders signierten lokalen Entwicklungsversion kann macOS erneut Freigaben verlangen.

Die Downloads sind notarisiert; Gatekeeper muss dafür nicht global abgeschaltet werden. Falls ein Download beschädigt erscheint, lade ihn erneut aus dem zugehörigen Release und vergleiche bei Bedarf `SHA256SUMS.txt`.

## Erster Start und Berechtigungen

| App | Einrichtung |
|---|---|
| FocusFrame | Bedienungshilfen freigeben, damit die App das aktive Fenster erkennen und den Rahmen nachführen kann. Darstellung und optionales Tastenkürzel in den Einstellungen anpassen. |
| LiveDesktop | In **Hintergründe** ein vorhandenes Video wählen oder eigene Videos hinzufügen. Die App benötigt Dateizugriff auf die verwendeten Videos und Ordner. |
| DockPreview | Bedienungshilfen für Erkennung/Fensterwahl und Bildschirmaufnahme für Miniaturen freigeben. Danach den Zeiger über ein App-Symbol im Dock bewegen. |
| UniversalPiP | Bildschirmaufnahme freigeben und ein Fenster aus der Auswahlliste wählen. Bedienungshilfen werden zusätzlich für die optionale Aktivierung des Originalfensters benötigt. |
| MacFitKit | Die gewünschten Tools separat installieren. Das gemeinsame Menü benötigt selbst keine Bildschirmaufnahme- oder Bedienungshilfen-Freigabe. |

Die Freigaben werden je App unter **Systemeinstellungen → Datenschutz & Sicherheit** erteilt. Je nach macOS-Version heißt die Aufnahmefreigabe **Bildschirmaufnahme** oder **Bildschirm- & Systemaudioaufnahme**. Folge einem von macOS verlangten App-Neustart. Freigaben werden beim Update nicht automatisch zurückgesetzt.

## Ein gemeinsames Menü

Starte zusätzlich zu deinen Tools die App **MacFitKit**. Sobald ein Tool verbunden ist, verschwindet dessen eigenes Menüleistensymbol. Im gemeinsamen Menü findest du Status, **Starten**, **Pausieren/Aktivieren**, **Einstellungen** und **Beenden**.

MacFitKit installiert die anderen Tools nicht automatisch. Beendest du nur MacFitKit, laufen die Tools weiter und zeigen wieder ihre eigenen Symbole. Auch nach einem Ausfall des gemeinsamen Menüs kehren die Symbole zurück. Ältere, nicht kompatible Tool-Versionen behalten ihr Symbol und werden als nicht verbunden angezeigt.

Für den Anmeldestart aktiviere **Allgemein → Beim Anmelden starten** in jeder gewünschten App sowie gegebenenfalls in MacFitKit. Nur den Autostart des Menüs einzuschalten aktiviert nicht automatisch den Autostart aller Tools.

Manuelle Aktivierung hebt automatische LiveDesktop-Pausen durch Stromsparmodus, Schlafzustand oder thermische Belastung nicht auf.

## Probleme und Wünsche

- [Fehler melden](https://github.com/dariuscorvus/macfitkit/issues/new?template=bug_report.yml): App-/Release-Version, macOS-Version, Mac-Typ und nachvollziehbare Schritte angeben.
- [Funktion wünschen](https://github.com/dariuscorvus/macfitkit/issues/new?template=feature_request.yml): Beschreibe die Aufgabe, die du mit der Verbesserung lösen möchtest.
- [Vorhandene Meldungen durchsuchen](https://github.com/dariuscorvus/macfitkit/issues)

Bitte entferne private Fenstertitel, Dateipfade, Kontodaten und andere persönliche Inhalte aus Screenshots oder Protokollen, bevor du sie in öffentlichen Issues teilst.

## Bekannte Grenzen

- Die Apps sind Vorabversionen. Vollständige VoiceOver-, Kontrast- und Tastaturprüfungen aller Ansichten sind noch offen.
- Intel, ältere unterstützte macOS-Versionen sowie Mehrmonitor-, Spaces-, Vollbild- und Energie-Sonderfälle sind noch nicht vollständig auf echter Hardware geprüft.
- UniversalPiP hat offene Langzeit-, Speicher- und Latenzprüfungen.
- FocusFrames Rahmen kann über überlappenden Fenstern sichtbar bleiben. Eine Korrektur ist [im Quellcode umgesetzt und auf dem Mac mini mit überlappenden Fenstern und Kontextmenüs geprüft](docs/focusframe-occlusion-plan.md); die verlinkten Preview-3-Downloads enthalten sie noch nicht.

[Bestätigte Prüfungen und offene Abnahmen](docs/validation-monorepo.md) · [UniversalPiP-Testmatrix](docs/universal-pip.md)

## Entwicklung

<details>
<summary>Workspace, Builds und Architektur</summary>

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


Das lokale Package `Packages/MacFitKitShared` enthält `MacFitKitCore`, `MacFitKitPlatform` und `MacFitKitUI`. Fenstermarkierung, Wiedergabe, Dock-Erkennung und Capture bleiben bei ihren jeweiligen Apps. Einstellungen werden in den vorhandenen app-eigenen Stores gehalten.

Die Menükommunikation verwendet feste, versionierte Befehle über `DistributedNotificationCenter`. Dieser Sitzungskanal ist keine Authentifizierungsgrenze gegenüber feindlichen Prozessen desselben Benutzers. Fenstertitel, Screenshots, Videodateipfade und vollständige Einstellungen werden nicht über diesen Kanal übertragen.

Notarisierte Pakete mit eingebettetem MIT-Lizenztext erzeugen:

```sh
python3 script/release.py all --preview 3 --notary-profile DEIN_PROFIL
```

Mit `--publish` werden erst nach bestandener Paketprüfung GitHub-Vorab-Releases angelegt. Vorhandene Tags und Downloads werden nicht überschrieben. Der Vorgang installiert keine Apps. Das Profil muss zuvor mit `notarytool store-credentials` im lokalen Schlüsselbund eingerichtet sein; Zugangsdaten gehören nicht ins Repository.

- [Migration und Herkunft](docs/migration.md)
- [Architektur](docs/architecture.md)
- [Prüfung und Auslieferung der Pakete](docs/releases.md)

</details>

## Lizenz

MacFitKit einschließlich der Apps und gemeinsamen Swift-Packages steht unter der [MIT-Lizenz](LICENSE). Der vollständige Text liegt auch in den aktuellen Downloadpaketen und unter `Contents/Resources/LICENSE` jeder App.
