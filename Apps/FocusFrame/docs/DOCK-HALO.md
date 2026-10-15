# Dock-Halo: lokaler Machbarkeitstest (2. Oktober 2026)

## Ergebnis

Ein statischer, klicktransparenter Halo um die AX-Zelle einer normalen App ist
machbar. Eine dauerhaft zuverlässige Markierung des tatsächlichen Dock-Symbols
mit flüssiger Vergrößerung und Auto-Hide ist mit den hier gemessenen öffentlichen
AX-Ereignissen **noch nicht machbar**. Der Prototyp ist deshalb separat, endlich
laufend und nicht in FocusManager, Einstellungen oder Autostart integriert.
Keine neue Version, DMG oder Veröffentlichung.

## Reproduzieren

Aus dem vorhandenen Repository:

```sh
./script/probe_dock_halo.sh --halo --seconds 20
```

Das Skript baut ein separates LSUIElement-App-Bundle im FocusFrame-Cache und
startet es über Launch Services. Ohne bereits vorhandene AX-Freigabe beendet
es sich ohne Berechtigungsdialog. Hier war dieser GUI-Start nicht berechtigt.
Es verändert keine TCC-, Dock- oder FocusFrame-Einstellungen.

Der ausdrücklich diagnostische Start mit geerbter Terminal-Berechtigung:

```sh
./script/probe_dock_halo.sh --stdio --halo --seconds 20
```

Ohne `--halo` werden nur Zuordnung/Ereignisse protokolliert. Die Laufzeit ist auf
2–120 Sekunden begrenzt. Keine wiederkehrenden Timer, kein Polling. Pro Anlass
zwei einmalige Geometrieproben nach 350 und 600 ms; unterschiedliche Proben
unterdrücken den Halo bis zum nächsten externen Ereignis. Diese Stichproben sind
keine Zusicherung, dass eine Dock-Animation fertig ist.

## Gemessene AX-Schnittstelle

Umgebung: ein Display, 2560 × 1080 AppKit-Punkte, Dock unten, Auto-Hide aus,
Vergrößerung an (nur read-only abgefragt). `AXApplication` enthält eine `AXList`.
Normale Symbole liefern `AXApplicationDockItem`, `AXURL`, `AXPosition`, `AXSize`.
Die laufende App wird über `NSRunningApplication.bundleURL` zugeordnet;
standardisierte, symlinkaufgelöste Datei-URLs müssen genau einmal übereinstimmen.
Keine Titelheuristik, keine Index-/Abstandsannahme. Handoff, Papierkorb, Trennlinien
und nicht eindeutig passende Einträge bleiben ausgeschlossen.

14–15 App-Kandidaten je nach transientem Dock-Zustand gefunden. Finder wurde bei Aktivierung eindeutig zugeordnet;
in der Terminal-Testsequenz: AX-Zelle in AppKit `(844.075, 5, 53, 69)`.
`OverlayWindow.isVisible=true`, `ignoresMouseEvents=true`. Ein vorübergehender Vordergrundprozess ohne Bundle-ID wurde nicht zugeordnet;
der Halo wurde entfernt. Der abschließende Test fand Codex eindeutig bei
`(1003.075, 5, 53, 69)` und schaltete dessen Halo sichtbar/klicktransparent.
Das Dock besitzt hier auch zwei gleich benannte Wine-Einträge mit identischer
Executable-URL: Namen oder eine vermeintliche PID aus der Dock-AX-Zelle würden
keine zuverlässige Identität liefern. Mehrfachmatches werden abgelehnt.

Die Zellgröße **53 × 69 pt ist keine exakte Icon-Kontur**. Sie enthält zusätzliche
Fläche für den Dock-Indikator/Abstände. Der Halo umrahmt bewusst die AX-Zelle;
er ist kein pixelgenauer Ring um Finder-Grafik oder individuelle App-Icon-Formen.

| Registrierung | App | Liste | App-Zellen |
| --- | --- | --- | --- |
| AXMoved | -25207 | -25207 | -25207 |
| AXResized | -25207 | -25207 | -25207 |
| AXLayoutChanged | -25207 | -25207 | -25207 |
| AXUIElementDestroyed | 0 | 0 | 0 |
| AXCreated | 0 | 0 | 0 |
| AXSelectedChildrenChanged | 0 | 0 | -25207 |

`0` bedeutet Registrierung erfolgreich, **nicht** bestätigte Zustellung für jede
Dock-Animation. `-25207` ist `notificationUnsupported`. Apple dokumentiert diesen
Rückgabefall für [AXObserverAddNotification](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification).
Keine privaten APIs, keine Dock-Injektion, keine Bildschirmaufnahme im Prototyp.
Ein zusätzlicher read-only WindowServer-Versuch lieferte für das Dock ein
bildschirmfüllendes Fenster, nicht dessen sichtbare Leiste: kein brauchbarer
Sichtbarkeitsnachweis.

## Verhalten und verbleibende Grenzen

