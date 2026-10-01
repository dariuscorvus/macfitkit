# Lokale V1-Prüfung – 1. Oktober 2026

Umgebung: Apple Silicon, Swift 6.4, Command Line Tools, macOS-27-SDK.
Deployment Target: macOS 14. Keine externen Paketabhängigkeiten.

## Bestätigt

- `./script/build_and_run.sh --verify`: Build, lokale Bundle-Signierung,
  Start über Launch Services und laufender FocusFrame-Prozess erfolgreich.
- `./script/test.sh`: 4 Tests in einer Suite erfolgreich. Geometrie auf dem
  Hauptdisplay, Display-Anordnungen links/oben/unten, ungültige Fensterdaten
  und Rahmenabstand.
- Der erste Start ohne Bedienungshilfen-Zugriff verursacht keinen Absturz.
  Nach der Freigabe durch den Nutzer bestätigt das Startprotokoll
  `Started; accessibility trusted: true`. Der Nutzer hat den sichtbaren Rahmen bestätigt.
- `git diff --check`: erfolgreich.

## Noch manuell zu prüfen

Reale Multi-Monitor-, Spaces- und Vollbild-Szenarien sowie Klickdurchleitung
sind noch nicht vollständig praktisch abgenommen. Die manuelle Prüfliste steht
in der README. Die UI-Automation war zunächst nicht erreichbar, funktioniert
inzwischen jedoch wieder.

## Nachbesserung: Rundung und Bewegung

- Abgerundeter Rahmen mit 10 pt Innenradius.
- AXMoved/AXResized aktualisieren das bekannte Fenster unmittelbar, ohne
  vollständige Fokus-/Berechtigungsprüfung und ohne Dispatch-Verzögerung.
- Position, Größe und Minimierungsstatus werden gebündelt gelesen.
- Globale Maus-Zieh-/Loslassereignisse ergänzen die Aktualisierung während
  einer Geste. Kein Polling und kein zusätzlicher wiederkehrender Timer.
- Bei reiner Bewegung wird das vorhandene Overlay verschoben; Neuzeichnen
  und erneutes Anheben erfolgen nur bei Bedarf.
- Build, Start und erhaltene Bedienungshilfen-Berechtigung bestätigt. Finder-
  Testfenster geöffnet, eine Ziehgeste ausgeführt und das Testfenster geschlossen.
  Die verbleibende Bewegungsverzögerung wurde nicht quantitativ gemessen und
  hängt weiterhin von den AX-Antwortzeiten der Ziel-App ab.

## Toolchain-Besonderheiten

- Expliziter CoreGraphics-Import und `@preconcurrency import ApplicationServices`
  für die importierte AX-Konstante; App-Zustand und AX-Callbacks bleiben auf dem
  MainActor bzw. Haupt-RunLoop.
- Swift Testing statt des hier nicht vorhandenen XCTest-Frameworks.
- Das Testskript übergibt den installierten Testing-Makro-Pfad explizit und baut
  in einem temporären Ordner außerhalb der Dateisynchronisation.
- Das App-Buildskript erstellt das App-Bundle außerhalb der synchronisierten
  Dokumente unter `~/Library/Caches/FocusFrame/FocusFrame.app`. Der lokale
  `dist/FocusFrame.app`-Pfad ist ein Link dorthin. FinderInfo aus der
  Dateisynchronisation hatte auch nach erfolgreichem Start die Signatur verändert.
  Die Signatur wird im Skript jetzt zusätzlich streng geprüft.
- Der Linker meldet fehlende zusätzliche Suchpfade innerhalb der Command Line
  Tools. Build, Linken und Start sind trotzdem erfolgreich.
