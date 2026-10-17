# FocusFrame: Rahmen bei überlappenden Fenstern

Status: Planung auf Benutzerwunsch, noch keine Änderung der Produktions-Fensterlogik.

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

Kein Umbau der gemeinsamen Einstellungen, keine Profile-Migration, kein neues dauerhaftes Einstellungsformat und keine Änderung installierter Apps im Rahmen dieser Planung. Die Umsetzung folgt erst auf einen entsprechenden Auftrag.
