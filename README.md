# FocusFrame

Kleine native macOS-Menüleisten-App: markiert das fokussierte Fenster mit einem
klicktransparenten Rahmen. Swift 6 / AppKit, keine externen Paketabhängigkeiten.
Aktueller Entwicklungsstand: 0.5.2.

## Start

Voraussetzungen: macOS 14 oder neuer, Swift 6 oder neuer und erlaubte
Bedienungshilfen für FocusFrame.

```sh
./script/build_and_run.sh
```

Das Skript baut und signiert lokal und installiert zum Starten nach
`~/Applications/FocusFrame.app`. Der feste Benutzer-App-Ordner bleibt auch nach
Cache-Bereinigung bestehen. `dist/FocusFrame.app` verlinkt die zuletzt gebaute
bzw. gestartete App. Reine `--build-only`-Prüfungen verwenden weiterhin das
Staging-Bundle unter `~/Library/Caches/FocusFrame/FocusFrame.app` und ändern
keine installierte App. Der Codex-Run-Button verwendet dasselbe Skript.

Beim ersten Start den Bedienungshilfen-Zugriff unter **Systemeinstellungen →
Datenschutz & Sicherheit → Bedienungshilfen** erlauben. Falls FocusFrame fehlt,
mit **+** hinzufügen und im Dateidialog mit **⌘⇧G** den obigen App-Pfad öffnen.
Danach **Berechtigung erneut prüfen** im Menüleistenmenü wählen. Bei Problemen
nach einem Neubau den Eintrag entfernen und die App erneut hinzufügen.

## Xcode

`FocusFrame.xcodeproj` ist ein klassisches macOS-App-Projekt ohne externe Pakete.
Es verwendet dieselben Quellen wie `Package.swift`; kein Code wird dupliziert.
Zum Öffnen/Builden wird vollständiges Xcode mit Swift 6 benötigt (Xcode 16 oder neuer).
Command Line Tools allein reichen für den bisherigen SwiftPM-Workflow.

1. `FocusFrame.xcodeproj` öffnen und Scheme **FocusFrame** auswählen.
2. Eine bereits laufende FocusFrame-Instanz über ihr Menü beenden, damit nicht
   gleichzeitig zwei Rahmen-Apps laufen.
3. **⌘R** baut und startet die Menüleisten-App; im Debug-Scheme öffnet `--settings`
   zusätzlich die Einstellungen. **⌘U** führt die Kernprüfungen aus; **⌘I** öffnet
   Instruments zum Profilieren des Release-Builds.
4. Scheme **FocusFrameFixture** startet die Testfenster-App.

Die Targets sind App, statische Kernbibliothek, eigenständige Swift-Testing-Suite
und Testfenster-App. Debug und Release sind konfiguriert; lokal wird ad-hoc signiert.
Sandbox ist deaktiviert, damit die vorhandene Accessibility-Funktion funktioniert.
Für spätere Verteilung müssen Developer-ID-Signing/Notarisierung separat eingerichtet
werden. Ein Start aus Xcode erfolgt aus dessen Build-Verzeichnis; bei Bedarf diese
App in den Bedienungshilfen freigeben. Anmeldung weiterhin für die fest installierte
App konfigurieren.

Version und Buildnummer stehen gemeinsam in `Config/Version.xcconfig` und werden
auch vom SwiftPM-App-Skript verwendet. Optionaler Xcode-Build mit Installation und
Start über denselben Skript-Einstieg:

```sh
./script/build_and_run.sh --xcode
```

Dafür muss das aktive Developer-Verzeichnis auf vollständiges Xcode zeigen;
`DEVELOPER_DIR` kann alternativ für diesen Aufruf gesetzt werden.
`script/check_xcode_project.py` prüft Quellenzuordnung, Target-Abhängigkeiten und
geteilte Schemes ohne Xcode. Das ersetzt keinen Xcode-Build.

## Einstellungen

Im Menüleistenmenü **Einstellungen …** öffnen:

- **Darstellung:** freie Rahmenfarbe, Deckkraft 10–100 %, Stärke 1–12 pt,
  Eckenradius 0–40 pt und Abstand 0–20 pt. Die Vorschau verwendet denselben
  Zeichenpfad wie das echte Overlay. Darstellung kann separat zurückgesetzt werden.
- **Effekte:** Glow/Neon mit Intensität, Leuchtweite, eigener oder übernommener
  Rahmenfarbe und Neon-Kern; Schatten mit Farbe, Deckkraft, Weichheit, Ausbreitung
  und X-/Y-Versatz; linearer oder umlaufender Zweifarbenverlauf mit Winkel.
