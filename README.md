# MacFitKit

Monorepo für eigenständige native macOS-Utilities. Der erste Baustein ist DockPreview: Fenstervorschauen direkt am macOS-Dock.

## Struktur

```text
MacFitKit.xcworkspace
Apps/DockPreview/
  DockPreview.xcodeproj
  DockPreview/
    DockPreviewApp.swift
    ContentView.swift
    AccessibilityReader.swift
    DockPreviewController.swift
    PreviewPanel.swift
    PreviewGeometry.swift
script/build_and_run.sh
```

DockPreview verwendet Swift 6, SwiftUI und einen AppKit-App-Delegate. Das gemeinsame Schema `DockPreview` ist eingecheckt. Keine externen Packages, kein Hub.

## Öffnen und starten

Voraussetzungen: macOS 14 oder neuer sowie Xcode mit macOS-SDK (Swift 6).

```sh
open MacFitKit.xcworkspace
./script/build_and_run.sh
```

In Xcode das Schema **DockPreview** und **My Mac** wählen und mit ⌘R starten. Für dauerhaft gültige macOS-Freigaben unter Signing ein eigenes Entwicklungszertifikat wählen; das Startskript erkennt ein vorhandenes Apple-Development-Zertifikat automatisch. Auch `Apps/DockPreview/DockPreview.xcodeproj` lässt sich eigenständig öffnen. In Codex ist die Aktion **Run** auf dasselbe Startskript eingestellt.

Das Skript beendet eine vorhandene DockPreview-Instanz, baut Debug und öffnet die App. `--verify` prüft zusätzlich den laufenden Prozess; `--debug`, `--logs` und `--telemetry` öffnen Debugger bzw. Log-Streams. Der Subsystem-Logfilter zeigt Vorschau- und Aktivierungsergebnisse ohne Fenstertitel oder Bildinhalte.

## Nur bauen

```sh
xcodebuild -workspace MacFitKit.xcworkspace -scheme DockPreview \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$HOME/Library/Caches/MacFitKit/DerivedData" build

xcodebuild -workspace MacFitKit.xcworkspace -scheme DockPreview \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$HOME/Library/Caches/MacFitKit/ReleaseDerivedData" build
```

Das Xcode-Projekt verwendet standardmäßig lokale Ad-hoc-Signierung und benötigt damit kein Apple-Entwicklerteam. Das Startskript wählt ein installiertes Apple-Development-Zertifikat, falls vorhanden, damit Datenschutz-Freigaben über Rebuilds hinweg gültig bleiben. Mit `MACFITKIT_SIGNING_IDENTITY` kann die lokale Identität explizit gewählt werden (z. B. `-` für Ad-hoc). Ohne Zertifikat können Freigaben nach Codeänderungen erneut nötig sein. Für eine spätere Verteilung müssen Signierung, Hardened Runtime und Notarisierung eingerichtet werden. Das Startskript legt Build-Dateien unter `~/Library/Caches/MacFitKit/DerivedData` ab; `MACFITKIT_BUILD_DIR` überschreibt diesen Pfad. Build-Dateien außerhalb synchronisierter Dokumente-Ordner vermeiden lokale Signierungsfehler durch Finder-Metadaten.

## Dock-Vorschau verwenden

1. DockPreview mit `./script/build_and_run.sh` starten. Die App läuft in der Menüleiste, ohne eigenes Dock-Symbol.
2. Im Einrichtungsfenster **Bedienungshilfen** und **Bildschirmaufnahme** für DockPreview freigeben. Die Bildschirmaufnahme wird direkt über ScreenCaptureKit angefragt; bei ausstehender Freigabe öffnet sich die passende Seite unter Datenschutz & Sicherheit. Fehlt dort der Eintrag, zeigt **App im Finder zeigen** das aktuelle App-Bundle zur Auswahl über **+**. Falls macOS es verlangt, die App anschließend neu starten.
3. Den Zeiger etwa 0,35 Sekunden über ein laufendes App-Symbol im Dock halten. Eine Leiste mit Fensterminiaturen erscheint.
4. Auf eine Miniatur klicken: Das zugehörige Fenster wird gegebenenfalls entminimiert und in den Vordergrund geholt. Die Vorschau selbst übernimmt beim Hover keinen Tastaturfokus.
5. Beim Verlassen von Dock-Symbol und Vorschau schließt sich die Leiste nach kurzer Verzögerung. Über das Menüleistensymbol lässt sich die Einrichtung erneut öffnen oder DockPreview beenden.

Die Leiste unterstützt das Dock unten, links und rechts sowie horizontales Scrollen bei vielen Fenstern. Die Miniaturen sind Momentaufnahmen beim Öffnen, kein laufender Videostream. Bilder bleiben im Arbeitsspeicher und werden beim Schließen der Vorschau verworfen; es gibt keine Uploads oder Bilddateien.

Ohne Bildschirmaufnahme sind Fenstertitel und Auswahl weiterhin verfügbar. Minimierte, geschützte oder nicht eindeutig zuordenbare Fenster erhalten einen Platzhalter. Minimierte Fenster bleiben auswählbar. Ohne Bedienungshilfen ist die Dock-Erkennung pausiert. Die verfügbaren Fenster hängen von der Accessibility-Unterstützung der jeweiligen App und macOS ab; andere Spaces und Vollbild-Sonderfälle sind gesondert zu testen.

Bei einer Freigabe, die in den Systemeinstellungen eingeschaltet ist, aber von DockPreview nicht erkannt wird: App neu starten. Wurde die Signatur geändert, den DockPreview-Eintrag für die aktuelle App erneut freigeben; bei einem veralteten Eintrag diesen entfernen und die aktuelle App neu hinzufügen. Das Startskript verwendet bei vorhandenem Entwicklungszertifikat eine stabile Signatur.

## Prüfen

```sh
./script/check_preview_core.sh
./script/build_and_run.sh --verify
```

Die Core-Prüfungen testen Bildschirmkoordinaten, Panel-Positionen, den Übergang vom Dock zur Vorschau und die Zuordnung gleichnamiger bzw. mehrdeutiger Fenster. Sie benötigen keine Datenschutz-Freigaben. Der vollständige Hover-/Miniatur-/Klick-Test benötigt die beiden Freigaben.

- [Aktueller Prüfbericht zur Dock-Vorschau](docs/dock-preview-validation.md)
- [Historischer Nachweis des Grundgerüsts](docs/validation.md)
