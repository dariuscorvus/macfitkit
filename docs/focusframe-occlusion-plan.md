# FocusFrame: Rahmen bei überlappenden Fenstern

Status: Im Quellcode umgesetzt am 17.10.2026; anschließend Dock-Regression korrigiert und auf dem Mac mini sichtbar geprüft. Die veröffentlichten Preview-3-Pakete enthalten diese Korrektur noch nicht. Der neue Fix wurde nur im gesicherten Testbundle auf dem Mac mini ausgeführt; die regulär installierte FocusFrame-App wurde nicht ersetzt.

## Umgesetzte Lösung

`FocusManager` ordnet das fokussierte AX-Fenster anhand von Prozess und eindeutiger Geometrie den öffentlichen WindowServer-Metadaten zu. Anschließend bleibt die Fenster-ID für dieselbe AX-Fokusgeneration erhalten, auch während zeitversetzter Move-/Resize-Meldungen. Eigene Einstellungen verwenden direkt ihre öffentliche AppKit-Fensternummer. Mehrdeutige oder fehlende Erstzuordnungen und verschwundene Ziele blenden sämtliche Effektpixel aus.

Alle sichtbaren, nicht vollständig transparenten Fenster vor dem Ziel bleiben für die Zielzuordnung erhalten. Für die zusätzliche Rechteckmaske werden nur Fenster auf oder unter der tatsächlichen Overlay-Ebene berücksichtigt. Höhere Ebenen verdeckt der WindowServer bereits nativ, einschließlich ihrer tatsächlichen Form und Transparenz. Das eigene Overlay wird ausgeschlossen. Eine Maske am Canvas-Elternlayer begrenzt den vollständigen Renderer einschließlich Rahmen, Leuchten und Schatten. Disjunkte Rechtecksubtraktion bildet die Vereinigung der Abdeckungen ohne doppelte Löcher. Ein Geräte-Pixel Sicherheitsrand vermeidet Effektreste an fractional/antialiasierten Grenzen. Die innere Effektmaske und die Bewegungskompensation bleiben erhalten.

Die Maske wird ohne implizite Animationen geändert. Vollständige Überdeckung macht den Renderer transparent; Layer und Animationsphasen bleiben für das Freilegen erhalten. Pause, Schlaf, Space-Wechsel und fehlendes Ziel stoppen den Metadaten-Timer. Nur bei einem aktiven Ziel läuft der Abgleich: 10 Hz im Leerlauf, 30 Hz bei gedrückter Maustaste, 4 Hz im Stromsparmodus. Zusätzliche Geometrieereignisse teilen sich dieselbe Begrenzung auf maximal 30 bzw. 4 Metadatenabfragen pro Sekunde. Keine Pixelaufnahmen und keine zusätzlichen Freigaben.

Der begrenzte native Versuch bestätigt, dass ein auf Normal-Level relativ zum fremden Ziel angeordnetes Overlay hinter dessen Floating-Panel bleibt. Das belegt keine allgemein zuverlässige Kopplung an fremde Fenster für alle App-/Space-/Level-Kombinationen; die Produktionslösung kombiniert daher die zusätzliche Verdeckungsmaske für niedrigere/gleiche Ebenen mit der nativen Komposition höherer Ebenen.

Halbtransparente Fenster und abgerundete Ecken auf oder unter der Overlay-Ebene werden konservativ anhand rechteckiger Bounds verdeckt. Höhere Ebenen behalten ihre native Transparenz, etwa das Material eines macOS-Kontextmenüs. Änderungen nicht aktivierender fremder Fenster können bis zum nächsten Abgleich sichtbar werden (nominal ca. 33/100/250 ms je Modus, zuzüglich Systemlast). Das ist keine atomare Kopplung an den WindowServer-Compositor.

## Dock-Korrektur und sichtbare Mac-mini-Prüfung

