# FocusFrame

Kleine native macOS-Menüleisten-App: markiert das fokussierte Fenster mit einem
klicktransparenten Rahmen. Swift 6 / AppKit, keine externen Paketabhängigkeiten.
Aktueller lokaler Entwicklungsstand: 0.7.1. Letzter Release: 0.6.0 als signierte
Universal-DMG, noch nicht notarisiert.

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
Danach zu FocusFrame zurückwechseln; die Berechtigung wird erneut geprüft. Bei Problemen
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

- Native Seitenleiste mit **Darstellung**, **Leuchten**, **Schatten**,
  **Farbverlauf**, **Animationen**, **Verhalten** und **App-Ausnahmen**.
- **Darstellung:** freie Rahmenfarbe, Deckkraft 10–100 %, Stärke 1–12 pt,
  Eckenradius 0–40 pt und Abstand 0–20 pt. Die Darstellung kann separat
  zurückgesetzt werden.
- **Leuchten:** Glow/Neon mit Intensität, Leuchtweite, eigener oder übernommener
  Rahmenfarbe und Neon-Kern. **Schatten:** Farbe, Deckkraft, Weichheit, Ausbreitung
  und X-/Y-Versatz. **Farbverlauf:** linearer oder umlaufender Zweifarbenverlauf.
- **Animationen:** Pulsieren oder Blinken mit Zyklusdauer und Deckkraftgrenzen;
  unabhängige Verlaufsrotation mit Richtung und Umlaufdauer. Für beide separat
  „nur beim Fokuswechsel“ oder „dauerhaft“, mit einstellbarer Fokusdauer.
- Der echte Rahmen um das aktive Einstellungsfenster ersetzt die separate
  Vorschau. „Fokuswechsel testen“ spielt die Fokusanimationen dort ab.
  Verschieben und Resize folgen lokalen AppKit-Ereignissen ohne AX-Abfragen.
  Farbpalette und Einstellungs-Sheets behalten das Einstellungsfenster als Ziel;
  beim Wechsel zu einer fremden App folgt der Rahmen wieder deren Fenster.
- Zusätzliche Regler erscheinen nur für eingeschaltete Effekte und den gewählten
  Modus. Ausblenden bewahrt die gespeicherten Werte; lange Bereiche sind scrollbar.
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
  Ausblenden im Vollbild. **App-Ausnahmen** hat eine eigene Seite.
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

Das Menüleistenmenü enthält Rahmen an/aus, Einstellungen, Diagnose und Beenden.
Bei fehlendem AX-Zugriff kommt „Bedienungshilfen erlauben …“ hinzu.
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

## Automatische Rundung – Machbarkeitstest

Die automatische Fensterrundung ist noch kein App-Modus.
`./script/probe_window_corners.sh` führt einen separaten lokalen Versuch mit
ScreenCaptureKit aus: eine transparente Aufnahme pro sichtbarem Fenster von
Finder, Chrome, Systemeinstellungen und FocusFrame; nur Eck-Alpha wird analysiert.
Bilder werden nicht gespeichert. Keine kontinuierliche Aufnahme, keine
Änderung der Konfiguration und keine automatische Berechtigungsanforderung.
Bestehende Bildschirmaufnahme-Berechtigung ist Voraussetzung. Details und
Ergebnisse stehen in docs/CORNER-DETECTION.md.

### Direkte Zahlenwerte

Jeder Zahlenregler hat ein editierbares Feld mit separater Einheit. Enter oder
Verlassen des Feldes übernimmt und speichert die Eingabe. Dezimalkomma und
Dezimalpunkt werden akzeptiert; ungültiger Text wird auf den gespeicherten Wert
zurückgesetzt, Werte außerhalb des Bereichs werden begrenzt.

Stärke: 1–100 pt; Eckenradius: 0–300 pt; Abstand: 0–200 pt. Leuchtweite,
Schattenweichheit und Ausbreitung: 0–200 pt; Schattenversatz: −200 bis +200 pt.
Prozentwerte, Winkel und Animationsdauern behalten ihre bisherigen Grenzen.

Standard-Eckenradius: 18,5 pt bei neuen Einstellungen und beim Zurücksetzen.
Bereits gespeicherte Radiuswerte bleiben erhalten.

### Rahmenposition und Metalloberflächen (0.7.0 lokal)

