# Architektur und gemeinsame Gestaltung

## Abhängigkeiten

```text
Apps/FocusFrame   Apps/LiveDesktop   Apps/DockPreview   Apps/MacFitKit
      └───────────────────┬──────────────────┬────────────────┘
                    MacFitKitUI       MacFitKitPlatform
                         └─────────┬──────────┘
                              MacFitKitCore
```

Ein lokales Package, drei Library-Produkte. App-eigene Domain-Cores, Renderer, AX-Beobachter und Player bleiben in den App-Verzeichnissen. Keine App bindet das Executable einer anderen App ein. App-Projekte besitzen getrennte Produkte und behalten ihre Bundle-Identitäten und Mindestversionen. Das gemeinsame Package benötigt macOS 14.

## Gestaltung

- Native Systemschrift und semantische Primär-/Sekundärfarben statt fester Hell-/Dunkelpaletten.
- Systemakzent für interaktive Hervorhebung, GroupBox für Einstellungsgruppen und native Sidebar-Auswahl.
- Abstände 8 / 12 / 16 / 24 Punkte über KitSpacing.
- SettingsShell stellt Navigation, Seitenkopf und Scrollfläche. Jede App ergänzt fachliche Seiten; Allgemein, Berechtigungen (nur falls nötig) und Info bleiben wiedererkennbar.
- ToggleRow, SliderRow mit numerischem Editor, ChoiceRow, PermissionRow, LoginItemRow und StatusMessage werden gemeinsam verwendet. Numerische Eingabe erlaubt Komma und Punkt, verwirft nicht endliche/ungültige Werte und begrenzt den Wertebereich.
- Keine Steuerung allein über Farben oder Icons: zugängliche Beschriftungen und Statusnamen. Die Systemkomponenten übernehmen native Tastaturinteraktionen. Tatsächliche VoiceOver- und Kontrast-Abnahme ist gesondert dokumentiert.
- FocusFrame behält seinen Renderer einschließlich Bewegungsreduktion und Stromsparregeln; die SwiftUI-Preview-Brücke stoppt den Renderer beim Entfernen aus der Ansicht.

## Menüleistenprotokoll

Die feste Tool-Liste ordnet ToolID zu Bundle-ID und Mindestversion. Der Host sucht nur laufende Apps, /Applications, ~/Applications und registrierte Launch-Services-Pfade. Es gibt keinen rekursiven Scan.

Versionierte JSON-Envelope in Property-List-fähigen Notifications; Größenlimit 64 KiB, unbekannte Versionen/Befehle werden verworfen. Status enthält Tool-ID, PID, zufällige Prozessinstanz, manuellen Aktivstatus, kurzen Funktionsstatus und bestätigte Menüverwaltung. Übertragene PIDs werden gegen die erwartete laufende App-Identität geprüft. Die lokale Benachrichtigungsschnittstelle ist kein Sicherheitskanal gegenüber beliebigen Prozessen desselben Benutzerkontos und enthält deshalb keine privilegierten oder frei formulierbaren Befehle.

Ablauf: Tool meldet Status → Host bestätigt diese Instanz im nächsten Lebenszeichen → Tool versteckt sein eigenes Symbol und bestätigt die Menüverwaltung. Erst danach werden wartende Steueraktionen gesendet. Fehlende Antworten führen nach fünf Sekunden zu einem sichtbaren Fehler; es gibt keine erzwungene Terminierung. Ein normaler Host-Stop gibt Symbole sofort frei, ein fehlendes Lebenszeichen nach drei Sekunden. Die Lease liegt ausschließlich im Arbeitsspeicher.

ToolBridgeClient passt feste Befehle an bestehende App-Zustände an. LiveDesktop setzt nur manualPause und übergeht keine automatische PlaybackPolicy. MacFitKit verändert keine anderen App-Preferences direkt. Integrationstests injizieren einen eigenen Kanal und eigene Bundle-IDs, sodass sie unabhängig von installierten Tools laufen.

## Builds und Rückweg

Root-Builds schreiben ausschließlich in den Library-Cache. Die bisherigen Repositories bleiben unverändert; ihre importierten Commits sind durch unsquashed Subtree-Merges erreichbar. Die PRs sind aufeinander aufgebaut und müssen in dieser Reihenfolge übernommen werden: Import → Shared → FocusFrame → LiveDesktop → DockPreview → Menüintegration. Es wird nichts automatisch gemergt oder veröffentlicht.

Historische Release-Skripte bleiben erhalten. Releases aus dem Monorepo müssen einzeln versioniert und signiert werden; diese Migration führt weder Notarisierung noch einen Upload aus. Installierte Apps werden erst nach einer gesonderten lokalen Abnahme mit gesicherten Originalen ersetzt.
