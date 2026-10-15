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
- DockPreview: Hover, Miniaturen und gezielte Fensteraktivierung wurden inzwischen vom Benutzer im echten migrierten Build bestätigt. Mehrmonitor-/Spaces-Sonderfälle bleiben offen; der frühere Nachweis steht zusätzlich in dock-preview-validation.md.
- Integration der drei migrierten Produktions-Apps mit dem echten MacFitKit-Menü unter den bestehenden Benutzerfreigaben. Die Bridge selbst ist mit nativen getrennten Testprozessen geprüft.
- Hardware-/Versionsläufe auf Intel und macOS 14 sowie Spaces-/Mehrmonitor-Sonderfälle.

Ein eigener NSView-Bitmap-Render-Versuch zeichnete SwiftUI-/Material-Inhalte unvollständig. Die Bilder wurden deshalb als ungeeignet verworfen und nicht als visuelle Nachweise aufgenommen. Der erste Start der drei UI-Testkopien war für den Benutzer nicht sichtbar. Die Prozesse liefen als Accessory-Apps ohne Dock-Symbol; der Prozessstart war daher kein Nachweis für erreichbare Fenster. Der Vorschaumodus verwendet jetzt reguläre Aktivierung, ein Dock-Symbol, den Titelzusatz „UI-Vorschau“ und eine verzögerte Fensterpräsentation auf dem aktiven Space. Die separate Preview-Bundle-ID bleibt erhalten; installierte Apps werden nicht verändert. Beim erneuten FocusFrame-Start meldete die eigene Fensterdiagnose `active=true regular=true visible=true key=true`; WindowServer führte das Fenster als onscreen. Der Benutzer hat anschließend bestätigt: „Fenster sichtbar“. Der Benutzer bestätigte danach auch den Seitenwechsel sowie die Bedienung von Schaltern und Reglern. Damit sind Sichtbarkeit und diese grundlegenden Interaktionen der hellen FocusFrame-Vorschau bestätigt. Der Benutzer bestätigte anschließend für die dunkle LiveDesktop-Vorschau ebenfalls Sichtbarkeit, Seitenwechsel und Schalterbedienung. Für die helle DockPreview-Vorschau bestätigte der Benutzer ebenfalls Sichtbarkeit, Seitenwechsel, Schalter und Regler. Die vollständige Seitenabnahme sowie Tastatur und VoiceOver bleiben offen. Die Computersteuerung fällt weiterhin beim Zugriff auf die native App aus.

LiveDesktop erzeugte im ursprünglichen ephemeren Vorschaumodus trotz leerer Medienauswahl ein leeres Desktop-Fenster. Die neue Vorschau überspringt die Erzeugung dieser Flächen vollständig. Normale Wiedergabe- und Probe-Läufe behalten ihre bisherige Initialisierung. Die Vorschauen starten keine IPC-Verbindung oder globalen Fenster-/Dock-Beobachter.

Die PRs mit UI-/Menüänderungen bleiben bis zur interaktiven Abnahme Entwürfe. Es wurde nichts automatisch gemergt, veröffentlicht, notarisiert oder installiert. Vor einem späteren lokalen Austausch sind bestehende Bundles/Einstellungen zu sichern und der Rückweg zu prüfen.

Zusätzlich ist der Strukturprüfer des vorhandenen FocusFrame-Xcode-Projekts an lokale Swift-Package-Produkte angepasst und erfolgreich: vollständige Quellenzuordnung, Core-Abhängigkeit, Shared-Produkte und geteilte Schemes bleiben geprüft. Die acht fertigen Debug-/Release-Bundles wurden nochmals auf Bundle-ID, Mindestversion, LSUIElement, Original-Icons, Signaturen und Universal-Architekturen geprüft.


## Interaktiver Test des gemeinsamen Menüs

`script/preview_menu.sh` startet die echte Debug-Version der MacFitKit-App mit drei isolierten Tool-Testbundles. Eigene Bundle-IDs und ein zufälliger Notification-Kanal schließen die installierten Apps aus. Der alternative Tool-Finder ist nur im Debug-Build auswählbar. FocusFrame und LiveDesktop starten als Testprozesse; DockPreview bleibt für die Prüfung von „Starten“ zunächst beendet. Die Test-Tools erzeugen keine Rahmen, Videos oder Dock-Aufnahmen. „Einstellungen“ öffnet ein beschriftetes Testfenster, „Pausieren“ ändert den Teststatus, „Beenden“ beendet nur das jeweilige Test-Tool. Autostart ist im Testfenster deaktiviert.

