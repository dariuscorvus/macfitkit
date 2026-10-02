# Lokale V1-Prüfung – 1. Oktober 2026

Neuester Stand: 0.5.2; die folgenden frühen V1-Ergebnisse bleiben als Verlauf
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

## 0.3.1 – Nutzerfeedback und Anmeldung

- Nutzer bestätigt: Ziehen „viel viel besser“ und Vollbild „in Ordnung“.
  Dies bestätigt die manuelle Nutzung, keine gemessene Latenz oder Abnahme
  sämtlicher Display-/Space-Anordnungen.
- iQualize-Quellcode verglichen: ebenfalls `SMAppService.mainApp.register()` /
  `.unregister()`, Systemstatus als Quelle. iQualize wird unter Applications
  installiert; FocusFrame startet nun dauerhaft aus `~/Applications/FocusFrame.app`.
- Anmeldung am neuen App-Pfad per UI registriert: macOS meldet „aktiv“.
- Tastenkürzel per UI registriert. Neue Statuszeile bestätigt die Registrierung
  und meldet empfangene Tastendrücke und Rahmenstatus. Automatisierte
  `ctrl+alt+f`-Eingabe lieferte keine Empfangsbestätigung; ein tatsächlicher
  physischer globaler Tastendruck bleibt unbestätigt. Kein behobener
  Tastenkürzelfehler wird daraus abgeleitet.
- Tatsächlicher Logout/Login bleibt offen; die Benutzersitzung wird dafür
  nicht unterbrochen.
- System-Anmeldeobjekt per `sfltool dumpbtm` am Benutzer-Applications-Pfad
  mit Status enabled/allowed gefunden. Nach App-Neustart zeigen Anmeldung und
  Tastenkürzel weiterhin ihren registrierten Status. Beide Optionen danach per
  UI wieder auf den bisherigen Zustand „aus“ gesetzt.
- `./script/check.sh`: alle 16 Tests, Build, Signaturprüfung und Diff-Prüfung
  erfolgreich. Installierte App anschließend neu gestartet; Prozess läuft aus
  dem dauerhaften Pfad. Neue Statuszeile im nativen Fenster sichtbar.

## 0.3.2 – Rahmen aktiv sichtbar bedienen

- Laufende App vor Änderung per UI geprüft: sechs empfangene Tastenkürzeleingaben,
  Rahmenstatus aktiv. Diagnose zeigte anschließend „Rahmen sichtbar“.
  Damit ist erstmals realer Tastenkürzelempfang in der laufenden App belegt;
  die zuvor erfolglose Automation war kein Nachweis eines defekten Hotkeys.
- Neuer Schalter „Rahmen aktiv“ in Verhalten per UI ausgeschaltet: Status pausiert;
  wieder eingeschaltet: Status aktiv. App bleibt aktiv, Tastenkürzel bleibt wie
  vom Nutzer eingestellt eingeschaltet.
- Build, Signaturprüfung, Prozessstart und Diff-Prüfung erfolgreich. Die reine
  GUI-Verdrahtung ändert keine Kernlogik; deren letzter Lauf bestand mit 16 Tests.

## 0.5.0 – Effekte und Animationen

Implementiert: getrennte kompatible Effektmodelle, zusätzliche Overlay-Ränder,
Core-Animation-Renderer für Overlay und Vorschau, vier scrollbar bedienbare
Einstellungsbereiche, Glow/Neon, Schatten, lineare/umlaufende Zweifarbverläufe,
Pulsieren/Blinken, getrennte Fokus-/Dauerauslöser und Verlaufsrotation.
„Bewegung reduzieren“ wird dynamisch beobachtet; verborgene/geschlossene
Vorschau und ausgeblendetes Overlay stoppen Animationen. Positionsänderungen
allein ändern weiterhin nur den Overlay-Ursprung.

Bestätigt:

- `./script/check.sh`: 22 Tests in fünf Suites erfolgreich, Build, strenge
  Signaturprüfung und Diff-Prüfung bestanden. Sechs neue Tests prüfen alte
  Konfigurationen ohne Effektfelder, komplette Effekt-Persistenz, ungültige
  Werte, Deckkraftgrenzen, unveränderte Geometrie bei ausgeschalteten Effekten,
  maximale Ausdehnung mit beiden Versatzrichtungen und Animationsauslöser.
- Native Oberfläche: alle vier Bereiche vorhanden, lange Seiten scrollbar,
  Leuchten/Schatten/Verlauf kombinierbar; Neon, linearer und umlaufender Verlauf
  sichtbar. Rotierender Verlauf zwischen zeitlich getrennten Screenshots verändert.
  Puls- und Blinkmodus auswählbar; Fokus-Testknopf vorhanden und betätigt.