Unter **Darstellung** wählst du Außen, Mittig oder Innen. Bei Abstand 0 liegt der
Rahmen vollständig außerhalb, zur Hälfte auf der Fensterkante oder vollständig
innerhalb. Ein positiver Abstand verschiebt Innenrahmen nach innen und die beiden
anderen Positionen nach außen. Die Rundungen folgen den inneren und äußeren
Konturen. Bei sehr kleinen Fenstern werden Innenabstand und -stärke für die
Darstellung begrenzt; gespeicherte Wunschwerte bleiben bestehen.

Unter **Oberfläche** stehen Farbe / Farbverlauf, Gold und Chrom zur Verfügung.
Metalloberflächen haben einen einstellbaren Glanz (0–100 %) und Lichtwinkel
(0–360°). Rahmenfarbe und Farbverläufe bleiben beim Wechsel gespeichert; die
Verlaufsrotation läuft nur bei der Oberfläche Farbe / Farbverlauf. Glow/Neon,
Schatten und Deckkraftanimationen lassen sich weiter kombinieren.

Unter **Animationen → Metall-Lichtreflex** gibt es einen optionalen wandernden
Reflex: Stärke 0–100 %, Breite 5–60 %, nur beim Fokuswechsel (0,5–5 s) oder
dauerhaft (Zyklus 2–30 s). Die Fokusvariante führt einen Durchlauf mit weichem
Ein-/Ausblenden aus. Pausieren, Ausblenden und Bewegung reduzieren stoppen ihn.
Jeder Zahlenwert hat einen Regler und eine direkte Eingabe; Oberfläche und
Lichtreflex besitzen eigene Zurücksetzen-Schaltflächen. Neue Effekte sind aus.

### Finder-Desktop (0.7.1 lokal)

Der Finder-Desktop erhält keinen FocusFrame-Rahmen. Normale Finder-Fenster,
auch maximierte Fenster, werden weiterhin verfolgt. Die Erkennung verwendet
AX-Rolle sowie übereinstimmende öffentliche WindowServer-Geometrie/-Ebenen,
keine lokalisierten Fenstertitel oder privaten Fenster-ID-APIs.
Die Ausnahme betrifft ausschließlich Finder; sie schließt nicht die gesamte App aus.

## Version 0.8.0

Unter Darstellung stehen „Dezent“ und „Hoher Kontrast“ sowie eigene benannte
Profile bereit. „Darstellung als Profil speichern“ speichert die aktuellen Werte;
ein vorhandener Name wird aktualisiert. Datei-Export und -Import übertragen
Darstellung, Ausnahmen, Tastenkürzel und Profile zwischen Macs. Autostart und
Bedienungshilfen-Berechtigung bleiben lokale macOS-Einstellungen.

Unter Verhalten kann das Tastenkürzel aus Buchstaben/Ziffern und Control, Option,
Command und Shift gewählt werden. Mindestens ein Modifier ist erforderlich.
Bestehende Konfigurationen behalten Control–Option–F. Konflikte bei Registrierung
werden angezeigt; macOS-/App-Kürzel können trotzdem Vorrang haben.
Eine Stromsparoption setzt Deckkraftanimation, Verlaufsrotation und bewegten
Metallreflex aus; der statische Rahmen und die gespeicherten Effekte bleiben.
Menüleiste: Version und private GitHub-Download-Seite. Beide Schwester-Apps
besitzen eigene Icons im gemeinsamen Erscheinungsbild.

Die Finder-Desktop-Klassifikation wird pro fokussiertem AX-Fenster gespeichert
und bei Fokus-/Appwechsel verworfen. AX-Messaging ist auf 50 ms pro Anfrage
begrenzt. Geometrieantworten über 150 ms oder für eine inzwischen andere
Vordergrund-App werden verworfen. Die optionale lokale Diagnose protokolliert
Abfragedauer und verworfene Antworten, ohne Titel oder Inhalte zu sammeln.
AX-Abfragen bleiben synchron; mehrere Anfragen können sich addieren. Eine
vollständige Auslagerung benötigt separate Lebenszyklus-/Fokus-Tests.

### Prüfung und Grenzen

33 Core-Tests, Einstellungsfenster mit sieben Bereichen, numerische Eingaben,
Speicherung, 9 Renderer-Pixelprüfungen und 792 reale AppKit-Geometrieprüfungen
liefen erfolgreich auf macOS 27.2 / Apple Silicon. Struktur der Xcode-Projekte
ist geprüft; mangels vollständigem Xcode erfolgte der Bau über SwiftPM.
Langsame Fremd-AX-Apps, frischer Account, Ab-/Anmelden, Intel, Mindestversion
macOS 14 und mehrere Displays benötigen weiterhin praktische Hardwaretests.
Desktop ohne Rahmen / normale Finder-Fenster mit Rahmen wurde vom Benutzer
bereits bestätigt; die Regel bleibt erhalten.

