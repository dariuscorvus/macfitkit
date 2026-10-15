# Monorepo-Validierung

Stand: 15.10.2026. Die Umsetzung liegt in den aufeinander aufbauenden PRs #2–#7. Der Benutzer hat nach den unten bestätigten Funktionstests ausdrücklich beauftragt, die offenen Prüfungen zu dokumentieren und die fertigen PRs nach `main` zu übernehmen. Offene Abnahmen werden dadurch nicht als bestanden gewertet. Keine Veröffentlichung oder Ersetzung installierter App-Dateien.

## Builds und Herkunft

- FocusFrame `15e3b58e548fad876c34a4ec5d7503691b13479a` und LiveDesktop `21e90a2769f906c03b15e916b6e55e5adf753e03` wurden vor dem Import gegen GitHub geprüft und ohne Squash per Subtree übernommen. Beide Revisionen bleiben Vorfahren der Migration.
- FocusFrames Xcode-Projekt bleibt erhalten. Der Workspace enthält vier unabhängige App-Schemes; LiveDesktop und das optionale MacFitKit-Menü haben eigene native Projekte erhalten.
- Alle vier Apps wurden in Debug und Universal-Release gebaut. Acht Bundles wurden auf Identität, Mindestversion, LSUIElement, Original-Icons, Signatur (`codesign --verify --deep --strict`) und Architekturen (`lipo`) geprüft. Nach der letzten Änderung an MacFitKits Startpfad wurden dessen Debug-/Release-Builds erneut geprüft.
- FocusFrame/DockPreview behalten macOS 14, LiveDesktop macOS 26. Bestehende App-Kennungen und Versionsdateien bleiben erhalten. Original-Repositories wurden nicht geändert oder archiviert.
- FocusFrames PreferencesStore und LiveDesktopCore/Settings.swift bleiben gegenüber den importierten Quellen unverändert. UI-Adapter schreiben in die vorhandenen Stores.

## Bestandene automatische Prüfungen

| Prüfung | Nachweis |
|---|---|
| `script/check.sh` | Shared-, Projektstruktur-, App-Core- und native Prozess-Bridge-Prüfungen |
| Shared Swift Testing | Vier Tests: Lease/Timeout, Version/ungültige Nutzlasten, Identitäten, numerische Komma-/Punkt-Eingabe |
| FocusFrame-Core | 34 Tests in sechs Suites, inklusive Persistenz, Konfiguration, Effekten und Bewegung |
| FocusFrame-Projektstruktur | Quellenzuordnung, Core-/Shared-Abhängigkeiten und geteilte Schemes |
| LiveDesktop-Core | Katalog, Apple-Metadaten, Favoriten/Wechsellisten-Persistenz und alle 16 Wiedergabepolitik-Kombinationen |
| DockPreview-Core | 16 Geometrie-/Fensterzuordnungschecks |
| Native Prozess-Bridge | Beide Startreihenfolgen, drei Tools, Handshake vor Verstecken, Pause/Fortsetzen/Einstellungen/Beenden, regulärer und Absturz-Rückfall, Wiederverbindung, ältere inkompatible Version mit Timeout |
| FocusFrame-Settings-/Renderer-Harness | Gemeinsame SwiftUI-Wurzel, Seitenliste, numerische Eingabe/Persistenz, lokaler Einstellungsrahmen, Metalle, Fokusanimation ohne Neustart bei Bewegung, Pause/Fortsetzen, Move/Resize, Eingabetransparenz und Stop |
| LiveDesktop-Playback-Harness | Erster Frame, Wechsel, Fehlerbeibehaltung, Wiederholung, Pause, klicktransparentes Desktop-Fenster, Fensterlevel und Decoder-Freigabe |

Die Bridge-Fixtures verwenden zufällige Notification-Kanäle und eigene Bundle-IDs. Der Playback-Harness verwendete zwei selbst erzeugte Farb-MP4s; seine historische Ausgabe „Apple playback“ belegt in diesem Lauf keine Apple-Asset-Prüfung. Der Settings-Harness bestand nach Korrektur seines AppDelegate-/Launch-Lifecycles; die Produktions-Fensterengine wurde dafür nicht geändert.

## Vom Benutzer bestätigte interaktive Prüfungen

