# Validierung des Grundgerüsts

Stand: 15. Oktober 2026.

## Ausgangslage

`dariuscorvus/macfitkit` war vorhanden, privat, leer und mit administrativem Zugriff erreichbar. Das bestehende Repository wurde geklont; es wurde kein neues GitHub-Repository angelegt. Es gab keine Dateien oder Projektanweisungen im Repository zu übernehmen.

## Umgebung

- macOS 27.2, Apple Silicon (arm64)
- Xcode 27.0, Build 27A266a
- Deployment-Ziel: macOS 14.0
- Swift-Sprachmodus: 6.0
- Lokale Ad-hoc-Signierung, kein Entwicklerteam erforderlich

## Ergebnis

- Projektdatei mit `plutil -lint` erfolgreich geprüft.
- `xcodebuild -list -workspace MacFitKit.xcworkspace` erkennt das gemeinsame Schema `DockPreview`.
- Debug-Build über `./script/build_and_run.sh --verify`: **BUILD SUCCEEDED**. App über Launch Services geöffnet, Prozess erfolgreich bestätigt.
- Release-Build mit generischem macOS-Ziel: **BUILD SUCCEEDED**.
- Laufendes Debug-Fenster zusätzlich über Accessibility-Baum und Screenshot geprüft: Titel „DockPreview“, Text „Das Grundgerüst ist bereit.“ und Hinweis auf die späteren Dock-Funktionen sichtbar.
- Shell-Syntax des Startskripts erfolgreich geprüft.

Die vollständigen reproduzierbaren Build-Befehle stehen in der README. Debug wurde für den aktuellen Apple-Silicon-Mac gebaut; Release enthält arm64 und x86_64. Ein Lauf auf Intel-Hardware oder macOS 14 wurde nicht geprüft.

## Behobene lokale Besonderheit

Die erste Build-Ausgabe im synchronisierten Dokumente-Ordner scheiterte beim Signieren mit `resource fork, Finder information, or similar detritus not allowed`. Die Build-Ausgabe wurde in den lokalen Library-Cache verlegt; anschließend waren Debug, Release und der Start erfolgreich. Quelldateien und Workspace bleiben im Repository.

## Grenzen

Dies ist ein baubares App-Grundgerüst. Dock-Hover, Fensterlisten, Bildschirmaufnahme, Fenstervorschauen, Fokuswechsel und LSUIElement-Betrieb sind noch offen. Der aktuelle Build enthält keine externen Abhängigkeiten, zusätzlichen Apps oder Hub. Automatisierte Funktionstests wurden für diesen Platzhalter nicht angelegt. Notarisierung und verteilbare Releases wurden nicht geprüft.