Die erste Maskenversion berücksichtigte auch ein bildschirmgroßes Dock-Fenster mit gemeldetem Alpha 1 auf Ebene 20. Seine überwiegend transparenten Pixel ließen sich aus den öffentlichen Bounds nicht erkennen. Dadurch wurde selbst ohne echte Abdeckung die gesamte Effektfläche ausgeschnitten. Die Korrektur prüft die tatsächliche Overlay-Ebene (derzeit 3), ohne Dock-Prozessnamen oder Bundle-IDs auszunehmen: Höhere Ebenen werden vom Compositor verdeckt und erzeugen keine zusätzlichen Rechtecklöcher. Normale Fenster auf Ebene 0 und Panels auf Ebene 3 bleiben maskiert, wenn sie vor dem Ziel liegen.

Am 17.10.2026 auf dem Mac mini, ARM64, macOS 26.6.2, einem Display mit 1920 × 1080 Punkten/Pixeln geprüft. Die reguläre App-Identität und Signaturanforderung bleiben erhalten. Eine gesicherte Kopie des bisherigen Testbundles wurde vor dem Austausch angelegt. Bedienungshilfen waren im stabilen Testpfad freigegeben; keine TCC-Einträge wurden zurückgesetzt oder neue Bildschirmaufnahme-Freigaben verlangt.

Die native Desktop-Fixture verwendet ausschließlich eigene Fenster und einen neutralen Hintergrund. Der echte FocusManager beobachtet ihr fokussiertes Fenster; Rahmen, cyanfarbenes Leuchten und magentafarbener Schatten stammen aus dem echten FocusFrame-Testbundle. Bildschirmbelege wurden aus der Remote-Desktop-Verbindung gesichert, zusätzlich Fokus, öffentliche Stapelmetadaten und tatsächlicher Canvas-Maskenzustand geprüft.

| Fall | Ergebnis |
| --- | --- |
| Baseline trotz bildschirmgroßem transparentem Dock-Fenster | Alle drei Effekte sichtbar |
| Teilweise Abdeckung durch nicht aktivierendes Floating-Panel | Alle Effekte im abgedeckten Bereich verdeckt; außen sichtbar |
| Zwei sich gegenseitig überlappende Abdeckungen | Keine Effektinseln in den Abdeckungen |
| Vollständig verdecken, anschließend freilegen | Alle drei Effektfarben verschwinden; Farbanzahlen nach Freilegen identisch zur Baseline |
| Abdeckung verschieben | Ausschnitt folgt der neuen Position |
| Normales Fenster auf Ebene 0 vor dem fokussierten Ziel | Maske verdeckt Effekte trotz höherer Overlay-Ebene |
| Bildschirmgroße transparente Ebene 20 mit einer sichtbaren grünen Fläche | Nur die tatsächliche Fläche verdeckt; außerhalb bleiben die Effekte sichtbar |
| Natives NSMenu ragt über den rechten Fensterrand | Menü auf Ebene 101 liegt vor den Effekten; native Materialtransparenz bleibt erhalten |
| Eigenes Menüfenster auf Ebene 0 ragt über denselben Rand | Rahmen, Leuchten und Schatten werden im Menübereich ausgeschnitten |
| Zielfenster verschieben und vergrößern | Alle drei Effekte folgen; Ziel-ID bleibt erhalten |

Die opaken Abdeckungsinnenflächen wurden zusätzlich auf Farbreste geprüft (12/255 Farbtoleranz für die Remote-Bildübertragung). Die native Menütransparenz ist eine sichtbare Kompositionsprüfung, kein Nachweis vollständiger Opazität. Die Testszenen behalten das Zielfenster als Key Window und die Fixture als Vordergrundprozess. Das belegt diese konkreten Fälle; es ersetzt keine Prüfung sämtlicher Fremd-Apps oder ihrer Menüimplementierungen.