| Bereich | Bestätigtes Ergebnis |
|---|---|
| FocusFrame-Vorschau, hell | Fenster sichtbar; Seitenwechsel, Schalter und Regler bedienbar |
| LiveDesktop-Vorschau, dunkel | Fenster sichtbar; Seitenwechsel und Schalter bedienbar |
| DockPreview-Vorschau, hell | Fenster sichtbar; Seitenwechsel, Schalter und Regler bedienbar |
| Echte Menüintegration | Alle drei echten Tools verbinden sich; ihre eigenen Symbole verschwinden erst nach Verbindung |
| Einstellungen über MacFitKit | Echte Einstellungsfenster erreichbar; FocusFrame und DockPreview ausdrücklich bestätigt, LiveDesktop über den geprüften Hintergrundwechsel |
| DockPreview | Hover zeigt Miniaturen; Klick aktiviert genau das gewählte Fenster; zentrale Pause/Aktivieren wirkt sichtbar |
| FocusFrame | Zentrale Pause/Aktivieren blendet den Rahmen aus/ein; vorhandenes Control–Option–F schaltet ebenfalls korrekt |
| LiveDesktop | Zentrale Pause hält das sichtbare Video an, Aktivieren setzt es fort; Wechsel auf einen anderen vorhandenen Hintergrund und zurück funktioniert |
| MacFitKit regulär beenden | Alle drei eigenen Symbole kehren zurück; Tools laufen weiter und DockPreview zeigt weiterhin Vorschauen |
| MacFitKit neu starten | Laufende Tools verbinden sich erneut und blenden ihre Symbole wieder aus; Einstellungen bleiben erreichbar |
| MacFitKit-Absturz | Nur der Menüprozess wurde mit SIGKILL beendet. Die Tool-Prozesse liefen weiter; der Benutzer bestätigte eigene Symbole und weiterhin funktionierende Rahmen, Videos und Dock-Vorschauen |
| Tools einzeln beenden/starten | FocusFrame-Rahmen kehrt zurück; LiveDesktop stellt denselben Hintergrund wieder her; DockPreview bietet Hover/Miniaturen/Fensterwahl ohne erneute Freigaben |
| Tastatur in FocusFrame | Seitenwechsel per Pfeiltasten, Tab/Shift–Tab und sichtbarer Tastaturfokus funktionieren |

Passive Statuslistener bestätigten echte Tool-Prozesse am Monorepo-Buildpfad mit `menuManaged=true`, auch nach Wiederverbindung. Das sind zusätzliche technische Nachweise; die sichtbaren Funktionsnachweise stammen aus den obigen Benutzerrückmeldungen.

## Offene Prüfungen

| Bereich | Verbleibende Abnahme |
|---|---|
| VoiceOver | Nicht geprüft. Der Benutzer möchte den manuellen Test derzeit nicht durchführen; keine Freigabe als barrierefrei abgeleitet. |
| Vollständige visuelle Abnahme | Nicht jede Seite jeder App in Hell/Dunkel geprüft. Erhöhter Kontrast, „Bewegung reduzieren“ und vollständige Zustands-/Fehlerdarstellungen bleiben offen. |
| Tastatur aller Apps | Grundlegende FocusFrame-Navigation bestätigt; vollständige Tastaturpfade in LiveDesktop, DockPreview und MacFitKit sowie jede Spezialansicht bleiben offen. |
| Wiederholbare Referenzansichten | Vollständige visuelle Vergleichsbilder fehlen. Ein NSView-Bitmap-Versuch zeichnete SwiftUI/Material unvollständig und wurde verworfen. |
| Hardware und Systeme | Kein echter Intel-Lauf; keine Abnahme auf macOS 14 oder LiveDesktops Mindestversion macOS 26. Universal-Builds ersetzen diese Läufe nicht. |
| Mehrere Monitore und Spaces | Monitorwechsel, unterschiedliche Skalierungen, Vollbild und Spaces-Sonderfälle nicht vollständig geprüft. |
| Freigaben und alte Versionen | Echte Apps mit vorhandenen Freigaben geprüft; fehlende/verweigerte Freigaben und inkompatible installierte Altversionen nicht vollständig interaktiv geprüft. Der ältere Protokollstand ist im isolierten Bridge-Test abgedeckt. Vorhandene Freigaben wurden nicht zurückgesetzt. |
| Automatische Wiedergabepausen | Alle 16 Policy-Kombinationen automatisch geprüft; echte Stromspar-/Akku-/Schlaf-/Thermal-Szenarien samt Menüanzeige noch offen. |
| Vollständiger Datenbestand | Bestehende Stores, Kern-Persistenztests und aktuelle Auswahl nach Neustart geprüft. Vollständige manuelle Abnahme aller vorhandenen Profile, Wechsellisten, Import-/Export-/Rücksetzfunktionen bleibt offen. |
| Autostart | Kennungen und bestehende Zuordnung erhalten; echtes Anmelden/Neustarten und Registrierung/Abmeldung noch nicht geprüft. Keine Login-Registrierungen wurden im Rahmen der Migration geändert. |

