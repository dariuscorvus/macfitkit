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

## Effekte prüfen

In Effekte Neon + Schatten + Verlauf kombinieren, danach in Animation Pulsieren
und Rotation aktivieren. Jeweils Fokus-/Dauerbetrieb prüfen. Schatten/Glow mit
maximaler Weite und positiven/negativen Versätzen: weder Abschneiden noch
Verschieben der Fensterkontur. Reine Bewegung darf keine Effektpfade neu bauen.
Diagnose „Fokussiertes Fenster gewechselt“ genau einmal pro tatsächlichem Wechsel;
Move/Resize im selben Fenster darf kein neues Fokusereignis erzeugen.
Vorschau bei Tab Verhalten und bei geschlossenem Fenster ohne Animationen;
verstecktes Overlay ebenfalls. „Bewegung reduzieren“ in macOS statisch prüfen.
Nach Tests nur neue Effekte zurücksetzen; Nutzerwerte für Verhalten beibehalten.

## Xcode-Projekt

Xcode 16+ öffnen: `FocusFrame.xcodeproj`. Scheme FocusFrame: Run/Tests/Profile;
Scheme FocusFrameFixture: Testfenster. Projekt hat keine externen Abhängigkeiten
und teilt Quellen mit SwiftPM. Neue Dateien müssen in beiden Build-Systemen ihrem
Target zugeordnet sein; `script/check_xcode_project.py` erkennt fehlende Zuordnung.
Version/Build zentral in `Config/Version.xcconfig` ändern.

Auf Hosts mit vollständigem Xcode zusätzlich prüfen:

```sh
xcodebuild -project FocusFrame.xcodeproj -scheme FocusFrame -configuration Debug -destination 'platform=macOS' build
xcodebuild -project FocusFrame.xcodeproj -scheme FocusFrame -destination 'platform=macOS' test
./script/build_and_run.sh --xcode
```

Auf dem derzeitigen Host fehlt vollständiges Xcode. Strukturelle Projektprüfung
und bestehender SwiftPM-Check sind hier die verfügbaren Nachweise; Xcode-spezifische
Build-/Signing-/Testausführung ist deshalb noch nicht bestätigt.

## Overlay-Koordinaten an Bildschirmrändern

`./script/test_overlay_geometry.sh` prüft in einer Desktop-Sitzung das tatsächliche
Overlay samt Renderer. Gleiche Fenstergrößen bei Fokuswechsel, Resize und maximale
Effektränder müssen ihre angefragte Position beibehalten, auch oberhalb/links eines
Displays. Das Overlay darf von AppKit nicht an der Menüleiste begrenzt werden.
Der Test ist zusätzlich zum Kerncheck auszuführen, wenn die Overlay-Geometrie
oder dessen AppKit-Fensterverhalten geändert wird.
