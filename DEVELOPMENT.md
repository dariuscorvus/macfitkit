# Entwicklungsablauf

## Vor und nach Änderungen

1. `git status --short` prüfen und fremde Änderungen erhalten.
2. Konkretes Verhalten und Abnahmekriterium festlegen; kleine Änderungen und Commits.
3. `./script/check.sh` ausführen. Tests, Build und Signatur müssen bestehen.
4. Betroffene GUI-/Fensterfunktion zusätzlich prüfen; Prozessstart ist keine UI-Abnahme.
5. Prüfergebnis und verbleibende Grenzen in VALIDATION.md, sichtbare Änderungen in CHANGELOG.md festhalten.

Keine neuen Laufzeitframeworks für kleine Funktionen. macOS-Ereignisse statt
wiederkehrender Timer. AX-Zugriffe gehören in den AccessibilityService; keine
synchronen Fensterabfragen auf dem aktiven Maus-Bewegungspfad. AppKit-/AX-Zustand
bleibt auf dem MainActor/Haupt-RunLoop.

## Reproduzierbare Fensterprüfung

```sh
./script/build_and_run.sh --diagnostics
./script/fixture.sh
```

Die Diagnose nur für die Prüfung einschalten. Zwei Fenster A/B haben definierte
Ausgangspositionen auf dem Hauptdisplay. Die Positions-/Größenanzeige verwendet
AppKit-Punkte. Die Menüaktion „Testfenster zurücksetzen“ erzeugt sie erneut.

| Aktion | Erwartung |
| --- | --- |
| Verschieben | Ursprung +90 / +40 pt; Rahmen folgt der neuen Geometrie |
| Größe ändern | Breite +50, Höhe +20 pt; keine alte Ziehvorhersage bleibt aktiv |
| Anderes Fenster fokussieren | Rahmen wechselt auf das andere Fenster |
| Minimieren / Schließen | Kein Rahmen bleibt auf einem nicht verfügbaren Fenster |
| Titelleiste manuell ziehen | Nach bestätigtem Bewegungsbeginn folgt der Rahmen dem Mausweg |
| Ziehen abbrechen / App oder Display wechseln | Keine verspätete Meldung reaktiviert die alte Ziehgeste |
| Test-App ausschließen | Kein Rahmen für diese App; Diagnose meldet den Ausschluss |
| Vollbild + Ausblendregel | Rahmen bleibt im Vollbild aus; nach Rückkehr korrekt wieder sichtbar |

Automatisierte AX-Button-Aktionen testen die programmatischen Änderungen. Sie
bilden echte Maus-/Hotkey-Eingabe nicht zwingend ab. Mausflüssigkeit, globales
Tastenkürzel, Anmeldung und reale Display-/Space-Wechsel separat manuell prüfen.
Abfragezeiten aus der Diagnose nicht als Bildschirm-Latenz ausgeben.

## Einstellungen prüfen

Farbe, Deckkraft, Stärke, Radius und Abstand ändern. Vorschau und tatsächlichen
Rahmen vergleichen. App neu starten und dieselben Werte erwarten. Ausnahmen
hinzufügen/entfernen. Autostart ein-/ausschalten und den OS-Status prüfen; eine
Registrierung ist noch kein tatsächlich getesteter Login. Tests hinterlassen
keine ausgeschlossene Test-App, eingeschaltete Diagnose oder temporär aktivierte
Alltagsoptionen.

## Plattformgrenzen und spätere CI

Der Build verwendet die lokal aktive Swift-Toolchain. Swift 6.4 CLT benötigt
hier den expliziten Testing-Makro-Pfad; Dokumentensynchronisation darf App-/Test-
Bundle-Signaturen nicht verändern. Änderungen an diesem Workflow gezielt prüfen.
Ein künftiger macOS-CI-Lauf kann denselben Prüfaufruf nutzen, ersetzt jedoch
keine Desktop-Sitzung mit erlaubten Bedienungshilfen. Ein Remote und eine CI
werden erst bei entsprechender Projektentscheidung eingerichtet.