Die native Computersteuerung scheiterte wiederholt an `Sky Computer Use native pipe closed before response`, auch nach Reset. Die Benutzerprüfungen ersetzen die jeweils ausdrücklich bestätigten Punkte, nicht die restlichen offenen Prüfungen. Auf Wunsch des Benutzers werden derzeit keine weiteren manuellen Tests verlangt. Diese Liste bleibt für spätere gezielte Abnahmen erhalten.

## Lokaler Lauf und Rückweg

Builds und Testkopien liegen im Library-Cache. Für die echte Integration wurden die Vorschau-Fixtures und die noch laufende ältere LiveDesktop-Instanz beendet; anschließend liefen die geprüften Debug-Apps mit ihren bestehenden Bundle-IDs. Installierte App-Dateien wurden nicht ersetzt, Datenschutzfreigaben nicht zurückgesetzt.

Vor dem echten Start wurden vorhandene Einstellungsdomains, ursprüngliche App-Pfade/Laufzustände und Binärprüfsummen gesichert. Die lokale Sicherung liegt unter `~/Library/Caches/MacFitKit/real-session-20261015-055337`. Das dortige `restore.py` beendet die Entwicklungsbuilds und öffnet die zuvor laufenden installierten Apps. Es schreibt Einstellungsbackups nicht automatisch zurück.

Die Binärprüfsummen beider installierter Original-Apps blieben unverändert. Direkt nach dem Start änderte sich die von macOS gespeicherte Menüleistensichtbarkeit. LiveDesktops `settings.v1` wurde neu serialisiert, war nach JSON-Dekodierung inhaltlich identisch zur Sicherung. Spätere ausdrücklich geprüfte Bedieneingaben schreiben regulär in die bestehenden Stores.

## Während der Abnahme korrigierte Probleme

- UI-Vorschauen waren zunächst als Accessory-Apps schlecht erreichbar. Sie erhalten jetzt eine reguläre Aktivierung, ein Dock-Symbol, den Titelzusatz „UI-Vorschau“ und eine verzögerte Fensterpräsentation auf dem aktiven Space. Sichtbarkeit wurde anschließend vom Benutzer bestätigt.
- Die ephemere LiveDesktop-Vorschau erzeugte trotz leerer Medienauswahl ein leeres Desktop-Fenster. Im UI-Vorschaumodus wird dessen Erzeugung jetzt übersprungen.
- Bei mehreren App-Kopien konnte „Starten“ nach Beenden eines Entwicklungsbuilds auf eine ältere Installation zurückfallen. MacFitKit merkt sich innerhalb der laufenden Sitzung den zuletzt verwendeten gültigen Bundlepfad. Der echte FocusFrame-Neustart wurde danach am erwarteten Buildpfad bestätigt. Dieser Pfad wird nicht dauerhaft gespeichert.

`script/preview_ui.sh` und `script/preview_menu.sh` bleiben als getrennte Prüfhilfen erhalten. Der interaktive Menü-Test verwendet den echten Debug-Hub mit isolierten Tool-Fixtures und einem getrennten Kanal; sein alternativer Finder ist nur im Debug-Build auswählbar. Die entscheidenden Menüaktionen wurden anschließend mit den echten Apps geprüft.

Die Zusammenführung nach `main` ist eine Quellcode-Integration. Sie veröffentlicht keine Releases, ersetzt keine installierten Apps und archiviert keine ursprünglichen Repositories.
