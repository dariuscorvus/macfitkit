# Automatische Fensterrundung: Machbarkeit

Stand: 2. Oktober 2026. Separates Entwicklungsexperiment; noch kein App-Modus.

## Methode

ScreenCaptureKit liefert eine Einzelaufnahme eines bestimmten Fensters,
transparent, ohne Cursor und ohne Fensterschatten. Der Alphakanal wird an allen
vier Ecken ausgewertet. Übergänge ab 50 % Alpha werden über mehrere Bildzeilen
ermittelt, mit dem Pixelskalierungsfaktor in Punkte umgerechnet und an einen
Kreisbogen angepasst. Der Bericht enthält Näherungsradius und RMS-Abweichung.
Ein guter Kreisbogen-Fit beweist keine exakt kreisförmige Systemkontur.

Keine privaten APIs, keine Prozessinjektion und kein Ändern fremder Fenster.
Fensterbilder bleiben nur kurz im Arbeitsspeicher; weder Bilder noch Titel werden
persistiert oder übertragen. Der Bericht enthält nur die explizit ausgewählten
App-IDs, Bildgröße, Maßstab, Dauer und numerische Eckmessungen.

## Lokales Ergebnis

Probe auf dem hiesigen System und einem Display mit 2×-Skalierung:

| Fenster | Vier Eckschätzungen | RMS pro Ecke | Aufnahme und Auswertung |
| --- | --- | --- | --- |
| Finder | jeweils ca. 17 pt | ca. 0,66 pt | 130,1 ms |
| Systemeinstellungen | jeweils ca. 17 pt | ca. 0,66 pt | 57,2 ms |
| FocusFrame | jeweils ca. 17 pt | ca. 0,66 pt | 51,4 ms |
| Chrome | nicht geprüft: kein verfügbares sichtbares Chrome-Fenster | – | – |

Das bestätigt die Messbarkeit dieser Konturen aus Transparenz. Es bestätigt
keinen allgemeinen Radius für eine App und keine Zuverlässigkeit auf anderen
macOS-Versionen. Die Nutzerbeobachtung ähnlicher Radien hier passt zum Ergebnis.
Der Wert 17 pt ist eine Bildmessung mit Modellabweichung, kein ausgelesener Wert.

## Ablauf und Grenzen

`./script/probe_window_corners.sh` oder mit expliziten Bundle-IDs starten.
Das Skript kompiliert/signiert einen kleinen lokalen Probeprozess im Cache.
Ohne bereits vorhandene Aufnahmeberechtigung endet es vor der ersten Aufnahme.
Es fordert oder erteilt keine neue Berechtigung. Die Produktions-App verwendet
weiter ausschließlich den vorhandenen manuellen Radius und benötigt für diese
neue Oberfläche keine Bildschirmaufnahme-Berechtigung.

Eine spätere automatische Funktion sollte Ergebnisse nach Fensteridentität und
relevanter Größe/Skalierung cachen, veraltete asynchrone Antworten verwerfen und
beim Ziehen ausschließlich die vorhandene Kontur verschieben. Eine Aufnahme
bei jedem Fokuswechsel würde eine hier messbare Verzögerung verursachen; bekannte
Fenster sollen sofort den Cache verwenden. Fremde oder nicht erfassbare Fenster
müssen sofort mit einem verlässlichen Rückfallradius erscheinen.

Vor Integration zu prüfen: Chrome und weitere Fenstertypen, macOS 14–26,
Intel, 1×/2× und gemischte Displays, teilweise transparente Inhalte, quadratische
Ecken, unterschiedliche Ecken, kontinuierliche statt kreisförmige Kurven,
Skalierung/Resize, Vollbild, Capture-Ausschlüsse und Berechtigungsverlust.
Ein schlechter Fit muss als unklar gelten, nicht als verbindlicher Radius.

## Technische Quellen

- [Einzelaufnahme](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)
- [Schatten ausschließen](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/ignoreshadowssinglewindow)
- [Transparenz erhalten](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/shouldbeopaque)
- [Fensterformen nach Stil](https://developer.apple.com/videos/play/wwdc2025/310/)