Weitere Prüfungen: 41 Core-Tests in acht Suites, Xcode Debug und Universal Release, Projektstrukturprüfung und native Geometrie-/Renderer-/Überdeckungsprüfungen bestanden. Auf dem Mac mini zusätzlich 792 AppKit-Geometriefälle, neun Renderer-Pixelprüfungen, vorhandene Effekt-/Animationsprüfungen sowie der getrennte native Überdeckungsprozess bestanden. Eine Stichprobe mit 100 Metadatenabfragen ergab dort rund 1,49 ms Mittelwert und 1,87 ms P95; das misst ausschließlich die Abfrage, keine Ende-zu-Ende-Latenz.

Nach dem Test wurden die Testprozesse beendet und die ursprünglichen Konfigurations- und Profildaten bytegleich wiederhergestellt. Autostart und Freigaben wurden nicht geändert. Die korrigierte Test-App bleibt gestoppt, ihr Vorgänger ist gesichert. Die reguläre Installation auf dem ursprünglichen Mac bleibt unverändert.

Reproduktion: `script/probe_occlusion_desktop.sh` aus `Apps/FocusFrame` baut und öffnet die native Fixture. Die beschrifteten Schaltflächen setzen die Testszenen. Die Fixture ändert keine FocusFrame-Einstellungen; für sichtbare Belege müssen Rahmen, Leuchten und Schatten im separaten Testlauf aktiviert sein. Optional liest `--commands /absoluter/pfad/phase-request.json` ausschließlich lokale Fixture-Kommandos `{ "phase": 0, "token": "eindeutiger-wert" }` (Phasen 0–9 gemäß Schaltflächen) und schreibt `phase-ready.json`. Bei Phase 8 erscheint das native Menü nach einer Sekunde und schließt nach 25 Sekunden; neue Kommandos werden nach Ende des Menütrackings verarbeitet. Der Start benötigt ein aktivierbares Fixture-Fenster und ein bereits für Bedienungshilfen freigegebenes FocusFrame-Bundle.

## Frühere Prüfungen der ersten Maskenversion am 17.10.2026

- 38 Kerntests in sieben Suites bestanden, einschließlich Vereinigung überlappender Abdeckungen, vollständiger Überdeckung/Freilegung, fractional/negativer Koordinaten, eindeutiger Prozesszuordnung und ID-Stabilität während Bewegung.
- `script/test_occlusion.sh` bestanden: zweiter nativer Prozess mit normalem sowie nicht aktivierendem Floating-Fenster; Verschieben, vollständige Überdeckung und Freilegen. Öffentliche Stapelmetadaten und tatsächliche Bitmap-Pixel des maskierten Renderers geprüft. Die Pixelprüfung verwendet ausschließlich die eigenen Fixture-Abdeckungen, damit private Desktopfenster das Ergebnis nicht beeinflussen; sie ist kein Screenshot fremder Apps. Alle drei Rahmenplatzierungen, doppelte Abdeckungen, kombinierter Rahmen/Glow/Schatten, unveränderte Effektlayer, Klickdurchlässigkeit und unveränderter Vordergrundprozess geprüft.
- Stichprobe mit 100 Metadatenabfragen: beispielsweise ca. 1,58 ms Mittelwert und 8,93 ms P95 in einem Lauf auf diesem Mac. Das ist die Abfragedauer, keine gemessene Ende-zu-Ende-Reaktionszeit oder langfristige CPU-/Speichermessung.
- Bestehender nativer Overlay-Test: 792 AppKit-Geometriefälle und neun Renderer-Pixelprüfungen sowie vorhandene Effekt-/Animationsprüfungen bestanden.
- Xcode Debug und Universal Release (ARM64 + x86_64) bestanden; Projektstruktur und `git diff --check` bestanden. Intel wurde gebaut, nicht auf Intel ausgeführt.
- Die bestehende Einstellungsfenster-Prüfung konnte ihr Fenster in dieser Sitzung nicht aktivieren (andere Vordergrund-Apps, `Active=false`, `key=nil`). Sie wird nicht als bestanden gewertet. Zusätzlicher Test prüft, dass ein eindeutig erkanntes Einstellungsziel keine leere Verdeckungsmaske erhält.

