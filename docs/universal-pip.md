# UniversalPiP

UniversalPiP ist eine eigenständige macOS-14-App im MacFitKit-Workspace. Der Implementierungsstand enthält einen einzelnen lokalen Fensterstream, ein nicht aktivierendes skalierbares Floating-Panel und die bestehende Menüleistenintegration. Die Live-Abnahme mit UTM und die Leistungsabnahme sind noch offen.

## Entwicklung

```sh
./script/build_and_run.sh UniversalPiP --build-only
./script/build_and_run.sh UniversalPiP --verify
swift test --package-path Packages/UniversalPiP --scratch-path "$HOME/Library/Caches/MacFitKit/UniversalPiPTests"
./script/check.sh
./script/build.sh all Release
./script/run_pip_fixture.sh
```

UniversalPiP hat die Bundle-ID `tech.highbyte.macfitkit.UniversalPiP`; das Swift-Modul des App-Targets heißt `UniversalPiPApp`, um die Namenskollision mit dem Library-Produkt zu vermeiden. Die lokale Library unter `Packages/UniversalPiP` benötigt keine andere App und kein Netzwerk. Die gemeinsame Oberfläche und Datenschutzfunktionen kommen aus MacFitKitShared. Die Root-Skripte und der Codex-Run-Eintrag unterstützen die neue App. Builds ersetzen keine installierten Apps.

## Bedienung und Datenschutz

UniversalPiP öffnen, Bildschirmaufnahme für diese App erlauben, erneut prüfen, ein Quellfenster wählen und „Vorschau starten“ drücken. Eine nachträglich erteilte Freigabe kann einen App-Neustart erfordern. DockPreviews Freigabe gilt nicht automatisch für UniversalPiP. Die reine Live-Vorschau benötigt keine Bedienungshilfen. Für den zusätzlich beauftragten Befehl „Originalfenster fokussieren“ gibt es eine optionale Bedienungshilfen-Freigabe, die nur auf ausdrücklichen Klick in den Berechtigungen angefragt wird. Eingabeüberwachung und Mikrofon werden nicht angefordert.

UTM-Fenster stehen zuerst. Eigene MacFitKit-Fenster sind von der Quellauswahl ausgeschlossen. Die Auswahl bindet an Fenster- und Prozess-ID und wechselt niemals anhand des Titels auf ein anderes Fenster. Ein neuer Prozess oder ein neues Fenster muss erneut ausgewählt werden.

Standardmäßig gibt es weder äußere Titelleiste noch untere Leiste. Beim Hover erscheint ein HUD im Bild: Original fokussieren, Pause/Fortsetzen, Quelle wechseln, Größenwahl, Optionen und Schließen. Ein Griff unten rechts verändert die Größe; Ziehen am Vorschaubild verschiebt das Fenster. Die Titelleiste lässt sich über Optionen wieder einschalten; die Auswahl wird gespeichert. Feste Größen sind 240, 400 und 800 Punkte Breite. Alle Bildränder bleiben durch Aspect Fit erhalten. „Pause“ stoppt den Stream und kennzeichnet das letzte Bild. „Quelle …“ öffnet die Auswahl. Schließen beendet die Sitzung, nicht die VM. Nach App-Neustart beginnt keine automatische Aufnahme. Autostart wird nicht eingeschaltet.

Frames werden nicht gespeichert oder hochgeladen. Ein einzelner wartender Frame und ein begrenzter Stream-Puffer halten die Verarbeitung begrenzt. Der angezeigte Pixelbuffer bleibt bis zum nächsten Bild oder Schließen erhalten. Statusprotokolle enthalten keine Fenstertitel oder Bilder.

## Architektur

`WindowSourceProvider` liefert Fenster-Metadaten. `CaptureSession` verwendet SCContentFilter für genau ein Fenster, SCStream mit BGRA/SDR, höchstens 30 fps, Queue-Tiefe 3 und ausgeschaltetem Audio/Cursor. Native Quellpixeldichte, Inhaltsrechteck und Capture-Ausgabemaße werden berücksichtigt. IOSurface wird direkt über eine CALayer dargestellt; es gibt keine JPEG-Konvertierung oder Screenshot-Polling für die Live-Vorschau.

`PiPSessionCoordinator` serialisiert Start, Stop und Größenupdates. Ein Generationstoken verwirft verspätete Ergebnisse. Größenupdates werden um 200 ms gebündelt. Frame-Callbacks gehen durch eine auf einen ausstehenden Wert begrenzte Mailbox zum Main Actor. Terminale Fehler haben Vorrang; Idle ersetzt kein noch wartendes Bild. Erst ein gültiges Bild setzt den Zustand auf live.