- Neon, Schatten mit -20 pt X-Versatz, umlaufender Verlauf, Puls-Dauerbetrieb
  und Rotations-Dauerbetrieb nach Neustart identisch in den Einstellungen.
- Maximale Leuchtweite/Weichheit 40 pt, Ausbreitung 20 pt und Versatz +/-40 pt
  per UI eingestellt. Gefundener Skalierungsfehler der Vorschau behoben:
  Layer-Transformation vor neuer Geometrie zurücksetzen; Szene danach korrekt
  innerhalb der Vorschau. Einseitiger Versatz bleibt in der Vorschau erhalten.
- Fixture-Move und -Resize per AppKit erfolgreich. Diagnose erfasst beim
  erstmaligen Aktivieren genau ein Fokusereignis, bei folgenden Move/Resize
  kein weiteres; Wechsel von Fenster B zu A erzeugt genau ein neues Ereignis.
  Einzelne AX-Abfragen dabei 0.11–0.14 ms; keine Bildschirm-Latenzmessung.
- Kurze Prozess-CPU-Stichprobe über jeweils 3 Sekunden: mit aktivierter
  Puls-/Rotationskonfiguration 0.02 s zusätzliche Prozess-CPU; mit statischem
  Rahmen keine Änderung bei 0.01-s-Anzeigeauflösung. Keine Aussage über GPU,
  WindowServer, Langzeitlast oder allgemeine Leistungsgarantie.
- Nach kleinen Renderer-/Vorschaukorrekturen nochmals gebaut, streng signiert
  und lokal gestartet. Alle neuen Effekte nach UI-Prüfung separat zurückgesetzt;
  ursprüngliche Rahmenwerte, Tastenkürzel und Vollbildregel bleiben erhalten.

Praktische Grenzen:

- Die Automation liefert zugeschnittene Screenshots der Ziel-App; äußere
  Overlay-Effekte werden darin nicht vollständig mit aufgenommen. Sichtbare
  Übereinstimmung zwischen Vorschau und fremdem Fensterrahmen ist daher noch
  mit echter Nutzung zu bestätigen.
- Echtes manuelles Ziehen, maximale Effekte in Vollbild/Spaces und Wechsel
  realer Displays sowie Änderungen der macOS-Bewegungseinstellung sind noch
  manuell abzunehmen. Die vorhandene Zieh-/Vollbildbestätigung des Nutzers
  bezog sich auf den vorherigen Renderer. Automatisierte Kernprüfungen ersetzen
  diese Abnahme nicht.

## 0.5.1 – weicher Abschluss der Fokus-Deckkraftanimation

Ursache: repeatDuration schnitt den 2-s-Puls nach 1.5 s ab. Die angezeigte
Deckkraft war dann nicht identisch mit der statischen Layer-Deckkraft und
sprang beim Entfernen der Animation zurück.

Fokus-Puls und -Blinken verwenden nun eine einmal vorbereitete Kurve über die
exakte Fokusdauer. Ein-/Ausblendung erfolgt mit einer Kosinus-Hüllkurve; der
letzte Wert ist exakt die normale Deckkraft. Erneute Auslösung übernimmt die
aktuell angezeigte Deckkraft als Start. Core Animation interpoliert die Werte;
keine neuen Timer/AX-Abfragen. Daueranimationen bleiben unverändert.

- 25 Tests in sechs Suites, Build, Signaturprüfung und Diff-Prüfung erfolgreich.
- Neue Regressionstests: 1.5-s-Fokusdauer bei 2-s-Puls, weicher Endbereich,
  maximale Pulsdeckkraft unter normaler Deckkraft, kurze Fokusdauer und
  erneute Auslösung beider Modi ab einem Zwischenwert.
- App neu installiert/gestartet. Nutzereinstellung Pulsieren, 2 s Zyklus,
  40–100 %, Fokusdauer 1.5 s erhalten; Vorschau-Testknopf ausgelöst.
  Die wahrgenommene Glätte beim echten Fokuswechsel bleibt Nutzerabnahme.

## 0.5.2 – klassisches Xcode-Projekt

- `FocusFrame.xcodeproj` hinzugefügt: App, statische Kernbibliothek, eigenständiges
  Swift-Testing-Target und Fixture-App. Geteilte Schemes FocusFrame und
  FocusFrameFixture, Debug-/Release-Konfigurationen, keine externen Pakete.