Offen bleiben sichtbare Abnahme mit tatsächlichen Fremd-Apps/UniversalPiP, Fokuswechseln und Tastenkürzel, mehrere Monitore/Skalierungen, echte Spaces-/Vollbild-/Sleep-Wake-Abläufe, macOS 14, langfristige CPU-/Speichermessung und Ende-zu-Ende-P95. Die automatischen Fixture-Ergebnisse ersetzen diese Abnahme nicht.

Reproduzierbar aus `Apps/FocusFrame`: `script/test.sh`, `script/test_overlay_geometry.sh`, `script/test_occlusion.sh`, `script/test_settings_window.sh`. Die drei nativen Skripte benötigen eine angemeldete Desktop-Sitzung; die Einstellungsprüfung benötigt ein aktivierbares Testfenster.

Die folgenden Abschnitte bewahren den ursprünglichen Plan und seine Abnahmekriterien.

## Problem und belegter Ausgangspunkt

Der Benutzer meldet, dass Rahmen oder Effekte des fokussierten Fensters über anderen, davorliegenden Fenstern sichtbar bleiben.

`OverlayWindow.swift` erstellt ein eigenes, nicht aktivierendes und klickdurchlässiges NSPanel mit `isFloatingPanel = true` und `level = .floating`. Beim Einblenden wird `orderFrontRegardless()` verwendet. Das Panel wird bisher nicht relativ zur Stapelposition des Zielfensters angeordnet. `EffectRenderer` maskiert die Fensterinnenfläche, berücksichtigt aber keine überdeckenden fremden Fenster. Das erklärt eine plausible Ursache; es ist noch kein vollständiger Nachweis für alle gemeldeten Fälle.

Die Beobachtung anderer Fenster darf nicht mit einem Fokuswechsel gleichgesetzt werden: Ein schwebendes PiP oder Werkzeugfenster kann das fokussierte Fenster überdecken, ohne ihm den Tastaturfokus zu nehmen.

## Gewünschtes Verhalten

- Der Rahmen gehört zum markierten Fenster und folgt dessen sichtbarer Kontur.
- Davorliegende Fenster verdecken auch Rahmen, Leuchten, Schatten und Animationen.
- Bei teilweiser Überdeckung bleiben die nicht verdeckten Rahmenteile sichtbar. Bei vollständiger Überdeckung verschwindet der Rahmen.
- Wird der Bereich wieder frei, erscheinen die zugehörigen Rahmenteile wieder.
- FocusFrame hebt weder das Zielfenster noch andere Apps an und übernimmt keinen Fokus.
- Einstellungen, Profile, Tastenkürzel, Rahmengeometrie und Klickdurchlässigkeit bleiben erhalten. Kein zusätzliches Bildschirmaufnahme-Recht.

## Vorgehen

### 1. Stapelposition reproduzierbar prüfen

Zwei eigene Test-App-Prozesse mit klar bezeichneten Fenstern plus schwebendem, nicht aktivierendem Panel verwenden. Fokus, WindowServer-Reihenfolge und Rahmen getrennt protokollieren. Teilüberdeckung, vollständige Überdeckung und Freilegen reproduzieren; keine privaten App-Inhalte aufzeichnen.

In einem begrenzten Versuch prüfen, ob das Overlay auf passendem Fensterlevel unmittelbar über dem Ziel angeordnet werden kann, ohne davorliegende Fenster zu überholen. Öffentliche AppKit-API verwenden. Eine zuverlässige Anordnung relativ zu fremden App-Fenstern ist zunächst experimentell nachzuweisen; kein Versprechen allein aus einem API-Aufruf ableiten. Keine privaten WindowServer-/SkyLight-APIs.

### 2. Ziel und Verdeckung unabhängig modellieren

