# FocusFrame

Eine kleine native macOS-App, die das aktuell fokussierte Fenster mit einem
klicktransparenten Rahmen hervorhebt. Swift 6 / AppKit, ohne externe Abhängigkeiten.

## Voraussetzungen und Start

- macOS 14 oder neuer.
- Swift 6 oder neuer, beispielsweise über Xcode Command Line Tools.
- Bedienungshilfen-Zugriff für **FocusFrame**.

```sh
./script/build_and_run.sh
```

Das Skript baut mit SwiftPM, erstellt und signiert lokal die App unter
`~/Library/Caches/FocusFrame/FocusFrame.app` und stellt sie auch über den Link
`dist/FocusFrame.app` bereit. Der Cache-Pfad verhindert, dass die
Dokumentensynchronisation die Bundle-Signatur nach dem Start verändert.
Auch der Codex-Run-Button verwendet dieses Skript.
FocusFrame erscheint als Rahmen-Symbol in der Menüleiste, ohne Dock-Symbol.

Beim ersten Start fordert macOS die Bedienungshilfen-Berechtigung an. Unter
**Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen** FocusFrame
aktivieren. Falls nötig `~/Library/Caches/FocusFrame/FocusFrame.app` mit dem
Plus-Button hinzufügen (im Dateidialog `⌘⇧G` drücken und den Pfad einfügen).
Anschließend im FocusFrame-Menü **Berechtigung erneut prüfen** wählen oder zu
einer anderen App wechseln. Die App prüft Berechtigungen bei Ereignissen und
auf Anforderung, ohne wiederkehrenden Timer. Falls macOS nach einem Neubau den
Eintrag nicht erkennt, FocusFrame aus der Berechtigungsliste entfernen und erneut
hinzufügen. Die lokale Signatur ist keine Developer-ID-Signatur.

Im Menü lassen sich der Rahmen ein-/ausschalten, vier Farben und Stärken von
2, 3, 4 oder 6 Punkten wählen. Farbe und Stärke werden lokal gespeichert.

## Architektur

```text
NSWorkspace (App-/Space-/Sleep-Ereignisse)
    ↓
AccessibilityService (AXUIElement / AXObserver)
    ↓
FocusManager (Fokus, Ereignisse bündeln, Koordinaten)
    ↓
OverlayWindow (nicht aktivierbares, klicktransparentes NSPanel)
```

- Der AccessibilityService beobachtet ausschließlich die aktive App und deren
  fokussiertes Fenster. Beim App-/Fensterwechsel entfernt er alte Beobachtungen.
- Fokus, Verschieben, Größe, Minimieren und Schließen werden über AX-Ereignisse
  verfolgt. Fehlende oder ungültige Fensterdaten blenden den Rahmen aus.
- Bewegungs-/Größenereignisse lesen die Geometrie des bereits beobachteten
  Fensters direkt in einer AX-Anfrage. Globale Maus-Ziehereignisse ergänzen diese
  Aktualisierung während einer Ziehgeste, falls eine App AX-Meldungen verzögert.
  Es gibt weiterhin keinen wiederkehrenden Timer.
- NSWorkspace meldet App- und Space-Wechsel, Ruhezustand und Aufwachen.
  Displayänderungen kommen von AppKit. Ein Space-Wechsel löst genau eine um
  150 ms verzögerte Aktualisierung aus; es gibt kein Polling.
- AX-Koordinaten werden anhand der Oberkante des Hauptdisplays nach AppKit
  umgerechnet, einschließlich negativer Koordinaten für weitere Monitore.
- Der Rahmen liegt außerhalb des Fensters, nimmt weder Fokus noch Mausklicks
  an und zeichnet keine gefüllte Fläche über den Inhalt. Seine Ecken sind
  abgerundet (10 pt Innenradius); beim Verschieben wird er ohne Neuzeichnen
  versetzt. macOS stellt keinen universellen AX-Wert für den Fensterradius bereit,
  daher ist dies eine feste Annäherung an native Fenster.

## Build und Tests

```sh
./script/test.sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh --verify
```

`--verify` bestätigt den laufenden Prozess, nicht die sichtbare Rahmenfunktion.
`--debug`, `--logs` und `--telemetry` starten Debugger bzw. lokale Logs.
Das Testskript verwendet Swift Testing und einen temporären Buildordner außerhalb
von synchronisierten Dokumentenordnern. Es übergibt den vorhandenen
Testing-Makro-Pfad explizit, um einen Fehler des Swift-6.4-Buildsystems zu umgehen.
Mit einer vollständigen Xcode-Installation kann auch `swift test` verwendet werden.
Die Unit-Tests prüfen Koordinaten auf verschieden angeordneten Displays,
ungültige Geometrie und den äußeren Rahmenabstand.

Manuelle Abnahme mit erlaubten Bedienungshilfen:

1. Zwischen Finder, Browser und Editor sowie zwei Fenstern derselben App wechseln.
2. Das fokussierte Fenster verschieben und skalieren; der Rahmen folgt.
3. Minimieren, schließen und eine App ohne Fenster aktivieren; kein alter Rahmen bleibt.
4. Durch Rahmen und Fenster klicken; FocusFrame übernimmt keinen Fokus.
5. Farbe und Stärke ändern, neu starten und gespeicherte Einstellungen prüfen.
6. Fenster auf Monitore links/oberhalb/unterhalb verschieben und Displays neu verbinden.
7. Spaces und Vollbild wechseln, Ruhezustand/Aufwachen sowie Berechtigungsentzug prüfen.

## Grenzen der V1

Apps können einzelne AX-Ereignisse oder Fensterattribute nicht unterstützen.
In solchen Apps ist die Aktualisierung bis zum nächsten unterstützten Ereignis
eingeschränkt; es gibt bewusst keinen Polling-Fallback. Vollbild/Spaces verwenden
öffentliche AppKit-Optionen (`canJoinAllSpaces`, `fullScreenAuxiliary`); ihre
Darstellung hängt auch vom Verhalten der Ziel-App und macOS ab und muss auf dem
jeweiligen Mac geprüft werden. Der äußere Rahmen kann an Bildschirmrändern
abgeschnitten sein. Mission Control und Stage Manager sind noch nicht gesondert
abgenommen. Kein Autostart, Glow, Animationen, App-Ausnahmen oder Installer.

Die App liest nur die AX-Fenstergeometrie und den Fokus. Sie erfasst keine
Fensterinhalte und hat keine Netzwerkfunktion.