Quellen und Berechtigung werden während aktiver Aufnahme alle zwei Sekunden geprüft. Eine seit fünf Sekunden noch nie mit einem gültigen Bild gestartete Sitzung wird als nicht verfügbar markiert; unveränderte Bilder nach dem ersten Frame gelten nicht als Fehler. Blank/Suspended, Fehler und Quellenverlust zeigen einen deutlichen Text über dem letzten Bild. Quellenverlust kann ohne Bedienungshilfen nicht in jedem Fall von Minimierung unterschieden werden; die Meldung fordert daher zum Wiederherstellen oder erneuten Auswählen auf. Es gibt keinen Display-Capture-Fallback.

Sleep stoppt Capture und merkt eine aktive Sitzung. Wake prüft Quelle und Rechte vor genau einem Wiederanlauf. Manuelle Pause und Stop überschreiben diese Wiederanlaufabsicht. Ein Neustartfehler bleibt sichtbar und wird nicht endlos wiederholt.

`PiPPanelController` setzt Floating-Level, nonactivatingPanel, hidesOnDeactivate=false, canJoinAllSpaces und canJoinAllApplications. Ein Tracking-Bereich steuert das Hover-HUD; während Größen-/Optionsmenüs und Resize-Tracking bleibt es erreichbar. Titelleiste und HUD verändern die Aspect-Fit-Bilddarstellung nicht. Cmd-P pausiert/setzt fort; Cmd-Shift-F fokussiert das Original, Cmd-Shift-W schließt die Vorschau, Cmd-O öffnet die Auswahl. Diese Befehle gelten innerhalb der App und sind keine globalen Tastaturüberwacher. Main-Actor-UI und serielle Capture-Verarbeitung bleiben getrennt. Größe und Position werden in app-eigenen UserDefaults gespeichert und bei Monitortrennung in die sichtbare Fläche zurückgeholt. Vordergrund- und Vollbildwirkung müssen auf echter Hardware abgenommen werden; Systemoberflächen werden nicht überlagert.

## MacFitKit Integration

ToolID.universalPiP enthält die feste Bundle-ID und Mindestversion 14. Die Bridge-Version und Befehle bleiben erhalten. openSettings öffnet die Quellauswahl; setEnabled(false) pausiert; setEnabled(true) setzt die bestätigte Quelle fort oder öffnet ohne Quelle die Auswahl; quit beendet nur UniversalPiP. Das eigene Symbol verschwindet erst bei bestätigter Verbindung und kehrt nach Ablauf der vorhandenen Lease zurück. Das PiP ist unabhängig vom Menü-Host.

## Optionaler Fokus des Originals

Der Fokus-Befehl validiert die ausgewählte Fenster-/Prozess-ID erneut über ScreenCaptureKit und sucht innerhalb dieses Prozesses ein eindeutiges AX-Fenster anhand Titel und Geometrie. Mehrdeutige Treffer werden abgelehnt. Es werden nur öffentliche Accessibility-Aktionen verwendet; keine Maus- oder Tastatureingaben an die VM gesendet. Ein Quellenwechsel oder Schließen bricht einen ausstehenden Fokusauftrag ab. Ohne optionale Freigabe erklärt die App den Bedarf im Einstellungsfenster. Die Freigabe wurde im Test nicht neu erteilt; das tatsächliche AX-Fokussieren bleibt deshalb offen.

## Tests und Abnahme

19 automatische Modulprüfungen decken Aspect Fit, Retina-Ausgabe, negative Monitor-Koordinaten, Monitorverlust, Rechteverweigerung und -entzug, Quellenverlust, verspätete Frames, konkurrierende Starts, Pause während Start, Sleep bei manueller Pause, Resize-Debouncing den tatsächlichen NSPanel-Vertrag, rahmenlosen Standard, Hover-/Menü-Zustand, Titelleistenumschaltung und eindeutige Fokuszuordnung ab. Die isolierten Bridge-Prüfungen umfassen vier Tools sowie PiP-Pause, Fortsetzung, Einstellungen und Host-Ausfall. Die bestehenden Tool-Checks bleiben Teil von script/check.sh.

Die synthetische Testquelle aus `script/run_pip_fixture.sh` zeigt vier markierte Ränder, einen Kreis und einen laufenden Zeitwert. Sie wird als gesonderte App im Cache gebaut. Damit lassen sich Seitenverhältnis, Stillstand/Idle und Verzögerung prüfen, ohne private App-Inhalte zu verwenden.

Manuelle Freigabematrix:

- [ ] Zehn Minuten bewegtes UTM-Gastbild gleichzeitig im Original und PiP.
- [ ] 240, 400, 800 Punkte Breite; alle vier Ränder sichtbar, Kreis unverzerrt.
- [ ] Original und Gastauflösung ändern; korrekte Bildanpassung.
- [ ] Zehn App-Wechsel und aktive Bedienung des Originals.
- [ ] Quelle überdecken, minimieren, verbergen, schließen und neu öffnen; eindeutiger Live-Status.
- [ ] Normale Spaces, UTM-Vollbild, fremde Vollbild-App und Stage Manager.
- [ ] Sleep/Wake, Monitortrennung und Wechsel der Pixeldichte.
- [ ] Tastatur, VoiceOver, helles und dunkles Erscheinungsbild.
- [ ] P95 der sichtbaren Verzögerung höchstens 250 ms bei bis zu 30 fps, zehn Minuten.
- [ ] Kein stetiges Speicherwachstum über 30 Minuten; Lastvergleich mit UTM allein.
- [ ] Keine weitere Capture-Aktivität nach Stop; lokaler Signatur-/Freigabetest des Auslieferungsbundles.