- Alle bestehenden Swift-Dateien sind dem passenden Target zugeordnet; dieselben
  Dateien bleiben über Package.swift nutzbar. Version/Build sind zentral in
  Config/Version.xcconfig; Script-Bundle und Xcode-Projekt verwenden sie gemeinsam.
- Native Plist-Prüfung und lokale Strukturprüfung (Quellenzuordnung, Core-Link/
  Target-Abhängigkeiten, Scheme-Verweise) erfolgreich. Diese Prüfung ist kein
  Xcode-Build und kann Xcode-spezifische Build-/Signingfehler nicht ausschließen.
- Gemeinsamer Check erfolgreich: 25 Swift-Tests in sechs Suites, SwiftPM-Build,
  lokale strenge Signaturprüfung und Diff-Prüfung.
- `xcodebuild -list -project FocusFrame.xcodeproj` und optionaler Script-Modus
  --xcode sind hier durch fehlendes vollständiges Xcode blockiert. Aktiv ist
  /Library/Developer/CommandLineTools; /Applications/Xcode.app existiert nicht.
  Kein Xcode-/Instruments-/Xcode-Test-Erfolg wird behauptet. Keine Installation
  oder globale Umstellung des Developer-Verzeichnisses durchgeführt.

## 0.5.2 – Release-Datei für Freunde

- Universal-Release-Build für arm64 und x86_64 erfolgreich, optimiert und mit
  macOS 14.0 Deployment-Metadaten in beiden Executable-Slices.
- App mit gültiger Developer ID Application (Team 4WF4549NW5), Zeitstempel und
  Hardened Runtime signiert. App und DMG streng geprüft; DMG-Prüfsumme gültig.
- App aus finaler HFS+-DMG read-only geprüft, in einen frischen Cache-Ordner
  kopiert und erneut verifiziert. Diese Release-Kopie lokal gestartet; native
  Einstellungen sichtbar. Danach vorher installierte Entwicklungs-App gestartet.
- Separate SHA-256-Datei, Installationsanleitung, Source-Revision und
  Verification.txt im Release-Ordner. Bestehende Swift-Prüfungen zuletzt 25/25
  erfolgreich; seitdem keine Funktionsänderung, nur Release-Verpackung.
- Gatekeeper: rejected / source=Unnotarized Developer ID. Nutzer bestätigt,
  dass noch kein Notarisierungsprofil eingerichtet ist. Daher ausdrücklich
  „unnotarized“ im Dateinamen; keine Apple-Notarisierung behauptet. Einzel-App-
  Freigabe beim ersten Start nach Apples dokumentiertem Ablauf beschrieben.
- Lokaler Start ist kein Download-/Quarantäne-Test auf einem fremden Mac.
  Ausführung auf Intel und tatsächlichem macOS 14 bleiben ungetestet; Universal-
  Architektur und Deployment-Metadaten sind geprüft.
- Kein Git-Remote vorhanden; keine öffentliche Veröffentlichung und keine
  Übermittlung an Apple durchgeführt. Lokale DMG kann privat weitergegeben werden.

## 0.5.3 – Rahmenversatz am oberen Bildschirmrand

- Ursache lokal reproduziert: NSPanel.setFrameOrigin begrenzt die Oberkante
  an der sichtbaren Bildschirmfläche, während die Größensetzung die angefragte
  Geometrie beibehält. Ein transparenter Effektrand oberhalb der Menüleiste
  verschiebt dadurch auch die eigentliche Kontur nach unten. Ein gleich großes
  neu fokussiertes Fenster verwendet ebenfalls den Positionspfad.
- Gegenprobe mit unverändertem OverlayWindow aus vorherigem Commit scheitert
  im Desktop-Regressionslauf: angefordert (97, 816, 606, 426), tatsächlich
  (97, 813, 606, 426). Separater NSPanel-Probe mit größeren Rändern: 40/70 pt Versatz.
- OverlayWindow überschreibt constrainFrameRect und gibt die berechnete
  Geometrie unverändert zurück. Fensterlevel, Klickdurchleitung, AX-Ereignisse
  und Mausnachführung bleiben erhalten; keine zusätzlichen Abfragen oder Timer.
- script/test_overlay_geometry.sh: 108 Prüfungen am tatsächlichen Overlay/Renderer
  erfolgreich, inklusive gleich großem Fokusziel, Resize, oberem/linkem Rand,
  virtuellem Ziel oberhalb des Displays und maximalen Effekten/Versätzen.
  Probe benötigt eine Desktop-Sitzung, keine AX-Berechtigung. Getestet an einem
  angeschlossenen Display; keine physische Mehrschirm- oder Intel-Abnahme.
