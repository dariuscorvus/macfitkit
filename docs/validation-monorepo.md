# Monorepo-Validierung

Stand: 15.10.2026. Codebasis: aufeinander aufbauende PRs #2–#7. Keine Veröffentlichung und keine Änderung installierter Apps.

## Builds und Herkunft

- FocusFrame-Main `15e3b58e548fad876c34a4ec5d7503691b13479a` und LiveDesktop-Main `21e90a2769f906c03b15e916b6e55e5adf753e03` vor Import gegen GitHub geprüft und ohne Squash per Subtree übernommen. Beide sind weiterhin Vorfahren der Migration.
- Bestehendes FocusFrame-Xcode-Projekt erhalten; LiveDesktop- und optionales MacFitKit-Projekt ergänzt. Workspace hat vier eigenständige App-Schemes.
- Alle vier Apps in Debug und Universal-Release erfolgreich gebaut; Signaturen mit `codesign --verify --deep --strict` geprüft. Beide Architekturen über `lipo` kontrolliert.
- App-Identitäten und Mindestversionen entsprechen dem Migrationsplan. FocusFrame/LiveDesktop verwenden weiter ihre vorhandenen Icons, Versionsdateien und Store-Formate.
- FocusFrame PreferencesStore und LiveDesktopCore/Settings.swift sind gegenüber den importierten Quellen unverändert. Die UI-Adapter schreiben in die bisherigen Stores. Tests verwenden separate Domains oder ephemere Controller.
- Builds/Tests liegen im Library-Cache. Original-Repositories, installierte Bundles, produktive UserDefaults, Login-Registrierungen und Datenschutzfreigaben wurden nicht ersetzt oder zurückgesetzt.

## Bestandene Prüfungen

| Prüfung | Ergebnis |
|---|---|
| `script/check.sh` | Erfolgreich |
| Shared Swift Testing | 4 Tests: Lease/Timeout, Version/ungültige Nutzlasten, Identitäten, numerische Komma-/Punkt-Eingabe |
| FocusFrame-Core | 34 Tests in 6 Suites, inklusive Persistenz, Konfiguration, Effekte und Bewegung |
| LiveDesktop-Core | Katalog, Apple-Metadaten, Favoriten/Wechsellisten-Persistenz und alle 16 Wiedergabepolitik-Kombinationen |
| DockPreview-Core | 16 Geometrie-/Fensterzuordnungschecks |
| Native Prozess-Bridge | Beide Startreihenfolgen, drei Tools gleichzeitig, Handshake vor Verstecken, Pause/Fortsetzen/Einstellungen/Beenden, Absturz-Rückfall, regulärer Rückfall, Wiederverbindung und ältere inkompatible Version mit Timeout |
| FocusFrame-Settings-/Renderer-Harness | Gemeinsame SwiftUI-Wurzel und Seitenliste, numerische Eingabe/Persistenz, echter lokaler Einstellungsrahmen, Metalle, Fokusanimation ohne Neustart bei Bewegung, Pause/Fortsetzen, Move/Resize, Eingabetransparenz und Stop |
| LiveDesktop-Playback-Harness | Erster Frame, Wechsel, Fehlerbeibehaltung, Wiederholung, Pause, klicktransparentes Desktop-Fenster, Fensterlevel und Decoder-Freigabe |

Die Bridge-Prüfung nutzt zufällige Notification-Kanäle und eigene Bundle-IDs. Sie steuert keine installierten Tools. Der Playback-Test wurde mit zwei selbst erzeugten Farb-MP4s ausgeführt; seine historische Ausgabe „Apple playback“ beschreibt in diesem Lauf keine Apple-Asset-Prüfung.

Beim ersten Settings-Harness-Lauf fehlte die aktive Key-Window-Voraussetzung. Nach korrektem Test-AppDelegate-/Launch-Lifecycle besteht der Harness. Dies war keine Änderung der Produktions-Fensterengine.

## Gemeinsame Gestaltung und offene Abnahmen

