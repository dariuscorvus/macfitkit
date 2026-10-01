# Änderungen

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