- Bestehender Check: 25/25 Kernprüfungen, SwiftPM-Build, strenge Signaturprüfung
  und Xcode-Strukturprüfung erfolgreich. Vollständiges Xcode weiterhin nicht
  vorhanden. Bestätigung des sporadischen Fokuswechsels beim Nutzer steht aus.
- 0.5.3 lokal installiert und Prozessstart bestätigt. Universal-Release-DMG
  für Intel/Apple Silicon erstellt; App-/DMG-Signaturen, Architektur, macOS-
  Mindestversion und DMG-Prüfsumme erneut bestanden. Weiterhin nicht notarisiert.

## 0.6.0 – lokale Einstellungen und Zahlenwerte (2026-10-02)

- Sieben native Seiten mit Sidebar, gruppierten und bedingt sichtbaren Reglern.
  Separate Vorschau entfernt; der echte Rahmen folgt dem eigenen Einstellungsfenster
  über AppKit-Ereignisse. Kein zusätzlicher AX-Abfragetimer. Menü vereinfacht.
- Native Integration mit isoliertem Preferences-Speicher bestanden: alle sieben
  Seiten ohne Fenstergrößenänderung; Eingabefeld je Zahlenregler; Dezimalkomma/
  Punkt, ungültiger Text, Begrenzung und erneutes Laden; echter Rahmen,
  Darstellungsänderung, Animation, Pause/Fortsetzen, Move, Resize, Klickdurchleitung
  und Stopp. Keine persönlichen Einstellungen durch diesen Test verändert.
- 162 tatsächliche AppKit-Overlay-Geometrieprüfungen bestanden, einschließlich
  der alten Screenshot-Werte und neuer Maximalwerte (100 pt Stärke, 200 pt Abstand/
  Effekte, 300 pt Radius, Schattenversatz ±200 pt), oberer/linker Rand und
  gleich großer Fensterwechsel. Ein physisches Display; kein Intel-/Mehrschirmtest.
- Radius-Machbarkeit separat untersucht: transparente Einzel-Fensteraufnahme
  mit bereits vorhandener Aufnahmeberechtigung; kreisförmige Näherung rund
  17 pt bei Finder, Systemeinstellungen und FocusFrame, ca. 51–130 ms je Aufnahme.
  Chrome nicht verfügbar. Keine Bilder/Titel gespeichert, kein automatischer
  Radiusmodus und keine neue Berechtigungsanforderung in der produktiven App.
- Vollständiges Xcode weiterhin nicht installiert: Strukturprüfung ersetzt keinen
  Xcode-Build. Kein neuer Release, keine DMG und kein Rollout in dieser Etappe.
- Gemeinsamer Check bestanden: 26 Kernprüfungen in sechs Suites, SwiftPM-Build,
  strenge Signaturprüfung und Xcode-Projektstruktur. Lokale 0.6.0/Build 4
  installiert und mit Einstellungen gestartet. Direkte UI-Gegenprobe: 24,5 pt
  per Enter übernommen, Regler synchronisiert, anschließend ursprüngliche
  Stärke 3 pt wiederhergestellt.

## 0.6.0 / Build 5 – Release mit Standardradius 18,5 pt

- Standard- und ungültiger Radius-Fallback auf 18,5 pt gesetzt. Vorhandene
  Radiuswerte bleiben unverändert; Zurücksetzen verwendet den neuen Standard.
- 26 Kernprüfungen, SwiftPM-Build, strenge lokale Signaturprüfung und
  Xcode-Strukturprüfung erfolgreich. Vorherige native UI-/Overlay-Prüfungen
  gelten für dieselbe Implementierung; nur Standardradius geändert.
- Universal-Release für arm64/x86_64, macOS-Mindestversion 14.0 in beiden
  Executable-Slices, Developer-ID-Signatur mit Zeitstempel und Hardened Runtime.
  Signaturen von DMG und tatsächlich enthaltener App streng geprüft; DMG-
  Integrität und separate SHA-256-Prüfsumme bestanden. Source: e565e08.
- App aus der finalen DMG in frischen Cache-Pfad kopiert, erneut signaturgeprüft
  und gestartet; native Einstellungen mit 18,5 pt sichtbar. Danach aktuellen
  Entwicklungsstand wieder lokal installiert und gestartet.
- Gatekeeper bestätigt Unnotarized Developer ID. Kein Profil vorhanden,
  keine Übermittlung an Apple und keine öffentliche Veröffentlichung.
  Intel-Ausführung, fremde Download-Quarantäne und vollständiges Xcode
  bleiben ungetestet. Installationshinweise auf neue Menüstruktur aktualisiert.
