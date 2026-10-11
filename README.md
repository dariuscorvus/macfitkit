# LiveDesktop 0.3.1

Eigenständiges natives macOS-Utility neben FocusFrame. Swift 6,
SwiftUI/AppKit/AVFoundation, macOS 26+, keine externen Pakete und keine Cloud.

## Benutzen

Die App läuft in der Menüleiste: auf das Video-Rechteck klicken.

- Lokal gespeicherte Apple-Standardhintergründe erscheinen mit ihren Apple-Namen,
  Kategorien und vorhandenen Vorschaubildern.
- Suchfeld benutzen, z. B. „Morgen“. Ein Klick auf einen Hintergrund startet ihn.
- „Anzeigen auf“ wählt alle oder einen bestimmten Bildschirm.
- Das Pause-Symbol hält das aktuelle Bild an; „macOS-Hintergrund zeigen“ entfernt
  die Videofläche auf den gewählten Displays.
- Unter „Weitere Optionen“: Apple-Hintergründe verwalten, eigenes Video, Ordner,
  Stromspar-Pause und Beenden.
- Display-Zuordnungen, eigene Videos und hinzugefügte Ordner bleiben nach einem
  Neustart erhalten. Neue Apple-Downloads über „Neu suchen“ einlesen.

Auf diesem Mac erkannt und im UI geprüft: **Mammutbaum am Morgen** und
**Mammutbaum bei Sonnenaufgang**, Kategorie Landschaft. Die Namen stammen aus
Apples lokalen deutschen Übersetzungen. Keine eingebauten UUID-Namenslisten.
Beim abschließenden Neustart wurde zusätzlich **Mammutbaum bei Nacht** lokal
erkannt und als aktive Auswahl wiederhergestellt.

Nur lokale Videos sind auswählbar. Ein in Apples Galerie sichtbarer Hintergrund
kann noch nicht heruntergeladen sein. „Apple-Hintergründe verwalten …“ öffnet die
macOS-Hintergrundbild-Einstellungen; dort einen animierten Hintergrund laden,
dann LiveDesktop neu suchen lassen. LiveDesktop lädt keine Videos oder Vorschauen
herunter, verändert keine Apple-Dateien und stellt das System-Wallpaper nicht um.
Statische Bilder und dynamische HEIC-Hintergründe werden nicht als Videos behandelt.

## Autostart und automatischer Wechsel

Die installierte App liegt unter `/Applications/LiveDesktop.app`.
„Beim Anmelden starten“ lässt die gespeicherte Display-Auswahl beim Anmelden
wieder anlaufen. Das Ausschalten entfernt die Registrierung. Der tatsächliche
Logout/Login wurde nicht automatisiert getestet; Registrierung und Neustart schon.

„Hintergründe automatisch wechseln“ zeigt Auswahlkästchen neben den Videos.
Mindestens zwei markieren und 1, 5, 15, 30 oder 60 Minuten wählen.
„Jetzt wechseln“ wechselt sofort zum nächsten markierten Video.
Die Reihenfolge entspricht der Markierungsreihenfolge, ohne Zufall oder Downloads.
Auswahl, Aktivierung und Intervall bleiben nach Neustart erhalten.

Der Wechsel gilt gemeinsam für Displays mit aktivem Video; Displays mit
„macOS-Hintergrund zeigen“ bleiben frei. Jedes aktive Display geht von seinem
aktuellen Video zum nächsten Kandidaten weiter. Fehlende/unlesbare Videos werden
übersprungen. Während manueller Pause, Schlaf, inaktiver Sitzung, Stromspar-Pause
oder thermischer Pause wird nicht gewechselt. Nach Rückkehr läuft der nächste
reguläre Timer-Takt; verpasste Wechsel werden nicht nachgeholt.

Updates in den Programme-Ordner installieren und starten:

```sh
./script/install_and_run.sh
```

## Bauen und starten

```sh
./script/build_and_run.sh
./scripts/check-core.sh
# Mit vollständiger Xcode-Testumgebung zusätzlich:
swift test
```

Das Startskript beendet vorher laufende LiveDesktop-Instanzen, baut im lokalen
Cache, erzeugt und signiert die App ad-hoc, startet sie und schreibt
`dist/LiveDesktop.zip`. Die Codex-Run-Konfiguration verweist auf dasselbe Skript.
App-Bundle: `~/Library/Caches/LiveDesktop/App/LiveDesktop.app`.
Nach Entpacken der ZIP kann die App z. B. in `~/Applications` liegen.
„Beim Anmelden starten“ registriert die installierte App als macOS-Anmeldeobjekt.
Der Schalter zeigt den Systemstatus; falls macOS eine Freigabe verlangt, erscheint
zusätzlich ein Button zu den Anmeldeobjekten. Keine öffentliche Distribution oder
Notarisierung.

Der native SwiftPM-Buildmodus ist wegen der hier installierten CLT erforderlich
und in Swift 6.4 deprecated. Build-Dateien außerhalb von Documents vermeiden
Signierungsprobleme mit Dateimetadaten. Diese CLT enthalten keine nutzbare
XCTest-Umgebung. `check-core.sh` führt dieselben XCTest-Testmethoden mit einfachen
Assertions aus; das ersetzt keine Integrationstests.

