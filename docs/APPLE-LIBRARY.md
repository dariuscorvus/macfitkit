# Apple-Hintergrundauswahl — 0.2.0

Geprüft am 11. Oktober 2026 auf macOS 27.2, Apple Silicon, Swift 6.4.
Ausführung auf dem Mindestziel macOS 26 ist noch offen.

## Tatsächlich lokale Apple-Videos

Die Videos liegen hier im Benutzerordner
`~/Library/Application Support/com.apple.wallpaper/aerials/videos`.
Der ältere systemweite idleassetsd-Ordner ist auf diesem Mac nicht vorhanden.

| Lokaler Dateiname | Apples deutscher Name |
| --- | --- |
| F88CDF4A-9681-4D1F-88FE-34F1A3C6A62B.mov | Mammutbaum am Morgen |
| 6D6834A4-2F0F-479A-B053-7D4DC5CB8EB7.mov | Mammutbaum bei Sonnenaufgang |

Beide werden als Landschaft mit vorhandenen lokalen PNG-Vorschauen angezeigt.
Beim abschließenden Neustart war zusätzlich Mammutbaum bei Nacht lokal vorhanden:
Das echte Menü zeigte drei Apple-Videos und stellte die inzwischen gespeicherte
Nacht-Auswahl wieder her. Die App erkennt neu hinzugekommene Videos ohne Namensliste.
Namen stammen aus Apples lokalem Manifest und Übersetzungstabellen; die Namen
wurden zusätzlich mit den macOS-Hintergrundbild-Einstellungen verglichen.
Apple-Dateien und Systemeinstellungen wurden dabei nicht verändert.

## Sichtbar geprüft

- Das echte Menüleisten-Popover öffnet und zeigt beide Hintergründe.
- Suche nach Morgen bzw. Sonnenaufgang filtert auf die passende Zeile.
- Auswahl wechselt zwischen den beiden Videos und markiert die aktive Zeile.
- Das Desktop-Fenster zeigt einen echten Wald-Frame des Apple-Videos.
- Pause/Fortsetzen aktualisiert den Zustand und die Beschriftung.
- Auswahl aller Displays bzw. des vorhandenen LG ULTRAGEAR funktioniert im UI.
- macOS-Hintergrund zeigen entfernt die ausgewählte Videofläche.
- Neu suchen erhält die Auswahl; Neustart stellt Mammutbaum am Morgen wieder her.
- Apple-Hintergründe verwalten öffnet die passende macOS-Einstellungsseite.

Der vorherige Test mit dem bunten Testvideo wurde vom Nutzer bestätigt:
Video hinter Finder-Icons sichtbar, Icons weiterhin bedienbar. Siehe
[ICON-TEST.md](ICON-TEST.md). Das ist eine Beobachtung auf diesem System,
keine garantierte Apple-API oder Zusicherung für andere Desktop-Konfigurationen.

## Automatische Prüfungen und Grenzen

`scripts/check-core.sh` besteht mit lokaler Dateisuche, Deduplizierung,
Symlink-Ausschluss, deutschen Namen, Sprach-Fallback, nicht heruntergeladenen
Assets, defekten Metadaten, expliziten Videos und allen 16 Pause-Kombinationen.
App-Build und strenge Ad-hoc-Signaturprüfung einschließlich entpackter ZIP
erfolgreich. Die CLT-Testeinschränkung steht in [VALIDATION.md](VALIDATION.md).

Es werden ausschließlich lokal vorhandene Videos und Vorschaubilder gelesen.
Weitere Galerie-Einträge werden erst nach einem Download durch macOS angeboten.
Private Apple-Dateipfade und Metadatenformate können sich ändern; Dateinamen
bleiben als Fallback auswählbar. Keine Netzwerkdownloads durch LiveDesktop.

Mehrere gleichzeitig angeschlossene Displays, Hotplug, Spaces, Mission Control,
Stage Manager und Energieverbrauch sind noch nicht praktisch abgenommen.
Die Display-Auswahl ist auf einem vorhandenen Display geprüft.