Alle Apps verwenden die gemeinsame SettingsShell und tatsächlich dieselben Schalter-, Auswahl-, Regler-, Freigabe- und Statuskomponenten. Specialized Views bleiben für Fensterkarten, Effektdarstellung und Videobibliothek bestehen. Es gibt keine zweite gespeicherte App-Konfiguration.

Die interaktive Computersteuerung antwortet wiederholt mit `Sky Computer Use native pipe closed before response`, auch nach Session-Reset. Daher sind folgende Punkte ausdrücklich noch offen:

- Vollständige visuelle Abnahme sämtlicher Seiten in Hell/Dunkel und mit erhöhtem Kontrast.
- Tatsächliche Tastatur-/VoiceOver-Bedienung aller neuen Oberflächen.
- Echte Dock-Hover-/Fensterfokus-Abnahme der UI-migrierten DockPreview-App; der vorherige Nachweis bleibt in dock-preview-validation.md als historisch erhalten.
- Integration der drei migrierten Produktions-Apps mit dem echten MacFitKit-Menü unter den bestehenden Benutzerfreigaben. Die Bridge selbst ist mit nativen getrennten Testprozessen geprüft.
- Hardware-/Versionsläufe auf Intel und macOS 14 sowie Spaces-/Mehrmonitor-Sonderfälle.

Ein eigener NSView-Bitmap-Render-Versuch zeichnete SwiftUI-/Material-Inhalte unvollständig. Die Bilder wurden deshalb als ungeeignet verworfen und nicht als visuelle Nachweise aufgenommen. Der erste Start der drei UI-Testkopien war für den Benutzer nicht sichtbar. Die Prozesse liefen als Accessory-Apps ohne Dock-Symbol; der Prozessstart war daher kein Nachweis für erreichbare Fenster. Der Vorschaumodus verwendet jetzt reguläre Aktivierung, ein Dock-Symbol, den Titelzusatz „UI-Vorschau“ und eine verzögerte Fensterpräsentation auf dem aktiven Space. Die separate Preview-Bundle-ID bleibt erhalten; installierte Apps werden nicht verändert. Beim erneuten FocusFrame-Start meldete die eigene Fensterdiagnose `active=true regular=true visible=true key=true`; WindowServer führte das Fenster als onscreen. Der Benutzer hat anschließend bestätigt: „Fenster sichtbar“. Der Benutzer bestätigte danach auch den Seitenwechsel sowie die Bedienung von Schaltern und Reglern. Damit sind Sichtbarkeit und diese grundlegenden Interaktionen der hellen FocusFrame-Vorschau bestätigt. Die übrigen App-Vorschauen, vollständige Seitenabnahme, Tastatur und VoiceOver bleiben offen. Die Computersteuerung fällt weiterhin beim Zugriff auf die native App aus.

LiveDesktop erzeugte im ursprünglichen ephemeren Vorschaumodus trotz leerer Medienauswahl ein leeres Desktop-Fenster. Die neue Vorschau überspringt die Erzeugung dieser Flächen vollständig. Normale Wiedergabe- und Probe-Läufe behalten ihre bisherige Initialisierung. Die Vorschauen starten keine IPC-Verbindung oder globalen Fenster-/Dock-Beobachter.

Die PRs mit UI-/Menüänderungen bleiben bis zur interaktiven Abnahme Entwürfe. Es wurde nichts automatisch gemergt, veröffentlicht, notarisiert oder installiert. Vor einem späteren lokalen Austausch sind bestehende Bundles/Einstellungen zu sichern und der Rückweg zu prüfen.

Zusätzlich ist der Strukturprüfer des vorhandenen FocusFrame-Xcode-Projekts an lokale Swift-Package-Produkte angepasst und erfolgreich: vollständige Quellenzuordnung, Core-Abhängigkeit, Shared-Produkte und geteilte Schemes bleiben geprüft. Die acht fertigen Debug-/Release-Bundles wurden nochmals auf Bundle-ID, Mindestversion, LSUIElement, Original-Icons, Signaturen und Universal-Architekturen geprüft.
