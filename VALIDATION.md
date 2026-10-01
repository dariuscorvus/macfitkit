# Lokale V1-Prüfung – 1. Oktober 2026

Neuester Stand: 0.3.0; die folgenden frühen V1-Ergebnisse bleiben als Verlauf
erhalten. Die aktuelle Abnahme steht am Ende dieses Dokuments.

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

## Zweite Bewegungsnachbesserung

Der Nutzer bestätigt, dass die erste Optimierung das sichtbare Nachziehen nicht
beseitigt hat. Der damalige Mausereignispfad las weiterhin synchron über AX und
konnte damit dieselben verzögerten Positionen übernehmen.

Nun wird bei Mausdruck in der Titelregion ein Anker gespeichert. Nach der ersten
AXMoved-Bestätigung folgt das Overlay ausschließlich den aktuellen Mauskoordinaten,
ohne weitere AX-Abfragen auf diesem Bewegungspfad. Größenänderungen, Fokus-/Space-
Wechsel und Loslassen beenden die Vorhersage. Nach Loslassen gibt es genau einen
verzögerten Abgleich nach 50 ms, keinen wiederkehrenden Timer.

- `./script/test.sh`: 8 Tests in zwei Suites erfolgreich, einschließlich
  Bewegung nur nach Bestätigung, Aufholen der aktuellen Mausposition,
  Richtungswechsel ohne Drift und wiederholter AX-Meldungen ohne Neuverankerung.
- `./script/build_and_run.sh --verify`: erfolgreicher Build und Start.
- Im laufenden Prozess ist die Bedienungshilfen-Berechtigung weiter vorhanden.
- Die automatisierte Finder-Ziehgeste hat die neue Vorhersage im Protokoll nicht
  nachweisbar aktiviert. Die wahrgenommene Flüssigkeit ist daher noch durch
  echtes manuelles Ziehen zu bestätigen; keine gemessene Latenzgarantie.

## 0.3.0 – freigegebene Roadmap

Implementiert: native Darstellungseinstellungen und gemeinsame Rahmenvorschau,
freie Farbe/Deckkraft/Stärke/Radius/Abstand, persistierte Konfiguration mit
Übernahme alter Werte, optionale Autostart-Registrierung, globales ⌃⌥F,
App-Ausnahmen, Vollbildregel, Diagnose im Arbeitsspeicher, lokale Test-App und
gemeinsamer Prüfaufruf.

Bestätigt:

- `./script/check.sh`: 16 Tests in vier Suites, Build und strenge Signaturprüfung
  erfolgreich. Tests umfassen Geometrie, Ziehgesten, Konfigurationsgrenzen,
  Persistenzformat und Sichtbarkeitsregeln. Nach kleineren GUI-/Zustandsanpassungen
  wurde die App nochmals gebaut und gestartet.
- Native Vorschau sichtbar. Radius 16 pt, Abstand 4 pt und Deckkraft 80 % per UI
  eingestellt; dieselben Werte nach Neustart wieder angezeigt. Danach ursprüngliche
  Darstellung mit 3 pt Stärke, 10 pt Radius, 0 pt Abstand und 100 % Deckkraft wiederhergestellt.
- Optionales Tastenkürzel registrierbar; Checkbox und Vollbildregel bleiben nach
  Neustart erhalten. Physische globale Tasteneingabe wurde nicht bestätigt.
- Native ServiceManagement-Registrierung für Anmeldung einmal eingeschaltet:
  OS-Status „aktiv“. Wieder ausgeschaltet: OS-Status „ausgeschaltet“. Kein tatsächlicher
  Logout/Login während der Abnahme.
- Test-App in Ausnahmeliste hinzugefügt, bei Fokus als „App ausgeschlossen“ in der
  Diagnose erfasst und anschließend aus der Liste entfernt.
- Testfenster programmatisch um +90/+40 pt verschoben und um +50/+20 pt vergrößert;
  die Anzeige bestätigt diese Änderungen. Die Test-App aktiviert sich für die Prüfung.
- Optionale Diagnose sichtbar, Zustandsereignisse und AX-Abfragezeiten erfasst
  (einzelne beobachtete Werte 0.12–0.47 ms; keine Latenzgarantie oder Bildschirmmessung).
- Test-App nach der Abnahme beendet. Autostart, Tastenkürzel, Vollbildregel und
  Diagnose sind im zurückgestellten Testzustand ausgeschaltet; keine App-Ausnahme bleibt.

Noch offen:

- Wahrgenommene Flüssigkeit echter Ziehgesten und sichtbarer Versatz des Overlays.
- Vollbild/Spaces: UI-Test wegen ScreenCaptureKit-Aufnahmefehler der Automation
  abgebrochen. Regel und persistierte Einstellung sind geprüft, echte Darstellung
  auf allen Spaces damit nicht bestätigt.
- Reale Mehrschirm-/Stage-Manager-/Mission-Control- und Anmeldeszenarien.
- Das App-Bundle bleibt am Entwicklungs-Cache-Pfad. Dauerhafter Installationspfad
  und Developer-ID-Verteilung sind eine spätere Etappe.

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
