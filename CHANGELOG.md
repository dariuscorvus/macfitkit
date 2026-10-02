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
