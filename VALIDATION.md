# Lokale V1-Prüfung – 1. Oktober 2026

Umgebung: Apple Silicon, Swift 6.4, Command Line Tools, macOS-27-SDK.
Deployment Target: macOS 14. Keine externen Paketabhängigkeiten.

## Bestätigt

- `./script/build_and_run.sh --verify`: Build, lokale Bundle-Signierung,
  Start über Launch Services und laufender FocusFrame-Prozess erfolgreich.
- `./script/test.sh`: 4 Tests in einer Suite erfolgreich. Geometrie auf dem
  Hauptdisplay, Display-Anordnungen links/oben/unten, ungültige Fensterdaten
  und Rahmenabstand.
- Startprotokoll: `Started; accessibility trusted: false`. Der Start ohne
  Bedienungshilfen-Zugriff verursacht keinen Absturz.
- `git diff --check`: erfolgreich.

## Noch manuell zu prüfen

Die Bedienungshilfen-Berechtigung wurde noch nicht erteilt. Deshalb sind
sichtbarer Rahmen, AX-Ereignisse beim Fokuswechsel/Verschieben/Skalieren,
Klickdurchleitung, reale Multi-Monitor-, Spaces- und Vollbild-Szenarien noch
nicht praktisch abgenommen. Die UI-Automation war beim Prüfversuch nicht
erreichbar (Timeout). Die manuelle Prüfliste steht in der README.

## Toolchain-Besonderheiten

- Expliziter CoreGraphics-Import und `@preconcurrency import ApplicationServices`
  für die importierte AX-Konstante; App-Zustand und AX-Callbacks bleiben auf dem
  MainActor bzw. Haupt-RunLoop.
- Swift Testing statt des hier nicht vorhandenen XCTest-Frameworks.
- Das Testskript übergibt den installierten Testing-Makro-Pfad explizit und baut
  in einem temporären Ordner außerhalb der Dateisynchronisation.
- Das App-Buildskript entfernt erweiterte Attribute ausschließlich vom erzeugten
  App-Bundle vor der Signierung. FinderInfo aus der Dateisynchronisation hatte
  die Signierung verhindert.
- Der Linker meldet fehlende zusätzliche Suchpfade innerhalb der Command Line
  Tools. Build, Linken und Start sind trotzdem erfolgreich.