## Lokale Apple-Erkennung

Schreibgeschützte Videowurzeln:

- `~/Library/Application Support/com.apple.wallpaper/aerials/videos` (hier benutzt)
- `/Library/Application Support/com.apple.idleassetsd/Customer`
- `~/Library/Application Support/com.apple.idleassetsd/Customer`
- hinzugefügte Ordner und explizit ausgewählte Dateien

Metadaten: lokale `entries.json` in Apples Wallpaper-Erweiterung, im älteren
idleassetsd-Cache und im Benutzer-Wallpaper-Manifest. Die Namensauflösung liest
`TVIdleScreenStrings.bundle` mit `.loctable` und `.strings`, bevorzugt die
Systemsprache, fällt auf Englisch bzw. Dateinamen zurück. Neuere Benutzer-
Metadaten ergänzen den Systemkatalog. Lokale PNG-Vorschauen werden über die
Asset-ID zugeordnet. UUID-Dateinamen und im Manifest genannte Video-Basenamen
werden unterstützt. Netzwerk-URLs werden ausschließlich als Namen gelesen.

Diese Pfade und Dateiformate sind undokumentierte Implementierungsdetails,
keine garantierte Apple-Katalog-API. Fehlende Standardordner sind normal.
Defekte Metadaten verhindern die Auswahl eigener Videos nicht. MOV/MP4/M4V
sind Kandidaten; AVFoundation prüft die Abspielbarkeit beim Laden.
Symlink-Verzeichnisse werden nicht verfolgt. Die App ist nicht sandboxed und
speichert lokale Dateipfade in UserDefaults; verschobene Dateien neu auswählen.

## Desktop-Ebene und Performance

Ein nicht aktivierbares, nicht fokussierbares, klickdurchlässiges borderless NSPanel pro Display,
`desktopWindow + 1`, unter `desktopIconWindow`. Erst das erste darstellbare
Videobild macht es sichtbar. AVPlayerLayer füllt den Bildschirm mit Aspect Fill;
Audio ist stumm, Video verhindert keinen Display-Schlaf.
Die dekorative Videofläche ist kein Bedienungshilfen-Element. Die zugänglichen
Menü- und Einstellungsoberflächen bleiben davon unabhängig.

Der Nutzer bestätigte auf dem getesteten Display: Video sichtbar hinter den
Icons, Icons bedienbar. Eine garantierte Live-Wallpaper-Integration bietet Apple
hiermit nicht. macOS 26, Spaces, Mission Control, Stage Manager, Desktop-Gesten
und Multi-Display-Hotplug bleiben eigenständige Abnahmepunkte.

Eigener AVQueuePlayer/AVPlayerLooper pro Display, persistente Display-UUIDs.
An-/Abschluss, Position und Auflösung werden abgeglichen. Gleiche Videos auf
mehreren Displays laufen unabhängig; der Aufwand steigt mit Displays und Codec.
Hardwarebeschleunigung liegt bei AVFoundation und ist nicht garantiert.

Pause bei manueller Pause, inaktiver Sitzung, Bildschirm-/Systemschlaf,
Stromsparmodus (abschaltbar) und thermischen Zuständen serious/critical. Kein
automatisches Pausieren für jeglichen Akkubetrieb oder vollständig verdeckte
Desktops. Pause gibt Decoder/Layer nicht vollständig frei. Energieprofil offen.

## Struktur und Prüfstand

- `Sources/LiveDesktopCore`: lokale Datei-/Apple-Katalog-Erkennung, Pause-Policy
- `Sources/LiveDesktop`: Menüleisten-Popover, SwiftUI-Bibliothek, Display-Verwaltung,
  Desktop-Fenster und Player
- `Tests/LiveDesktopCoreTests`: Dateisuche, Übersetzungen, lokale Downloads,
  defekte Metadaten, explizite Videos und kombinierte Pause-Gründe
- `script/build_and_run.sh`, `scripts/build-app.sh`: Start und App-Paket
- [Autostart und Wechsel-Test](docs/AUTOSTART-ROTATION.md)
- [Apple-Auswahl-Test](docs/APPLE-LIBRARY.md)
- [Finder-Icon-Test](docs/ICON-TEST.md)
- [Machbarkeit und Abnahmeschritte](docs/FEASIBILITY.md)
- [Historischer Build-/Player-Prüfstand](docs/VALIDATION.md)

Diagnose: `--show-library` öffnet dieselbe Bibliothek als Testfenster;
`--show-menu` öffnet das tatsächliche Menüleisten-Popover. Diese Optionen sind
keine Voraussetzung für normale Nutzung. Der zeitlich begrenzte Desktop-Test:

```sh
./script/build_and_run.sh --probe --probe-seconds 30 --video /absolute/path/video.mov --report /absolute/path/probe.txt
```

Der Test speichert keine Wallpaper-Zuordnungen. `probe.txt.progress` enthält
Player-Zustand und beobachtete Fensterreihenfolge. Keine Videos mitgeliefert.
Noch keine Release-Lizenz festgelegt. Nächste Schritte: macOS-26-/Spaces-/Hotplug-
Abnahme, Energieprofil mit Apple-Videos, optional Autostart und Release-Signing.