## Plattformstand am 15. Oktober 2026

Referenzumgebung: MacBook Pro mit Apple M5 Pro und 64 GB RAM, macOS 27.2, Xcode 27.0. Der aktive Checkout liegt unter `/Users/darius/Documents/Codex/2026-10-15/referenced-chatgpt-conversation-this-is-an/outputs/macfitkit`; Ausgangspunkt ist main bei 8df3083. `/Users/darius/macfitkit` ist kein verwendbarer Checkout.

UTM liegt unter `/Users/darius/Applications/UTM Baerim Test.app`, Version 5.0.5. Das echte Fenster „Baerim2 – Windows ARM Test“ wurde über die native UI-Verbindung erreicht. QEMU-Hilfsprozesse sind vorhanden; die genaue VM-/Grafikkonfiguration wurde noch nicht verifiziert. Der erste Suchlauf mit dem exakten Namen UTM.app hatte diese umbenannte Installation übersehen.

Die native UI-Verbindung war für das anfängliche Einstellungsfenster zeitweise nicht erreichbar. Die echte PiP-Ansicht konnte anschließend gelesen und visuell geprüft werden. Das vollständige UTM-Bild, Pause/Fortsetzen, das rahmenlose Bild ohne HUD sowie die eingeblendete HUD-Steuerung und 400 Punkte Breite sind sichtbar bestätigt.

Die Capture-Engine absolvierte einen 600,18-Sekunden-Lauf mit 16.489 gültigen und 16.462 als verändert erkannten Bildern. Eine kurze manuelle Pause/Fortsetzung war Teil dieses Laufs. Das erste Bild kam nach etwa 0,394 Sekunden; das ist Startdauer und kein Nachweis der Ende-zu-Ende-Verzögerung. Nach dem Test wurde der Stream beendet. Nach dem HUD-Umbau erfolgte eine zusätzliche Live-Kurzprüfung; die Vorschau bleibt im Entwicklungsbuild geöffnet.

Ein dabei gefundener Retina-Fehler ist korrigiert und durch einen Regressionstest abgedeckt: Das ScreenCaptureKit-contentRect in Punkten wird mit scaleFactor in Pixel umgerechnet. contentScale ist bereits in dieser Geometrie berücksichtigt und darf nicht nochmals angewendet werden. Die korrigierte Ausgabe zeigt alle Fensterbereiche, keinen vergrößerten Ausschnitt.

Das separate Testprogramm PiPCaptureProbe hatte zunächst einen Initialisierungsfehler: UserDefaults wurde mit der eigenen Bundle-ID als Suite geöffnet und ungeprüft ausgewertet. Es verwendet jetzt einen eigenen Settings-Namensraum mit sicherem Rückfall und prüft Startargumente. Sein eigener Capture-Zugriff ist nicht freigegeben; die Live-Nachweise stammen aus der eigentlichen UniversalPiP-Debug-App mit eigener erkannter Bildschirmaufnahme-Freigabe.

Die 30-Minuten-Speicherprüfung und das P95-Ziel von höchstens 250 ms sind offen. Die protokollierten kurzen Prozess-RSS-/CPU-Stichproben ersetzen diese Abnahmen nicht. Auch Intel-Lauf, macOS 14, VoiceOver, reale Monitorwechsel, Stage Manager und systematische Vollbild-/Spaces-Prüfungen bleiben offen.

## Lokale Auslieferung und Rückweg

Release-Bundles bleiben zunächst im Build-Cache beziehungsweise als ZIP-Prüfpaket. Keine Veröffentlichung oder Notarisierung. Der Austausch installierter Apps erfordert den im Auftrag separat vorgesehenen Installationsauftrag. Dabei sowohl das MacFitKit-Menü als auch UniversalPiP berücksichtigen: Das aktuell installierte alte Menü kennt den neuen Tool-Fall noch nicht.

Vor Installation bestehendes MacFitKit-Bundle und app-eigene Einstellungen sichern, Signaturen und Binärprüfsummen des neuen Builds prüfen und vorhandene Originale erhalten. UniversalPiP darf zunächst eigenständig getestet werden. Bei Rückkehr die vorherige Menü-App wiederherstellen und UniversalPiP regulär beenden; die drei bestehenden Tools und ihre Datenschutzfreigaben bleiben erhalten. TCC wird nicht zurückgesetzt. Mehrere PiPs und Eingabeweiterleitung bleiben spätere separate Erweiterungen.