## Schatten und Animationen (0.9.0)

Unter **Schatten → Farbe verwenden von** gibt es Eigene Farbe, Rahmenfarbe und
Rahmenverlauf. Verlauf übernimmt die aktuell sichtbare Oberfläche inklusive
Gold/Chrom; ohne Verlauf wird die Rahmenfarbe verwendet. Eigene Schattenfarben
bleiben gespeichert. Deckkraft, Weichheit, Ausbreitung und Versatz sind unabhängig.
Der Verlaufsschatten nutzt einen einmal pro Geometrie erzeugten weichen Alpha-Masken-
Bitmap und eine lebende Farbverlaufsebene. Rotation und Farbfluss teilen mit dem
Rahmen denselben Startzeitpunkt. Maskenauflösung ist auf einen Pixel pro Punkt
begrenzt; weiche Schatten benötigen keine Retina-Auflösung. Bei Geometrieänderung
werden die Masken neu erzeugt; breite Schatten können dadurch zusätzlichen Aufwand
beim Vergrößern verursachen. Es wird keine pauschale Verbrauchsverbesserung behauptet.

Unter **Animationen** stehen eine eigene verkleinerte Vorschau und die Presets
Dezent, Lichtläufer, Atmender Schatten und Farbfluss bereit. Presets verändern
Animationseinstellungen; Schatten-/Verlaufs-Presets aktivieren benötigte Effekte.
Die Vorschau nutzt denselben Renderer wie das Overlay. „Animation abspielen“
startet einen Fokusdurchlauf, ohne ein anderes Fenster aktivieren zu müssen.
Beim Seitenwechsel oder Schließen werden Vorschauanimationen gestoppt.

Neue Bewegungseffekte:
- Fokusimpuls: ein kurzer heller Akzent auf der Kontur, optional federnd.
- Lichtläufer: ein kurzer heller Abschnitt läuft um die Kontur.
- Rahmen zeichnen: die echte Rahmenkontur wird schrittweise sichtbar.
- Atmen: Schatten, Rahmen, Leuchten oder alles werden sanft moduliert.
  Verlaufsschatten überblenden dabei zwischen breiter und kompakter Maske;
  einfarbige Schatten verändern zusätzlich ihre Weichheit.
- Farbfluss: die Verlaufstöne gehen ineinander über, auch im Verlaufsschatten.

Dauer je Durchlauf, ein bis sechs Fokus-Durchläufe, Stärke und Bewegungsverlauf
sind einstellbar. Dauerhaft läuft bis zum Ausblenden/Pausieren. Federnd gilt für
Fokusimpuls; andere Bewegungen verwenden bei dieser Auswahl einen sanften Verlauf.
Optional übernehmen Deckkraft, Rotation und Metallreflex Dauer und Auslöser aus
der gemeinsamen Steuerung. Die bisherigen Einzelwerte bleiben gespeichert.
Die Deckkraftanimation lässt sich getrennt auf Rahmen, Leuchten, Schatten oder
alles anwenden. Stromsparmodus und „Bewegung reduzieren“ stoppen auch neue Effekte.

Bestehende Konfigurationen behalten eigene Schattenfarbe, Deckkraft auf alles
und ausgeschaltete neue Bewegungseffekte. Import/Export und Darstellungsprofile
enthalten alle neuen Optionen. Verschieben verwendet bestehende Ebenen;
Vergrößern erhält den Startzeitpunkt einer laufenden Animation.

### Validierung

34 Core-Tests einschließlich Migration, Presets, Speicherung und Stromsparmodus;
9 bestehende Renderer-Pixelprüfungen; zusätzliche Verlaufsschatten-Pixelprüfung
für räumliche Farben und transparente Mitte, native Schattenfarbe,
synchronisierte Rotation/Farbfluss, fünf Bewegungsmodi, Wiederholungen, Phasenerhalt
beim Vergrößern, getrennte Schattenanimation und Cleanup; 792 AppKit-Geometrieprüfungen.
Einstellungsfenster: sieben Bereiche, bisherige Darstellung und Live-Verfolgung,
Lichtläufer-Preset, tatsächliche Vorschauwiedergabe und Stop beim Seitenwechsel.
Prüfsystem macOS 27.2 / Apple Silicon. Intel und Mindestversion macOS 14 sind
Universal-Bauziele, aber noch nicht auf echter Hardware getestet.