Der erste Lauf bestätigte den Verbindungsaufbau mit beiden gestarteten Test-Tools und das anschließende Verstecken ihrer eigenen Menüleistensymbole. Die eigene Fensterdiagnose von MacFitKit meldete `active=true regular=true visible=true key=true`. Die Benutzerprüfung der Menüaktionen ist noch offen. Dieses Verfahren prüft Menü und Kommunikation; es ersetzt nicht die spätere Integration mit den Produktions-Engines und vorhandenen Freigaben.


## Lokaler Lauf mit den echten Apps

Nach Benutzerhinweis auf den Testcharakter wurde auf die echten geprüften Debug-Bundles umgestellt. Die UI-/Menü-Testkopien und die noch laufende installierte LiveDesktop-Version wurden beendet. Alle vier echten Apps laufen aus dem Monorepo-Buildcache mit ihren bestehenden Bundle-IDs; installierte App-Dateien wurden nicht ersetzt. Vor dem Start wurden vorhandene Einstellungsdomains exportiert, ursprüngliche App-Pfade/Laufzustände und Binärprüfsummen gesichert und ein Rückkehrskript erstellt. Die lokale Sicherung liegt unter `~/Library/Caches/MacFitKit/real-session-20261015-055337`; `python3` mit dem dortigen `restore.py` beendet die Entwicklungsbuilds und öffnet die zuvor laufenden installierten Apps. Einstellungsbackups werden dabei nicht automatisch zurückgeschrieben.

Ein passiver Listener bestätigte Statusnachrichten aller drei echten App-Prozesse vom erwarteten Buildpfad, jeweils `menuManaged=true`: FocusFrame „Rahmen aktiv“, LiveDesktop „Wiedergabe läuft“, DockPreview „Bereit – bewege den Zeiger über ein App-Symbol im Dock.“ DockPreview erkennt damit vorhandene Freigaben. Diese Statusmeldungen bestätigen Verbindung und gemeldeten Enginezustand; Der Benutzer bestätigte inzwischen auch die sichtbare LiveDesktop-Wiedergabe und deren zentrale Pause/Fortsetzung. Dock-Hover, Miniaturen und gezielter Fensterfokus wurden anschließend vom Benutzer im echten migrierten Build bestätigt. Der Benutzer bestätigte anschließend, dass „DockPreview → Einstellungen …“ im echten gemeinsamen Menü das vollständige Einstellungsfenster der echten DockPreview-App öffnet. Damit ist dieser Steuerweg zwischen MacFitKit und DockPreview interaktiv bestätigt.

Nach dem Start sind die Binärprüfsummen beider installierter Original-Apps unverändert. Die geänderten Einstellungskeys betreffen die von macOS gespeicherte Menüleistensichtbarkeit; LiveDesktops `settings.v1` wurde neu serialisiert, ist nach JSON-Dekodierung inhaltlich identisch zur Sicherung.

Die Benutzerprüfung von DockPreview ergab: Beim Hover erscheinen die Miniaturen, und ein Klick bringt genau das ausgewählte Fenster nach vorne. Der Benutzer bestätigte danach auch die zentrale Pause-/Aktivieren-Aktion: Über MacFitKit pausiert DockPreview die Vorschauen und stellt sie nach Aktivieren wieder bereit. Der Benutzer bestätigte außerdem den regulären Rückfall beim Beenden des echten MacFitKit-Menüs: Alle drei eigenen Menüleistensymbole erscheinen wieder, alle Apps laufen weiter und DockPreview zeigt weiterhin Vorschauen. Nach erneutem Start von MacFitKit bestätigte der Benutzer, dass die eigenen Symbole wieder verschwinden und „FocusFrame → Einstellungen …“ das echte Einstellungsfenster öffnet. Ein passiver Statuslistener bestätigte dabei die erneute Verbindung aller drei unverändert weiterlaufenden Tool-Prozesse mit `menuManaged=true`. Der Benutzer bestätigte danach die sichtbare Wirkung von „LiveDesktop → Pausieren“ und „Aktivieren“: Das echte Hintergrundvideo bleibt stehen und läuft anschließend wieder weiter. Der zentrale Pause-/Aktivieren-Steuerweg für den echten FocusFrame-Rahmen ist als nächster Schritt offen.