Eine eigene Zuordnung aus Ziel-PID, AX-Geometrie und öffentlichen WindowServer-Metadaten liefern: Ziel-Fenster-ID, Stapelposition und Bounds. Mehrdeutige Zuordnungen explizit behandeln; kein beliebiges Fenster bei gleicher Größe wählen. Der bisherige AX-Fokus bleibt die Quelle für die Wahl des Ziels.

Mit `CGWindowListCopyWindowInfo` die von vorne nach hinten geordnete Liste der sichtbaren Fenster auswerten. Nur Fenster vor dem Ziel berücksichtigen; das eigene Overlay und nicht sichtbare beziehungsweise vollständig transparente Fenster ausschließen. Hinter dem Ziel liegende Fenster dürfen keine Löcher erzeugen. Bei fehlender oder mehrdeutiger Zielzuordnung den Rahmen vorübergehend ausblenden, statt ihn über fremde Fenster zu zeichnen.

### 3. Verdeckte Flächen begrenzen

Falls die native Reihenfolge nicht alle relevanten Fälle zuverlässig löst, die Überdeckungsbereiche aus der gesamten Effektfläche ausschneiden. Die Maske muss den vollständigen Renderer einschließlich Leuchten und Schatten umschließen. Mehrfach überlappende Abdeckungen gemeinsam behandeln, damit doppelte Ausschnitte keine sichtbaren Inseln erzeugen.

Fensterbounds liefern keine pixelgenaue Transparenz- oder Rundungsmaske. Für halbtransparente Fenster und abgerundete Ecken daher ein konservatives Verhalten festlegen und prüfen. Kein Bildschirm-Capture nur für diese Korrektur einführen.

CoreGraphics-Koordinaten, AppKit-Koordinaten, negative Monitorpositionen und Retina-Skalierung ausdrücklich abbilden. Bestehende Bewegungskompensation und Animationsphasen erhalten; eine reine Verdeckungsänderung darf keinen Effekt-Neuaufbau oder Fokus-Puls auslösen.

### 4. Aktualisierung begrenzen

Fokus-, Fenstergeometrie-, App- und Space-Ereignisse für Aktualisierungen verwenden. Bewegungen nicht aktivierender fremder Panels werden damit nicht vollständig beobachtet; solange ein Rahmen sichtbar ist, einen begrenzten Metadaten-Abgleich vorsehen. Während Interaktion schneller aktualisieren, im Leerlauf und Stromsparzustand reduzieren. Zuerst messen, dann konkrete Frequenzen festlegen. Kein Screenshot-Polling und kein dauerhaftes Neurendern aller Effekte.

## Abnahme

- Normale Fenster derselben und anderer Apps, Werkzeugfenster und UniversalPiP.
- Ein und mehrere überlappende Fenster; auch zwei sich gegenseitig überlappende Abdeckungen.
- Teilweise und vollständige Überdeckung; Verschieben, Resize und erneutes Freilegen.
- Rahmen innen, mittig und außen; Schatten, Leuchten, Verläufe und Animationen.
- Kein Fokuswechsel, keine Fensteranhebung und weiterhin klickdurchlässiges Overlay.
- Pause/Aktivieren und Tastenkürzel unverändert.
- Mehrere Monitore, Retina, negative Koordinaten, Spaces und Vollbild gemäß bestehender Einstellungen.
- Keine zusätzliche Aufnahmefreigabe; CPU-/Speicherverbrauch und sichtbare Verzögerung messen.

Zuerst reine Zuordnungs-/Geometrieprüfungen und native getrennte Testprozesse, anschließend sichtbare Abnahme der tatsächlichen Fensterreihenfolge. Ein bestandener Maskentest allein ist kein Nachweis für korrektes Verhalten über fremden Apps.

## Abgrenzung

Kein Umbau der gemeinsamen Einstellungen, keine Profile-Migration, kein neues dauerhaftes Einstellungsformat und keine Änderung installierter Apps im Rahmen dieser Planung. Die Umsetzung wurde anschließend ausdrücklich beauftragt; die Prüfungsergebnisse und verbleibenden Grenzen stehen oben.
