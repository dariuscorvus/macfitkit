# MacFitKit

Monorepo für eigenständige native macOS-Utilities. Der erste Baustein ist DockPreview.

## Struktur

```text
MacFitKit.xcworkspace
Apps/DockPreview/
  DockPreview.xcodeproj
  DockPreview/
    DockPreviewApp.swift
    ContentView.swift
script/build_and_run.sh
```

DockPreview verwendet Swift 6, SwiftUI und einen AppKit-App-Delegate. Das gemeinsame Schema `DockPreview` ist eingecheckt. Keine externen Packages, kein Hub.

## Öffnen und starten

Voraussetzungen: macOS 14 oder neuer sowie Xcode mit macOS-SDK (Swift 6).

```sh
open MacFitKit.xcworkspace
./script/build_and_run.sh
```

In Xcode das Schema **DockPreview** und **My Mac** wählen und mit ⌘R starten. Auch `Apps/DockPreview/DockPreview.xcodeproj` lässt sich eigenständig öffnen. In Codex ist die Aktion **Run** auf dasselbe Startskript eingestellt.

Das Skript beendet eine vorhandene DockPreview-Instanz, baut Debug und öffnet die App. `--verify` prüft zusätzlich den laufenden Prozess; `--debug`, `--logs` und `--telemetry` öffnen Debugger bzw. Log-Streams. Für den Subsystem-Logfilter sind noch keine eigenen Ereignisse implementiert.

## Nur bauen

```sh
xcodebuild -workspace MacFitKit.xcworkspace -scheme DockPreview \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$HOME/Library/Caches/MacFitKit/DerivedData" build

xcodebuild -workspace MacFitKit.xcworkspace -scheme DockPreview \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$HOME/Library/Caches/MacFitKit/ReleaseDerivedData" build
```

Die lokale Ad-hoc-Signierung benötigt kein Apple-Entwicklerteam. Für eine spätere Verteilung müssen Signierung, Hardened Runtime und Notarisierung eingerichtet werden. Das Startskript legt Build-Dateien unter `~/Library/Caches/MacFitKit/DerivedData` ab; `MACFITKIT_BUILD_DIR` überschreibt diesen Pfad. Build-Dateien außerhalb synchronisierter Dokumente-Ordner vermeiden lokale Signierungsfehler durch Finder-Metadaten.

## Aktueller Umfang

Ein natives Startfenster bestätigt das App-Grundgerüst. Dock-Hover, Fenstererkennung, Miniaturen, Fensteraktivierung und Hintergrundbetrieb sind noch nicht implementiert. Deshalb werden derzeit keine Bedienungshilfen- oder Bildschirmaufnahme-Rechte angefordert.

Build- und Startnachweis: [docs/validation.md](docs/validation.md).