| Fall | Prototyp / öffentliche Ereignisquelle | Nachweis und Grenze |
| --- | --- | --- |
| Aktive App wechselt | NSWorkspace-Aktivierung, Neuzuordnung, zwei Proben | Finder sichtbar geschaltet; nicht passende App ausgeblendet |
| Vergrößerung / Maus am Dock | Globaler Mausmonitor blendet aus; beim Verlassen zwei Proben | Keine AX-Abfrage auf dem Mausbewegungspfad; flüssiges Folgen ausdrücklich nicht implementiert; reales Hover-Verhalten noch nicht visuell abgenommen |
| Dock wird ein-/ausgeblendet | Auto-Hide ist eine Sperre | AX-Zellen/VisibleChildren beweisen tatsächliche Sichtbarkeit nicht; read-only `com.apple.dock/autohide` ist nur eine experimentelle Vorsichtsmaßnahme, keine stabile öffentliche Dock-Konfigurationsschnittstelle |
| Dock links / rechts | AX-Rechtecke statt fester Icon-Geometrie, alle drei Dock-Kanten als Maus-Sperrzone | Koordinatenmodell geeignet; keine physische Abnahme, Dock-Einstellung nicht verändert |
| Dock auf anderem Display | Aktueller AX-Baum, öffentliche Display-/Space-Ereignisse | Umrechnung relativ zur Oberkante des ersten Displays, nicht zur Display-Union; ein physisches Display getestet; Dock-Umzug kann ohne AX-Geometrieereignis geschehen |
| Dock startet neu / Einträge ändern sich | Workspace-Launch/Terminate, unterstützte AX-Ereignisse | Alte AX-Registrierungen entfernt, Baum neu erstellt; Dock nicht absichtlich neu gestartet |
| Sitzung wechselt | Workspace-Sitzungsereignisse | Overlay verborgen, Rückkehr neu abgeglichen; kein Logout-Test |
| Vollbild / Mission Control / unbekannte Layoutänderung | Space-Ereignis invalidiert den Halo | Wiederholte AX-Samples können trotzdem alte/unsichtbare Zellpositionen liefern; keine zuverlässige Dock-Sichtbarkeitsgarantie |

Die Sperrzone (160 pt an den seitlichen/unteren Displaykanten plus 100 pt um die
letzte Dock-Liste) ist bewusst konservativ und kann den Halo auch ohne Dock-
Interaktion verbergen. Während dieser Phase laufen keine AX-Abfragen durch
Mausbewegungen. Seltene Layoutänderungen ohne beobachtetes Ereignis können einen
Halo bis zum nächsten Ereignis oder Ende des Tests an alter Position belassen.
Auch die Änderung von Dock-Präferenzen wird nicht vollständig beobachtet.
**Nicht als dauerhaftes Produktfeature aktivieren.**

## Architektur und sinnvolle Alternative

`script/experiments/DockHalo/DockAccessibilityService.swift` liest ausschließlich
Dock-AX. Der separate Prototype-Controller beobachtet Workspace/Displays/Maus,
verwaltet Generationen und verwirft verspätete Proben. Er verwendet unverändert
`OverlayWindow` und `EffectRenderer`, mit eigenem, statischem blauem Stil und
Fensterlevel oberhalb des Docks. Keine Synchronisierung mit FocusManager und
keine zusätzliche Abfrage auf dem bestehenden Fenster-Ziehpfad.

Für ein belastbares Produkt zunächst den aktiven App-Namen und das App-Icon im
FocusFrame-Menüleistenbereich anzeigen: Aktivierung ist öffentlich über
[NSWorkspace.didActivateApplicationNotification](https://developer.apple.com/documentation/appkit/nsworkspace/didactivateapplicationnotification)
verfügbar und braucht keine fremden Dock-Koordinaten. Alternativ ein kurzer
Dock-Fokusimpuls bei eindeutigem, sichtbarem statischem Ziel; dieser müsste
Sichtbarkeit und Verhalten noch praktisch absichern. „Nur Fenster / nur Dock /
beides“ erst nach dieser Abnahme ergänzen. Gold, Chrom und Pulsieren bleiben später.

## Validierung

- Separater Swift/AppKit-Build und strenge lokale Ad-hoc-Signatur erfolgreich.
- Terminal-Diagnose mit bereits vorhandener AX-Berechtigung: Finder-Zuordnung,
  sichtbares Panel und Klicktransparenz-Flag, Entfernung beim Nichtmatch und
  automatisches Ende bestätigt. Physische Klickdurchleitung nicht neu geprüft.
- Separater GUI-Launch: fehlende AX-Freigabe korrekt erkannt, beendet ohne Prompt.
- Visuelle Automation: Dock-App-Zugriff lief in Timeout; Finder-Aufnahme enthält
  nur dessen Desktop-Fläche, nicht Dock/Overlay. Keine visuelle Halo-Abnahme
  aus dieser Aufnahme abgeleitet.
- `script/check.sh`: 31 Kernprüfungen, SwiftPM-Build, strenge Signatur und
  Xcode-Strukturprüfung bestanden. `script/test_overlay_geometry.sh`: 792 native
  Overlay-Prüfungen und 9 Renderer-Pixelprüfungen erneut bestanden.
- FocusFrame-Quellen, Version/Build und persönliche Einstellungen unverändert.
  Vollständiges Xcode sowie reale Mehrschirm-/seitliche Dock-/Auto-Hide-Tests
  weiterhin nicht bestätigt. Keine Systemeinstellungen dafür umgeschaltet.