- **Animation:** Pulsieren oder Blinken mit Zyklusdauer und Deckkraftgrenzen;
  unabhängige Verlaufsrotation mit Richtung und Umlaufdauer. Für beide separat
  „nur beim Fokuswechsel“ oder „dauerhaft“, mit einstellbarer Fokusdauer.
- Vorschau in Darstellung/Effekte/Animation nutzt denselben Renderer wie der echte
  Rahmen. „Fokuswechsel testen“ spielt gewählte Fokusanimationen ab. Bei großen
  Effekten skaliert die Vorschau die gesamte Szene; Angaben bleiben echte Punkte.
- Jeder Effekt ist separat zurücksetzbar. Grunddarstellung zurücksetzen verändert
  keine Effekte. Neue Effekte sind zunächst ausgeschaltet; alte Einstellungen
  bleiben erhalten. Lange Seiten sind scrollbar.
- Glow und Neon sind Alternativen; Schatten, Verlauf und Animation sind frei
  kombinierbar. Übernommene Leuchtfarbe verwendet bei Verlauf dessen erste Farbe.
  Positiver vertikaler Schattenversatz bedeutet nach unten.
- Animationen laufen über Core Animation, ohne Zeichentimer oder weitere
  AX-Abfragen. Verborgene Rahmen stoppen die Animationen. macOS „Bewegung
  reduzieren“ schaltet Animationen zur Laufzeit aus, ohne die Auswahl zu löschen.
- **Verhalten:** Rahmen aktivieren/pausieren, Start bei Anmeldung, optionales globales Tastenkürzel **⌃⌥F**,
  Ausblenden im Vollbild und eine Liste ausgeschlossener Apps.
- Die Konfiguration wird lokal gespeichert. Bestehende Farb-/Stärkeeinstellungen
  der ersten Version werden übernommen.
- Autostart verwendet den nativen macOS-Service. Angezeigter Status kommt von
  macOS; erforderliche Bestätigung und Fehler werden sichtbar angezeigt.
- Ein belegtes Tastenkürzel wird mit einer Fehlermeldung abgelehnt. Es liest
  keine Tastatureingaben mit, sondern registriert ausschließlich diese Kombination.
  Unter **Verhalten** zuerst aktivieren und **Control + Option + F** drücken
  (Control, nicht Command). Die Statuszeile zeigt Registrierung, empfangene
  Tastendrücke und „Rahmen: aktiv/pausiert“ unmittelbar. Zum globalen Test ein
  anderes App-Fenster aktivieren, drücken und anschließend den Status ansehen.

Die App bleibt ohne Dock-Symbol in der Menüleiste. **Rahmen aktiv** pausiert die
Markierung. Einstellungen und Diagnose können geschlossen werden, ohne die App
zu beenden. Autostart und Tastenkürzel sind anfangs ausgeschaltet.

## Diagnose

**Diagnose …** öffnet die optionale Erfassung. Maximal 300 Ereignisse bleiben
im Arbeitsspeicher: Zustandswechsel, Beginn/Ende einer Ziehgeste und Dauer von
AX-Geometrieabfragen. Keine Fensterinhalte, Titel oder App-Kennungen. Mit
**Aktualisieren** wird eine Momentaufnahme angezeigt; es gibt keinen
wiederkehrenden Diagnosetimer. Ausschalten löscht die Einträge. Ein Neustart
startet mit deaktivierter Erfassung. Abfragezeit ist keine Messung sichtbarer Latenz.

## Architektur

```text
NSWorkspace + AXObserver + Mausereignisse
    ↓
AccessibilityService → FocusManager → OverlayWindow
                            ↑
                     PreferencesStore
                            ↓
                     EffectRenderer (Overlay + Vorschau)
```

`FocusFrameCore` enthält testbare Geometrie, Konfiguration, Sichtbarkeitsregeln
und den Zustand einer Ziehgeste. Die GUI bleibt AppKit; Vorschau und Overlay
teilen ihren Zeichenpfad.

Fokus/Minimieren/Schließen laufen über AX-Ereignisse. Bewegungs-/Größenereignisse
lesen die bekannte Fenstergeometrie gebündelt. Bei Mausdruck in der Titelregion
werden Maus- und Fensterposition verankert. Nach AXMoved-Bestätigung folgt der
Rahmen dem Mausweg ohne weitere AX-Abfragen während dieses Ziehens. Resize,
Fokus-/Displaywechsel und Berechtigungsverlust unterbrechen die Verfolgung.
Nach Loslassen erfolgt ein einmaliger Abgleich nach 50 ms. Ein Space-Wechsel
verwendet einen einmaligen Abgleich nach 150 ms. Kein periodisches Polling.

