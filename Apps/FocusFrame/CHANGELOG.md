# Unveröffentlicht

- Bildschirmgroße transparente Dock-/Systemfenster blenden die Effekte nicht mehr vollständig aus. Höhere Fensterebenen und native Kontextmenüs verdecken sie durch die systemeigene Komposition; niedrigere und gleiche Ebenen bleiben zusätzlich maskiert. Auf dem Mac mini einschließlich herausragender nativer und eigener Kontextmenüs geprüft.

- Rahmen, Leuchten und Schatten werden gemeinsam an davorliegenden Fenstern ausgeschnitten. Überlappende Abdeckungen erzeugen keine sichtbaren Inseln.
- Eindeutige Zielzuordnung über Prozess, Geometrie und anschließend stabile öffentliche Fenster-ID; bei unklarer Zuordnung werden Effekte ausgeblendet.
- Verdeckung wird auch bei nicht aktivierenden Panels begrenzt aktualisiert, ohne Effektanimationen neu aufzubauen. Keine neue Bildschirmaufnahme-Freigabe oder Änderung bestehender Profile.
- Rechteckige Bounds werden konservativ maskiert; Reaktionszeit und offene Abnahme siehe [Verdeckungsprüfung](../../docs/focusframe-occlusion-plan.md).

# 0.9.0 – 2026-10-11

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


# 0.8.0 – 2026-10-11



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


# Änderungen

## 0.7.0 – 2. Oktober 2026 (lokale Entwicklung)

- Rahmenposition Außen / Mittig / Innen, konzentrische Konturen und sichere
  Darstellung sehr breiter Innenrahmen auf kleinen Fenstern.
- Gold und Chrom mit einstellbarem Glanz und Lichtwinkel; bestehende Farben
  und Verläufe bleiben gespeichert.
- Optionaler Metall-Lichtreflex mit Stärke, Breite, Fokus-/Dauerbetrieb und
  konfigurierbarer Dauer. Core Animation, kein Zeichentimer.
- Ganzzahlige Overlay-Fenstergeometrie mit separater Korrektur für Subpixel-
  Positionen. Fensterbewegung erhält dieselben Kontur-Layer und laufende Reflexe.
- Kein neuer Release in dieser Etappe; Feuer noch nicht implementiert.

## 0.6.0 – 2. Oktober 2026

- Direkte Zahleneingaben neben allen Reglern; Dezimalwerte, Validierung und
  Speicherung bei Enter/Fokusverlust. Größere Grenzen für Stärke, Radius,
  Abstand, Leuchten und Schatten.

- Native Einstellungs-Seitenleiste mit sieben Bereichen, gruppierten Optionen
  und kontextabhängigen Effekt-/Animationsreglern. Menüleistenmenü vereinfacht.
- Separate Vorschau entfernt: Änderungen und Fokus-Test erscheinen direkt am
  echten Rahmen des aktiven Einstellungsfensters. Lokale AppKit-Ereignisse
  verfolgen Fokus, Move, Resize und Minimieren ohne AX-Abfragen.
- Separater Machbarkeitstest für automatische Rundung aus transparenten
  ScreenCaptureKit-Einzelaufnahmen; noch kein automatischer Radius-Modus.
- Standardradius 18,5 pt für neue Einstellungen und Zurücksetzen; gespeicherte
  Radiuswerte bleiben erhalten. Signierte Universal-DMG für Intel/Apple Silicon,
  weiterhin ohne Apple-Notarisierung.

## 0.5.3 – 2. Oktober 2026

- Rahmen bleibt beim Fokuswechsel und Positionswechsel nahe der Menüleiste
  an der Fensterkontur: das transparente Overlay darf mit seinen Effekträndern
  über Bildschirmgrenzen reichen, ohne von AppKit nach unten verschoben zu werden.
- Desktop-Regressionstest gegen echtes AppKit-Overlay für gleiche Fenstergrößen,
  Größenänderungen und maximale Glow-/Neon-/Schattenränder.

## 0.5.2 – 2. Oktober 2026

- Release-Verpackung: Universal-DMG, Developer-ID-Signatur, Hardened Runtime,
  Installationsanleitung, Prüfsumme und optionaler Notarisierungsablauf.