AX-Koordinaten werden an der Hauptdisplay-Oberkante umgerechnet, einschließlich
negativer Koordinaten bei weiteren Displays. Das Overlay kann weder Key- noch
Main-Window werden und nimmt keine Mausklicks an.

## Entwicklung und Prüfungen

```sh
./script/check.sh                     # Tests, Build, Signatur, Whitespace
./script/build_and_run.sh --settings  # Einstellungsfenster direkt öffnen
./script/build_and_run.sh --diagnostics
./script/fixture.sh                   # Zwei reproduzierbare Testfenster
```

Weitere Buildmodi: `--build-only`, `--verify`, `--debug`, `--logs`, `--telemetry`.
`--verify` bestätigt einen laufenden Prozess, keine korrekte sichtbare Darstellung.
Das Testskript verwendet Swift Testing, einen temporären Buildordner außerhalb
synchronisierter Dokumente und den expliziten Testing-Makro-Pfad als Umgehung
für die lokale Swift-6.4-Toolchain. `FocusFrameFixture` ist ausschließlich ein
Entwicklungswerkzeug und wird nicht in FocusFrame eingebaut.

[Entwicklungsablauf](DEVELOPMENT.md), [Prüfnachweise](VALIDATION.md),
[Roadmap](ROADMAP.md) und [Änderungen](CHANGELOG.md).

## Grenzen

Apps unterstützen AX-Attribute und Ereignisse unterschiedlich. Titel-Ziehgesten
werden in den obersten 64 pt ohne Resize-Kante erkannt und erst nach AXMoved
vorhergesagt. Apps, die erst nach Loslassen melden oder andere Bereiche als
Ziehgriff verwenden, können weiterhin verzögert aktualisiert werden. Besondere
Snap-/Begrenzungsregeln können während der Vorhersage abweichen; nach Loslassen
wird die echte Geometrie übernommen. Der Eckenradius ist eine manuelle Annäherung,
keine automatische Erkennung fremder Fensterformen. Bildschirmränder können
Teile des äußeren Rahmens abschneiden.

Reale Mehrschirm-, Spaces-, Vollbild-, Mission-Control- und Stage-Manager-Szenarien
sind noch nicht vollständig praktisch abgenommen. Vollbild nutzt öffentliche
AppKit-Optionen und AXFullScreen, sofern die Ziel-App dieses Attribut bereitstellt.
Ein tatsächlicher Anmeldestart und physische Tastenkürzeleingabe benötigen
manuelle Prüfung. Lokale Ad-hoc-Signatur, noch keine Notarisierung/Verteilung.
Kein Glow, Preset-System, Installer oder Update-Dienst. Keine Netzwerkfunktion.

## Release für Freunde

`./script/release.sh` erstellt einen optimierten Universal-Build (Apple Silicon
und Intel, macOS 14+), Developer-ID-signierte App mit Hardened Runtime und eine
signierte DMG mit Applications-Link und Installationsanleitung. Die laufende
Entwicklungs-App wird dabei nicht ersetzt. Die Datei landet unter
`outputs/releases/<Version>/`, inklusive SHA-256 und Source-Revision.
Ein vorhandenes Release-Paket wird nicht überschrieben.

Ohne Notarisierungsprofil heißt die Datei ausdrücklich `-unnotarized.dmg`.
Das ist keine Bestätigung durch Apple; beim ersten Start kann die einzelne App
unter Datenschutz & Sicherheit > Dennoch öffnen freigegeben werden, wenn der
Empfänger dem Absender vertraut. Es werden keine globalen Sicherheitsoptionen
abgeschaltet. Details: [Apple – Apps sicher öffnen](https://support.apple.com/de-de/102445).

Mit eingerichtetem Keychain-Profil:

```sh
./script/release.sh --notarize FocusFrame-notary
```

Dieser Aufruf übermittelt App und DMG an Apples Notarisierungsdienst. Nur nach
Status Accepted werden Tickets angeheftet und geprüft. Das Profil wird lokal
interaktiv mit `xcrun notarytool store-credentials FocusFrame-notary` eingerichtet;
Zugangsdaten gehören nicht in den Chat, ins Repository oder in Skripte. Die
Signatur kann über FOCUSFRAME_SIGN_IDENTITY explizit gewählt werden.

Eine lokale Release-Datei ist kein öffentliches GitHub-Release; derzeit hat das
Repository keinen Remote. Veröffentlichungen erfolgen separat auf Wunsch.