- Klassisches Xcode-App-Projekt mit geteilten App-/Fixture-Schemes,
  statischer Kernbibliothek und Swift-Testing-Target; gemeinsame Quellen mit SwiftPM.
- Gemeinsame Versionsdatei, optionaler Xcode-Build/Start im vorhandenen Skript.
- Prüfung von Xcode-Projektstruktur, Quellenzuordnung und Schemes im lokalen Check.

## 0.5.1 – 2. Oktober 2026

- Fokus-Pulsieren und -Blinken blenden weich zur statischen Deckkraft zurück,
  statt mitten im Zyklus abzubrechen. Individuelle Maximaldeckkraft und erneute
  Auslösung werden berücksichtigt; Daueranimation bleibt unverändert.
- Regressionstests für abgebrochene Zyklen, niedrigere Maximaldeckkraft und
  erneute Auslösung ab der angezeigten Deckkraft.

## 0.5.0 – 1. Oktober 2026

- Etappe 0.4: kombinierbare Glow-/Neon-, Schatten- und Zweifarbverlauf-Effekte
  mit normalisierter, abwärtskompatibler Speicherung und separatem Zurücksetzen.
- Etappe 0.5: Pulsieren, Blinken und unabhängige Verlaufsrotation mit Fokus- oder
  Dauerauslöser; dynamische Unterstützung für „Bewegung reduzieren“.
- Gemeinsamer Core-Animation-Renderer für Vorschau und Overlay; zusätzlicher
  Platz für äußere Effekte, weiterhin reine Positionsänderung beim Ziehen.
- Vier native Einstellungsbereiche, scrollbar, gemeinsame skalierbare Vorschau
  und Testknopf für Fokusanimationen.
- Sechs zusätzliche Prüfungen für Migration, Persistenz, Grenzen und Animationen.

## 0.3.2 – 1. Oktober 2026

- „Rahmen aktiv“ direkt in den Verhaltenseinstellungen; synchron mit
  Menüleistenschalter und Tastenkürzel.

## 0.3.1 – 1. Oktober 2026

- Start aus dauerhaftem Benutzer-App-Ordner statt Cache; Anmeldestart verwendet
  wie iQualize `SMAppService.mainApp` für die installierte App.
- Anmeldestatus wird nach Rückkehr aus Systemeinstellungen neu geprüft;
  ausstehende Freigabe erscheint als Zwischenzustand.
- Tastenkürzel zeigt Registrierung, empfangene Tastendrücke und Rahmenzustand
  direkt in den Einstellungen.
- Nutzer bestätigt deutlich verbesserte Ziehbewegung und funktionierendes Vollbild.

## 0.3.0 – 1. Oktober 2026

- Native Einstellungen mit gemeinsamer Rahmenvorschau: freie Farbe, Deckkraft,
  Stärke, Eckenradius und Abstand; lokale Speicherung und Übernahme alter Werte.
- Optionaler nativer Start bei Anmeldung, globales ⌃⌥F, App-Ausnahmen und Vollbildregel.
- Optionale Diagnose mit begrenzter Erfassung im Arbeitsspeicher.
- Test-App für definierte Fensteränderungen und gemeinsamer Prüfaufruf.
- Getestete Sichtbarkeitsregeln, Konfigurationsgrenzen und unterbrochene Ziehgesten.

## 0.1.0 – 1. Oktober 2026

- Swift/AppKit-Repository, AccessibilityService → FocusManager → OverlayWindow.
- AX-/Workspace-Ereignisse, klicktransparentes Overlay und Mehrschirm-Koordinaten.
- Rahmenrundung und Mausverfolgung bei bestätigten Fenster-Ziehgesten.
- Lokaler Build-/Startworkflow, Signaturprüfung und Geometrie-/Ziehgestentests.

## Unveröffentlicht – separates Dock-Experiment

- Endlicher Dock-Halo-Prototyp mit App-Bundle-URL-Zuordnung und gemeinsamem
  Renderer, ohne Änderung der produktiven Fensterverfolgung oder Einstellungen.
- Dock-AX-Geometrieereignisse lokal nicht unterstützt; Grenzen bei Vergrößerung,
  Auto-Hide, seitlichem Dock und Displaywechsel in docs/DOCK-HALO.md dokumentiert.
  Keine neue Versionsnummer und kein Release.
